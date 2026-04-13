package appserver

import (
	"context"
	"errors"
	"os"
	"strings"
	"sync"

	"github.com/LaLanMo/muxagent-cli/internal/taskexecutor"
	"github.com/LaLanMo/muxagent-cli/internal/taskexecutor/claudeexec"
	"github.com/LaLanMo/muxagent-cli/internal/taskexecutor/codex"
	"github.com/LaLanMo/muxagent-cli/internal/taskexecutor/opencodehttp"
	"github.com/LaLanMo/muxagent-cli/internal/taskruntime"
	"golang.org/x/sync/singleflight"
)

type runtimeService interface {
	Run(ctx context.Context) error
	Events() <-chan taskruntime.RunEvent
	Dispatch(cmd taskruntime.RunCommand)
	PrepareShutdown(ctx context.Context) error
	Close() error
}

type runtimeServiceFactory func(workDir string) (runtimeService, error)

type runtimeManager struct {
	factory runtimeServiceFactory
	onEvent func(workspaceID string, event taskruntime.RunEvent)

	mu             sync.Mutex
	actors         map[string]*workspaceActor
	reconcileGroup singleflight.Group
}

type workspaceActor struct {
	workspaceID string
	workDir     string
	service     runtimeService
	cancel      context.CancelFunc

	mu        sync.Mutex
	running   bool
	lastError string
}

func defaultRuntimeServiceFactory(workDir string) (runtimeService, error) {
	return taskruntime.NewService(
		workDir,
		taskexecutor.NewRouter(newCodexExecutorForAppServer(), claudeexec.New(""), opencodehttp.New("")),
	)
}

func newCodexExecutorForAppServer() taskexecutor.Executor {
	return codex.NewWithMode("", codexExecutorModeForAppServer(os.Getenv(codex.EnvExecutorMode)))
}

func codexExecutorModeForAppServer(mode string) string {
	switch strings.ToLower(strings.TrimSpace(mode)) {
	case codex.ModeAppServer, "app-server":
		return codex.ModeAppServer
	case codex.ModeExec, "":
		return codex.ModeExec
	default:
		// Keep the daemon on the proven exec path unless rollout is explicit.
		return codex.ModeExec
	}
}

func newRuntimeManager(factory runtimeServiceFactory, onEvent func(workspaceID string, event taskruntime.RunEvent)) *runtimeManager {
	if factory == nil {
		factory = defaultRuntimeServiceFactory
	}
	return &runtimeManager{
		factory: factory,
		onEvent: onEvent,
		actors:  map[string]*workspaceActor{},
	}
}

func (m *runtimeManager) dispatch(workspace workspaceRecord, cmd taskruntime.RunCommand) error {
	actor, err := m.ensure(workspace)
	if err != nil {
		return err
	}
	actor.service.Dispatch(cmd)
	return nil
}

func (m *runtimeManager) snapshot(workspaceID string) workspaceActorDTO {
	m.mu.Lock()
	actor, ok := m.actors[workspaceID]
	m.mu.Unlock()
	if !ok {
		return workspaceActorDTO{State: "cold"}
	}
	actor.mu.Lock()
	defer actor.mu.Unlock()
	state := "active"
	if !actor.running {
		state = "error"
		if actor.lastError == "" {
			state = "cold"
		}
	}
	return workspaceActorDTO{
		State:     state,
		LastError: actor.lastError,
	}
}

func (m *runtimeManager) remove(workspaceID string) error {
	m.mu.Lock()
	actor, ok := m.actors[workspaceID]
	if ok {
		delete(m.actors, workspaceID)
	}
	m.mu.Unlock()
	if !ok {
		return nil
	}
	return closeWorkspaceActor(actor)
}

