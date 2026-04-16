package taskruntime

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/taskconfig"
	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskengine"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor"
	"github.com/LaLanMo/muxagent/cli/internal/taskruntime/instancelock"
	"github.com/LaLanMo/muxagent/cli/internal/taskstore"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
	"github.com/google/uuid"
)

type Service struct {
	workDir  string
	lock     *instancelock.Lock
	store    *taskstore.Store
	engine   *taskengine.Engine
	executor taskexecutor.Executor
	bus      *LocalBus
	nodeWG   sync.WaitGroup
	// beforeStartNode is a narrow test seam for forcing deterministic
	// post-commit entry-run launch failures.
	beforeStartNode func(task taskdomain.Task, run taskdomain.NodeRun) error

	mu             sync.Mutex
	rootCtx        context.Context
	taskCancels    map[string]context.CancelFunc
	taskCtxs       map[string]context.Context
	runEventSeqs   map[string]uint64
	shutdownReason string
}

func NewService(workDir string, executor taskexecutor.Executor) (*Service, error) {
	workDir = taskstore.NormalizeWorkDir(workDir)
	lock, err := instancelock.Acquire(workDir)
	if err != nil {
		return nil, err
	}
	store, err := taskstore.Open(workDir)
	if err != nil {
		_ = lock.Release()
		return nil, err
	}
	service := &Service{
		workDir:      workDir,
		lock:         lock,
		store:        store,
		engine:       taskengine.New(),
		executor:     executor,
		bus:          NewLocalBus(16, 64),
		taskCancels:  map[string]context.CancelFunc{},
		taskCtxs:     map[string]context.Context{},
		runEventSeqs: map[string]uint64{},
	}
	if err := service.reconcileStaleRunning(context.Background()); err != nil {
		_ = store.Close()
		_ = lock.Release()
		return nil, err
	}
	return service, nil
}

func (s *Service) Close() error {
	s.mu.Lock()
	for _, cancel := range s.taskCancels {
		cancel()
	}
	s.taskCancels = map[string]context.CancelFunc{}
	s.taskCtxs = map[string]context.Context{}
	s.runEventSeqs = map[string]uint64{}
	s.mu.Unlock()
	s.nodeWG.Wait()
	executorErr := taskexecutor.Close(s.executor)
	storeErr := s.store.Close()
	lockErr := s.lock.Release()
	if executorErr != nil {
		return executorErr
	}
	if storeErr != nil {
		return storeErr
	}
	return lockErr
}

func (s *Service) PrepareShutdown(ctx context.Context) error {
	s.setShutdownReason(taskdomain.FailureReasonInterruptedByUser)
	s.cancelTasks()
	return s.failActiveRunningNodeRuns(ctx, taskdomain.FailureReasonInterruptedByUser)
}

func (s *Service) Events() <-chan RunEvent {
	return s.bus.Events
}

func (s *Service) Dispatch(cmd RunCommand) {
	s.bus.Commands <- cmd
}

func (s *Service) Run(ctx context.Context) error {
	s.rootCtx = ctx
	for {
		select {
		case <-ctx.Done():
			s.cancelTasks()
			return ctx.Err()
		case cmd := <-s.bus.Commands:
			if err := s.handleCommand(ctx, cmd); err != nil {
				if !shouldPublishCommandError(err) {
					continue
				}
				s.publish(RunEvent{
					Type:   EventCommandError,
					TaskID: cmd.TaskID,
					Error:  &RunError{Message: err.Error()},
				})
			}
			if cmd.Type == CommandShutdown {
				return nil
			}
		}
	}
}

func (s *Service) handleCommand(ctx context.Context, cmd RunCommand) error {
	switch cmd.Type {
	case CommandStartTask:
		return s.startTask(ctx, cmd.Description, cmd.ConfigAlias, cmd.ConfigPath, firstNonEmpty(cmd.WorkDir, s.workDir), cmd.UseWorktree)
	case CommandStartFollowUp:
		return s.startFollowUpTask(ctx, cmd.ParentTaskID, cmd.Description, cmd.ConfigAlias, cmd.ConfigPath, cmd.FollowUpMode)
	case CommandSubmitInput:
		return s.submitInput(ctx, cmd.TaskID, cmd.NodeRunID, cmd.Payload)
	case CommandRetryNode:
		return s.retryNode(ctx, cmd.TaskID, cmd.NodeRunID, cmd.Force)
	case CommandContinueBlocked:
		return s.continueBlockedStep(ctx, cmd.TaskID)
	case CommandShutdown:
		return s.PrepareShutdown(ctx)
	default:
		return fmt.Errorf("unsupported command %q", cmd.Type)
	}
}

