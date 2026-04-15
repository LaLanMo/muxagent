package appserver

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/LaLanMo/muxagent/cli/internal/taskconfig"
	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskengine"
	"github.com/LaLanMo/muxagent/cli/internal/taskhistory"
	"github.com/LaLanMo/muxagent/cli/internal/taskruntime"
	"github.com/LaLanMo/muxagent/cli/internal/taskstore"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
)

type taskReadModel struct {
	workDir string
	store   *taskstore.Store
}

func openTaskReadModel(workDir string) (*taskReadModel, error) {
	workDir = taskstore.NormalizeWorkDir(workDir)
	store, err := taskstore.Open(workDir)
	if err != nil {
		return nil, err
	}
	return &taskReadModel{workDir: workDir, store: store}, nil
}

func (m *taskReadModel) Close() error {
	if m == nil {
		return nil
	}
	return m.store.Close()
}

func (m *taskReadModel) ListTaskViews(ctx context.Context) ([]taskdomain.TaskView, error) {
	tasks, err := m.store.ListTasksByWorkDir(ctx, m.workDir)
	if err != nil {
		return nil, err
	}
	views := make([]taskdomain.TaskView, 0, len(tasks))
	for _, task := range tasks {
		view, _, err := m.LoadTaskView(ctx, task.ID)
		if err != nil {
			continue
		}
		views = append(views, view)
	}
	return views, nil
}

func (m *taskReadModel) LoadTaskView(ctx context.Context, taskID string) (taskdomain.TaskView, *taskconfig.Config, error) {
	task, err := m.store.GetTask(ctx, taskID)
	if err != nil {
		return taskdomain.TaskView{}, nil, err
	}
	cfg, err := taskconfig.Load(taskstore.ConfigPath(task.WorkDir, task.ID))
	if err != nil {
		return taskdomain.TaskView{}, nil, err
	}
	runs, err := m.store.ListNodeRunsByTask(ctx, taskID)
	if err != nil {
		return taskdomain.TaskView{}, nil, err
	}
	blockedSteps, err := taskengine.DeriveBlockedSteps(cfg, runs)
	if err != nil {
		return taskdomain.TaskView{}, nil, err
	}
	view := taskdomain.DeriveTaskView(task, cfg, runs, blockedSteps)
	if err := m.loadTaskLineage(ctx, &view); err != nil {
		return taskdomain.TaskView{}, nil, err
	}
	return view, cfg, nil
}

func (m *taskReadModel) LoadTaskAncestry(ctx context.Context, taskID string) ([]taskdomain.TaskView, error) {
	if _, err := m.store.GetTask(ctx, taskID); err != nil {
		return nil, err
	}

	visited := map[string]struct{}{
		taskID: {},
	}
	lineage := make([]taskdomain.TaskView, 0)
	parentTaskID, err := m.store.GetFollowUpParentTaskID(ctx, taskID)
	if err != nil {
		return nil, err
	}
	for strings.TrimSpace(parentTaskID) != "" {
		if _, seen := visited[parentTaskID]; seen {
			return nil, taskstore.ErrTaskLineageCorrupt
		}
		visited[parentTaskID] = struct{}{}
		view, _, err := m.LoadTaskView(ctx, parentTaskID)
		if err != nil {
			return nil, err
		}
		lineage = append(lineage, view)
		parentTaskID = view.ParentTaskID
	}

	for left, right := 0, len(lineage)-1; left < right; left, right = left+1, right-1 {
		lineage[left], lineage[right] = lineage[right], lineage[left]
	}
	return lineage, nil
}

func (m *taskReadModel) BuildInputRequest(ctx context.Context, taskID, nodeRunID string) (*taskruntime.InputRequest, error) {
	task, err := m.store.GetTask(ctx, taskID)
	if err != nil {
		return nil, err
	}
	cfg, err := taskconfig.Load(taskstore.ConfigPath(task.WorkDir, task.ID))
	if err != nil {
		return nil, err
	}
	run, err := m.store.GetNodeRun(ctx, nodeRunID)
	if err != nil {
		return nil, err
	}
	if run.TaskID != taskID {
		return nil, fmt.Errorf("%w: node run %q does not belong to task %q", taskruntime.ErrNodeRunTaskMismatch, nodeRunID, taskID)
	}
	if run.Status != taskdomain.NodeRunAwaitingUser {
		return nil, fmt.Errorf("%w: node run %q is not awaiting user input", taskruntime.ErrNodeRunNotAwaitingUser, nodeRunID)
	}
	runs, err := m.store.ListNodeRunsByTask(ctx, taskID)
	if err != nil {
		return nil, err
	}
	return m.buildInputRequest(ctx, task, cfg, runs, run)
}