func (m *runtimeManager) closeAll() error {
	m.mu.Lock()
	actors := make([]*workspaceActor, 0, len(m.actors))
	for _, actor := range m.actors {
		actors = append(actors, actor)
	}
	m.actors = map[string]*workspaceActor{}
	m.mu.Unlock()

	var errs []error
	for _, actor := range actors {
		if err := closeWorkspaceActor(actor); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

func (m *runtimeManager) prepareShutdownAll(ctx context.Context) error {
	m.mu.Lock()
	actors := make([]*workspaceActor, 0, len(m.actors))
	for _, actor := range m.actors {
		actors = append(actors, actor)
	}
	m.mu.Unlock()

	var errs []error
	for _, actor := range actors {
		if err := actor.service.PrepareShutdown(ctx); err != nil && !errors.Is(err, context.Canceled) {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

func (m *runtimeManager) reconcile(workspace workspaceRecord) (workspaceReconcileOutcome, error) {
	result, err, _ := m.reconcileGroup.Do(workspace.WorkspaceID, func() (interface{}, error) {
		staleActor, busy := m.detachInactiveActor(workspace.WorkspaceID)
		if busy {
			return workspaceReconcileOutcomeBusy, nil
		}
		if staleActor != nil {
			if err := closeWorkspaceActor(staleActor); err != nil {
				return workspaceReconcileOutcomeBusy, err
			}
		}

		if _, err := m.ensure(workspace); err != nil {
			if runtimeInstanceBusy(err) {
				return workspaceReconcileOutcomeBusy, nil
			}
			return workspaceReconcileOutcomeBusy, err
		}
		return workspaceReconcileOutcomeReconciled, nil
	})
	if err != nil {
		return workspaceReconcileOutcomeBusy, err
	}
	outcome, ok := result.(workspaceReconcileOutcome)
	if !ok {
		return workspaceReconcileOutcomeBusy, errors.New("unexpected reconcile outcome")
	}
	return outcome, nil
}

func (m *runtimeManager) ensure(workspace workspaceRecord) (*workspaceActor, error) {
	if actor, staleActor := m.activeOrDetachedActor(workspace.WorkspaceID); actor != nil {
		return actor, nil
	} else if staleActor != nil {
		_ = closeWorkspaceActor(staleActor)
	}

	service, err := m.factory(workspace.Path)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithCancel(context.Background())
	actor := &workspaceActor{
		workspaceID: workspace.WorkspaceID,
		workDir:     workspace.Path,
		service:     service,
		cancel:      cancel,
		running:     true,
	}

	m.mu.Lock()
	m.actors[workspace.WorkspaceID] = actor
	m.mu.Unlock()

	go m.runActor(ctx, actor)
	go m.forwardActorEvents(ctx, actor)
	return actor, nil
}

func (m *runtimeManager) runActor(ctx context.Context, actor *workspaceActor) {
	err := actor.service.Run(ctx)
	actor.mu.Lock()
	actor.running = false
	if err != nil && !errors.Is(err, context.Canceled) {
		actor.lastError = err.Error()
	}
	actor.mu.Unlock()
}

func (m *runtimeManager) forwardActorEvents(ctx context.Context, actor *workspaceActor) {
	for {
		select {
		case <-ctx.Done():
			return
		case event := <-actor.service.Events():
			if m.onEvent != nil {
				m.onEvent(actor.workspaceID, event)
			}
		}
	}
}

func closeWorkspaceActor(actor *workspaceActor) error {
	if actor == nil {
		return nil
	}
	actor.cancel()
	actor.mu.Lock()
	actor.running = false
	actor.mu.Unlock()
	return actor.service.Close()
}

func (a *workspaceActor) isRunning() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.running
}

func (m *runtimeManager) activeOrDetachedActor(workspaceID string) (active *workspaceActor, stale *workspaceActor) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if actor, ok := m.actors[workspaceID]; ok {
		if actor.isRunning() {
			return actor, nil
		}
		delete(m.actors, workspaceID)
		return nil, actor
	}
	return nil, nil
}

func (m *runtimeManager) detachInactiveActor(workspaceID string) (*workspaceActor, bool) {
	active, stale := m.activeOrDetachedActor(workspaceID)
	if active != nil {
		return nil, true
	}
	return stale, false
}

func runtimeInstanceBusy(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(strings.ToLower(err.Error()), "already running in this directory")
}