func (s *Service) startTask(ctx context.Context, description, configAlias, configPath, workDir string, useWorktree bool) (err error) {
	return s.startTaskWithExecution(ctx, "", description, configAlias, configPath, workDir, func(taskID, normalizedWorkDir string) (string, func() error, error) {
		return prepareTaskExecutionDir(normalizedWorkDir, taskID, useWorktree)
	})
}

func (s *Service) startFollowUpTask(ctx context.Context, parentTaskID, description, configAlias, configPath string, requestedMode FollowUpMode) error {
	parentTaskID = strings.TrimSpace(parentTaskID)
	if parentTaskID == "" {
		return errors.New("parent task id is required")
	}
	parentView, _, err := s.LoadTaskView(ctx, parentTaskID)
	if err != nil {
		return err
	}
	if parentView.Status != taskdomain.TaskStatusDone {
		return fmt.Errorf("parent task %q is not completed", parentTaskID)
	}
	parentTask := parentView.Task
	if strings.TrimSpace(parentTask.ConfigAlias) == "" || strings.TrimSpace(parentTask.ConfigPath) == "" {
		return fmt.Errorf("parent task %q is missing launch metadata", parentTaskID)
	}
	configAlias = strings.TrimSpace(configAlias)
	configPath = strings.TrimSpace(configPath)
	switch {
	case configAlias == "" && configPath == "":
		configAlias = parentTask.ConfigAlias
		configPath = parentTask.ConfigPath
	case configAlias == "" || configPath == "":
		return errors.New("follow-up task config alias and path must be provided together")
	}

	parentExecutionDir, parentCheckoutRoot, relativeCWD, err := resolveTaskCheckout(parentTask)
	if err != nil {
		if taskUsesWorktree(parentTask) {
			return err
		}
		if strings.TrimSpace(string(requestedMode)) != "" {
			return fmt.Errorf("follow-up mode %q requires a repo-backed parent task", requestedMode)
		}
		return s.startTaskWithExecution(ctx, parentTaskID, description, configAlias, configPath, parentTask.WorkDir, func(taskID, normalizedWorkDir string) (string, func() error, error) {
			return prepareTaskExecutionDir(normalizedWorkDir, taskID, false)
		})
	}
	mode, err := resolveFollowUpMode(requestedMode)
	if err != nil {
		return err
	}
	if mode == FollowUpModeContinueHere {
		if err := s.ensureCheckoutAvailableForContinueHere(ctx, parentTask.ID, parentCheckoutRoot); err != nil {
			return err
		}
		return s.startTaskWithExecution(ctx, parentTaskID, description, configAlias, configPath, parentTask.WorkDir, func(taskID, normalizedWorkDir string) (string, func() error, error) {
			return parentExecutionDir, nil, nil
		})
	}

	parentHead, err := worktree.HeadCommit(parentCheckoutRoot)
	if err != nil {
		return fmt.Errorf("resolve parent checkout HEAD: %w", err)
	}
	mirrorExclusions, err := followUpMirrorExclusions(parentTask, parentCheckoutRoot)
	if err != nil {
		return err
	}
	return s.startTaskWithExecution(ctx, parentTaskID, description, configAlias, configPath, parentTask.WorkDir, func(taskID, normalizedWorkDir string) (string, func() error, error) {
		executionDir, childCheckoutRoot, rollback, err := prepareTaskExecutionDirFromRef(parentCheckoutRoot, taskID, parentHead, relativeCWD)
		if err != nil {
			return "", rollback, err
		}
		if mode != FollowUpModeForkWithChanges {
			return executionDir, rollback, nil
		}
		if err := worktree.MirrorCheckout(parentCheckoutRoot, childCheckoutRoot, mirrorExclusions...); err != nil {
			return "", rollback, fmt.Errorf("snapshot parent checkout: %w", err)
		}
		executionDir, err = worktree.ResolveWorktreeCWD(childCheckoutRoot, relativeCWD)
		if err != nil {
			return "", rollback, err
		}
		return executionDir, rollback, nil
	})
}