func (m *taskReadModel) LoadRunHistory(ctx context.Context, taskID, nodeRunID string) (taskdomain.NodeRun, taskhistory.ReadResult, error) {
	task, err := m.store.GetTask(ctx, taskID)
	if err != nil {
		return taskdomain.NodeRun{}, taskhistory.ReadResult{}, err
	}
	run, err := m.store.GetNodeRun(ctx, nodeRunID)
	if err != nil {
		return taskdomain.NodeRun{}, taskhistory.ReadResult{}, err
	}
	if run.TaskID != taskID {
		return taskdomain.NodeRun{}, taskhistory.ReadResult{}, fmt.Errorf("%w: node run %q does not belong to task %q", taskruntime.ErrNodeRunTaskMismatch, nodeRunID, taskID)
	}
	localHistory, err := taskhistory.Load(task, nil, run)
	if err != nil {
		if taskhistory.IsMissing(err) || errors.Is(err, os.ErrNotExist) {
			return run, taskhistory.ReadResult{}, nil
		}
		return taskdomain.NodeRun{}, taskhistory.ReadResult{}, err
	}
	if strings.TrimSpace(run.SessionID) == "" {
		return run, localHistory, nil
	}
	cfg, err := taskconfig.Load(taskstore.ConfigPath(task.WorkDir, task.ID))
	if err != nil {
		return run, localHistory, nil
	}
	history, err := taskhistory.Load(task, cfg, run)
	if err != nil {
		if taskhistory.IsMissing(err) || errors.Is(err, os.ErrNotExist) {
			return run, localHistory, nil
		}
		return taskdomain.NodeRun{}, taskhistory.ReadResult{}, err
	}
	return run, history, nil
}

func (m *taskReadModel) loadTaskLineage(ctx context.Context, view *taskdomain.TaskView) error {
	if view == nil {
		return nil
	}
	parentTaskID, err := m.store.GetFollowUpParentTaskID(ctx, view.Task.ID)
	if err != nil {
		return err
	}
	if parentTaskID == "" {
		return nil
	}
	parentTask, err := m.store.GetTask(ctx, parentTaskID)
	if err != nil {
		return err
	}
	view.ParentTaskID = parentTaskID
	view.ParentTaskDescription = parentTask.Description
	return nil
}

func (m *taskReadModel) BuildFollowUpInfo(task taskdomain.Task, status taskdomain.TaskStatus) (*followUpDTO, error) {
	if status != taskdomain.TaskStatusDone {
		return nil, nil
	}
	executionDir := taskstore.NormalizeWorkDir(strings.TrimSpace(task.ExecutionDir))
	if executionDir == "" {
		return nil, nil
	}

	checkoutRoot, err := worktree.FindRepoRoot(executionDir)
	if err != nil {
		return nil, nil
	}
	relativeCWD, err := worktree.NormalizeRepoRelativePath(checkoutRoot, executionDir)
	if err != nil {
		return nil, nil
	}
	if _, err := worktree.ResolveWorktreeCWD(checkoutRoot, relativeCWD); err != nil {
		return nil, nil
	}

	dirtyCount, err := worktree.DirtyChangeCount(checkoutRoot)
	if err != nil {
		return nil, err
	}
	return &followUpDTO{
		DefaultMode: taskruntime.FollowUpModeContinueHere,
		AvailableModes: []taskruntime.FollowUpMode{
			taskruntime.FollowUpModeContinueHere,
			taskruntime.FollowUpModeForkHead,
			taskruntime.FollowUpModeForkWithChanges,
		},
		UncommittedChangeCount: dirtyCount,
	}, nil
}

func (m *taskReadModel) buildInputRequest(ctx context.Context, task taskdomain.Task, cfg *taskconfig.Config, runs []taskdomain.NodeRun, run taskdomain.NodeRun) (*taskruntime.InputRequest, error) {
	artifacts := completedArtifactPaths(runs)
	inheritedArtifacts, err := m.loadInheritedInputArtifacts(ctx, task)
	if err != nil {
		return nil, err
	}
	if len(inheritedArtifacts) > 0 {
		artifacts = mergeArtifactPaths(artifacts, inheritedArtifacts)
	}
	def := cfg.NodeDefinitions[run.NodeName]
	if def.Type == taskconfig.NodeTypeHuman {
		schema := def.ResultSchema
		return &taskruntime.InputRequest{
			Kind:          taskruntime.InputKindHumanNode,
			TaskID:        run.TaskID,
			NodeRunID:     run.ID,
			NodeName:      run.NodeName,
			Schema:        &schema,
			ArtifactPaths: artifacts,
		}, nil
	}
	if len(run.Clarifications) == 0 {
		return nil, nil
	}
	return &taskruntime.InputRequest{
		Kind:          taskruntime.InputKindClarification,
		TaskID:        run.TaskID,
		NodeRunID:     run.ID,
		NodeName:      run.NodeName,
		Questions:     run.Clarifications[len(run.Clarifications)-1].Request.Questions,
		ArtifactPaths: artifacts,
	}, nil
}