func (s *Service) startTaskWithExecution(ctx context.Context, parentTaskID, description, configAlias, configPath, workDir string, prepareExecution func(taskID, normalizedWorkDir string) (string, func() error, error)) (err error) {
	workDir = taskstore.NormalizeWorkDir(workDir)
	taskID := uuid.NewString()
	now := time.Now().UTC()
	committed := false
	var rollbackWorktree func() error
	defer func() {
		if committed || err == nil {
			return
		}
		if cleanupErr := os.RemoveAll(taskstore.TaskDir(workDir, taskID)); cleanupErr != nil {
			err = errors.Join(err, fmt.Errorf("cleanup task dir: %w", cleanupErr))
		}
		if rollbackWorktree != nil {
			if cleanupErr := rollbackWorktree(); cleanupErr != nil {
				err = errors.Join(err, fmt.Errorf("rollback worktree: %w", cleanupErr))
			}
		}
	}()
	configAlias = strings.TrimSpace(configAlias)
	if configAlias == "" {
		return errors.New("task config alias is required")
	}
	configPath = strings.TrimSpace(configPath)
	if configPath == "" {
		return errors.New("task config path is required")
	}
	materialized, err := taskconfig.Materialize(workDir, taskID, configPath)
	if err != nil {
		return err
	}
	executionDir, rollback, err := prepareExecution(taskID, workDir)
	rollbackWorktree = rollback
	if err != nil {
		return err
	}
	task := taskdomain.Task{
		ID:           taskID,
		Description:  description,
		ConfigAlias:  configAlias,
		ConfigPath:   configPath,
		WorkDir:      workDir,
		ExecutionDir: executionDir,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	entry := materialized.Config.Topology.Entry
	nodeRun := taskdomain.NodeRun{
		ID:        uuid.NewString(),
		TaskID:    taskID,
		NodeName:  entry,
		Status:    initialStatus(materialized.Config.NodeDefinitions[entry]),
		StartedAt: now,
	}
	if strings.TrimSpace(parentTaskID) == "" {
		err = s.store.CreateTaskWithEntryRun(ctx, task, nodeRun)
	} else {
		err = s.store.CreateFollowUpTaskAtomic(ctx, parentTaskID, task, nodeRun)
	}
	if err != nil {
		return err
	}
	committed = true

	view := taskdomain.DeriveTaskView(task, materialized.Config, []taskdomain.NodeRun{nodeRun}, nil)
	if loadedView, _, loadErr := s.LoadTaskView(ctx, taskID); loadErr == nil {
		view = loadedView
	}
	s.publish(RunEvent{
		Type:     EventTaskCreated,
		TaskID:   taskID,
		TaskView: &view,
		Config:   materialized.Config,
	})

	s.engine.RegisterEntryRun(taskID, nodeRun)

	taskCtx, cancel := context.WithCancel(s.rootCtx)
	s.mu.Lock()
	s.taskCancels[taskID] = cancel
	s.taskCtxs[taskID] = taskCtx
	s.mu.Unlock()

	if s.beforeStartNode != nil {
		if err = s.beforeStartNode(task, nodeRun); err != nil {
			cancel()
			s.clearTaskContext(taskID)
			return s.failRun(context.Background(), task, materialized.Config, nodeRun, err)
		}
	}
	if err = s.startNode(taskCtx, task, materialized.Config, nodeRun); err != nil {
		cancel()
		s.clearTaskContext(taskID)
		return s.failRun(context.Background(), task, materialized.Config, nodeRun, err)
	}
	return nil
}

func prepareTaskExecutionDir(workDir, taskID string, useWorktree bool) (string, func() error, error) {
	if !useWorktree {
		return workDir, nil, nil
	}

	repoRoot, err := worktree.FindRepoRoot(workDir)
	if err != nil {
		return "", nil, err
	}
	relPath, err := worktree.NormalizeRepoRelativePath(repoRoot, workDir)
	if err != nil {
		return "", nil, err
	}
	executionDir, _, rollback, err := prepareTaskExecutionDirFromRef(repoRoot, taskID, "HEAD", relPath)
	if err != nil {
		return "", rollback, err
	}
	return executionDir, rollback, nil
}

func prepareTaskExecutionDirFromRef(repoRoot, taskID, ref, relativeCWD string) (string, string, func() error, error) {
	worktreePath, err := worktree.CreateFromRef(repoRoot, taskID, ref)
	if err != nil {
		return "", "", nil, err
	}
	rollback := func() error {
		return worktree.Cleanup(repoRoot, worktreePath, worktree.BranchName(taskID))
	}
	executionDir, err := worktree.ResolveWorktreeCWD(worktreePath, relativeCWD)
	if err != nil {
		return "", worktreePath, rollback, err
	}
	return executionDir, worktreePath, rollback, nil
}

func taskUsesWorktree(task taskdomain.Task) bool {
	executionDir := strings.TrimSpace(task.ExecutionDir)
	workDir := strings.TrimSpace(task.WorkDir)
	if executionDir == "" || workDir == "" {
		return false
	}
	return taskstore.NormalizeWorkDir(executionDir) != taskstore.NormalizeWorkDir(workDir)
}

func resolveFollowUpMode(requestedMode FollowUpMode) (FollowUpMode, error) {
	switch requestedMode {
	case "", FollowUpModeContinueHere:
		return FollowUpModeContinueHere, nil
	case FollowUpModeForkHead, FollowUpModeForkWithChanges:
		return requestedMode, nil
	default:
		return "", fmt.Errorf("unsupported follow-up mode %q", requestedMode)
	}
}

func resolveTaskCheckout(task taskdomain.Task) (string, string, string, error) {
	checkoutRoot, err := worktree.FindRepoRoot(task.ExecutionDir)
	if err != nil {
		return "", "", "", fmt.Errorf("%w: %w", ErrFollowUpParentWorktreeMissing, err)
	}
	relativeCWD, err := worktree.NormalizeRepoRelativePath(checkoutRoot, task.ExecutionDir)
	if err != nil {
		return "", "", "", fmt.Errorf("%w: %w", ErrFollowUpParentWorktreeMissing, err)
	}
	executionDir, err := worktree.ResolveWorktreeCWD(checkoutRoot, relativeCWD)
	if err != nil {
		return "", "", "", fmt.Errorf("%w: %w", ErrFollowUpParentWorktreeMissing, err)
	}
	return executionDir, checkoutRoot, relativeCWD, nil
}

func (s *Service) ensureCheckoutAvailableForContinueHere(ctx context.Context, parentTaskID, parentCheckoutRoot string) error {
	liveStatuses := []taskdomain.NodeRunStatus{
		taskdomain.NodeRunRunning,
		taskdomain.NodeRunAwaitingUser,
	}
	seenTaskIDs := map[string]struct{}{}
	for _, status := range liveStatuses {
		runs, err := s.store.ListNodeRunsByStatus(ctx, status)
		if err != nil {
			return err
		}
		for _, run := range runs {
			if run.TaskID == parentTaskID {
				continue
			}
			if _, ok := seenTaskIDs[run.TaskID]; ok {
				continue
			}
			seenTaskIDs[run.TaskID] = struct{}{}
			task, err := s.store.GetTask(ctx, run.TaskID)
			if err != nil {
				return err
			}
			_, checkoutRoot, _, err := resolveTaskCheckout(task)
			if err != nil {
				continue
			}
			if checkoutRoot == parentCheckoutRoot {
				return fmt.Errorf("cannot continue here while task %q is still active in this checkout", task.ID)
			}
		}
	}
	return nil
}

func followUpMirrorExclusions(task taskdomain.Task, checkoutRoot string) ([]string, error) {
	if taskUsesWorktree(task) {
		return nil, nil
	}
	muxagentRoot := filepath.Join(task.WorkDir, ".muxagent")
	if _, err := os.Stat(muxagentRoot); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, fmt.Errorf("inspect parent runtime state: %w", err)
	}
	relativePath, err := worktree.NormalizeRepoRelativePath(checkoutRoot, muxagentRoot)
	if err != nil {
		return nil, fmt.Errorf("resolve parent runtime exclusion: %w", err)
	}
	return []string{relativePath}, nil
}

func (s *Service) submitInput(ctx context.Context, taskID, nodeRunID string, payload map[string]interface{}) error {
	task, err := s.store.GetTask(ctx, taskID)
	if err != nil {
		return err
	}
	cfg, err := taskconfig.Load(taskstore.ConfigPath(task.WorkDir, task.ID))
	if err != nil {
		return err
	}
	run, err := s.store.GetNodeRun(ctx, nodeRunID)
	if err != nil {
		return err
	}
	if run.TaskID != taskID {
		return fmt.Errorf("node run %q does not belong to task %q", nodeRunID, taskID)
	}
	if run.Status != taskdomain.NodeRunAwaitingUser {
		return fmt.Errorf("node run %q is not awaiting user input", nodeRunID)
	}

	def := cfg.NodeDefinitions[run.NodeName]
	now := time.Now().UTC()
	if def.Type == taskconfig.NodeTypeHuman {
		if err := taskconfig.ValidateValue(&def.ResultSchema, payload); err != nil {
			return err
		}
		runs, err := s.store.ListNodeRunsByTask(ctx, taskID)
		if err != nil {
			return err
		}
		result, err := materializeHumanNodeArtifact(task, run, runs, payload, now)
		if err != nil {
			return err
		}
		run.Result = result
		run.Status = taskdomain.NodeRunDone
		run.FailureReason = ""
		run.CompletedAt = &now
		if err := s.store.SaveNodeRun(ctx, run); err != nil {
			return err
		}
		return s.afterNodeCompleted(ctx, task, cfg, run)
	}

	if len(run.Clarifications) == 0 {
		return errors.New("clarification input submitted for a node without clarification request")
	}
	runs, err := s.store.ListNodeRunsByTask(ctx, taskID)
	if err != nil {
		return err
	}
	response, err := parseClarificationResponse(run.Clarifications[len(run.Clarifications)-1].Request, payload)
	if err != nil {
		return err
	}
	run.Clarifications[len(run.Clarifications)-1].Response = response
	run.Clarifications[len(run.Clarifications)-1].AnsweredAt = &now
	if _, err := writeClarificationInputArtifact(task, run, runs); err != nil {
		return err
	}
	run.Status = taskdomain.NodeRunRunning
	run.FailureReason = ""
	if err := s.store.SaveNodeRun(ctx, run); err != nil {
		return err
	}
	view, err := s.refreshTaskView(context.Background(), task.ID)
	if err != nil {
		return err
	}
	s.publish(RunEvent{
		Type:      EventNodeStarted,
		TaskID:    task.ID,
		NodeRunID: run.ID,
		NodeName:  run.NodeName,
		TaskView:  &view,
	})

	taskCtx := s.lookupTaskContext(taskID)
	if taskCtx == nil {
		taskCtx = ctx
	}
	s.runAgentNodeAsync(taskCtx, task, cfg, run)
	return nil
}