func (m *taskReadModel) loadInheritedInputArtifacts(ctx context.Context, task taskdomain.Task) ([]string, error) {
	parentTaskID, err := m.store.GetFollowUpParentTaskID(ctx, task.ID)
	if err != nil {
		return nil, err
	}
	if parentTaskID == "" {
		return nil, nil
	}
	parentTask, err := m.store.GetTask(ctx, parentTaskID)
	if err != nil {
		return nil, err
	}
	parentRuns, err := m.store.ListNodeRunsByTask(ctx, parentTaskID)
	if err != nil {
		return nil, err
	}
	return existingArtifactPaths(resolveArtifactPaths(parentTask, parentRuns)), nil
}

func completedArtifactPaths(runs []taskdomain.NodeRun) []string {
	paths := make([]string, 0)
	for _, run := range runs {
		if run.Status != taskdomain.NodeRunDone {
			continue
		}
		paths = append(paths, taskdomain.ArtifactPaths(run.Result)...)
	}
	return paths
}

func existingArtifactPaths(paths []string) []string {
	seen := map[string]struct{}{}
	reversed := make([]string, 0, len(paths))
	for i := len(paths) - 1; i >= 0; i-- {
		path := strings.TrimSpace(paths[i])
		if path == "" {
			continue
		}
		if _, ok := seen[path]; ok {
			continue
		}
		if _, err := os.Stat(path); err != nil {
			continue
		}
		seen[path] = struct{}{}
		reversed = append(reversed, path)
	}
	result := make([]string, 0, len(reversed))
	for i := len(reversed) - 1; i >= 0; i-- {
		result = append(result, reversed[i])
	}
	return result
}

func resolveArtifactPaths(task taskdomain.Task, runs []taskdomain.NodeRun) []string {
	resolved := make([]string, 0)
	for _, run := range runs {
		if run.Status != taskdomain.NodeRunDone {
			continue
		}
		for _, rawPath := range taskdomain.ArtifactPaths(run.Result) {
			path := strings.TrimSpace(rawPath)
			if path == "" {
				continue
			}
			path = taskstore.ResolveRunPath(task.WorkDir, task.ID, run.ID, path)
			resolved = append(resolved, path)
		}
	}
	return resolved
}

func mergeArtifactPaths(current, inherited []string) []string {
	merged := make([]string, 0, len(current)+len(inherited))
	seen := map[string]struct{}{}
	for _, group := range [][]string{current, inherited} {
		for _, path := range group {
			path = strings.TrimSpace(path)
			if path == "" {
				continue
			}
			if _, ok := seen[path]; ok {
				continue
			}
			seen[path] = struct{}{}
			merged = append(merged, path)
		}
	}
	return merged
}

func latestAwaitingRunID(view taskdomain.TaskView) string {
	for i := len(view.NodeRuns) - 1; i >= 0; i-- {
		if view.NodeRuns[i].Status == taskdomain.NodeRunAwaitingUser {
			return view.NodeRuns[i].ID
		}
	}
	return ""
}

func runtimeLookupRPCError(err error) *rpcError {
	if err == nil {
		return nil
	}
	if errors.Is(err, taskruntime.ErrNodeRunTaskMismatch) ||
		errors.Is(err, taskruntime.ErrNodeRunNotAwaitingUser) ||
		errors.Is(err, sql.ErrNoRows) {
		return &rpcError{Code: errorCodeInvalidParams, Message: err.Error()}
	}
	if errors.Is(err, os.ErrNotExist) {
		return &rpcError{Code: errorCodeInvalidParams, Message: err.Error()}
	}
	return &rpcError{Code: errorCodeInternalError, Message: err.Error()}
}

func xorBlank(values ...string) bool {
	blankCount := 0
	for _, value := range values {
		if strings.TrimSpace(value) == "" {
			blankCount++
		}
	}
	return blankCount > 0 && blankCount < len(values)
}