func (s *Service) rebuildEngineState(taskID string, runs []taskdomain.NodeRun) {
	sort.Slice(runs, func(i, j int) bool {
		if runs[i].StartedAt.Equal(runs[j].StartedAt) {
			return runs[i].ID < runs[j].ID
		}
		return runs[i].StartedAt.Before(runs[j].StartedAt)
	})
	for _, run := range runs {
		if run.TriggeredBy == nil {
			s.engine.RegisterEntryRun(taskID, run)
		} else {
			s.engine.RegisterTriggeredRun(taskID, run, run.TriggeredBy.NodeRunID)
		}
	}
}

func (s *Service) publish(event RunEvent) {
	select {
	case s.bus.Events <- event:
	default:
		s.bus.Events <- event
	}
}

func (s *Service) cancelTasks() {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, cancel := range s.taskCancels {
		cancel()
	}
}

func (s *Service) lookupTaskContext(taskID string) context.Context {
	s.mu.Lock()
	defer s.mu.Unlock()
	if taskCtx, ok := s.taskCtxs[taskID]; ok {
		return taskCtx
	}
	if s.rootCtx == nil {
		return context.Background()
	}
	return s.rootCtx
}

func (s *Service) clearTaskContext(taskID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.taskCancels, taskID)
	delete(s.taskCtxs, taskID)
}

func (s *Service) setShutdownReason(reason string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.shutdownReason == "" {
		s.shutdownReason = reason
	}
}

func (s *Service) currentShutdownReason() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.shutdownReason
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

type reportedTaskFailureError struct {
	cause error
}

func (e reportedTaskFailureError) Error() string {
	return e.cause.Error()
}

func (e reportedTaskFailureError) Unwrap() error {
	return e.cause
}

func markTaskFailureReported(err error) error {
	if err == nil {
		return nil
	}
	return reportedTaskFailureError{cause: err}
}

func shouldPublishCommandError(err error) bool {
	if err == nil {
		return false
	}
	var reported reportedTaskFailureError
	return !errors.As(err, &reported)
}
