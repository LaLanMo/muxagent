package appserver

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	goruntime "runtime"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/appwire"
	appconfig "github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/taskconfig"
	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor/codex"
	"github.com/LaLanMo/muxagent/cli/internal/taskhistory"
	"github.com/LaLanMo/muxagent/cli/internal/taskruntime"
	"github.com/LaLanMo/muxagent/cli/internal/taskstore"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
)

func TestServerRejectsCallsBeforeInitialize(t *testing.T) {
	server := newTestServer(t)

	var in bytes.Buffer
	var out bytes.Buffer
	writeRequestFrame(t, &in, 1, methodServiceStatus, map[string]any{})

	if err := server.Serve(context.Background(), &in, &out); err != nil {
		t.Fatalf("serve: %v", err)
	}

	messages := readFramesAsMaps(t, out.Bytes())
	if len(messages) != 1 {
		t.Fatalf("message count = %d, want 1", len(messages))
	}
	if got := nestedFloat(messages[0], "error", "code"); int(got) != int(errorCodeNotInitialized) {
		t.Fatalf("error code = %v, want %d", got, errorCodeNotInitialized)
	}
}

func TestServerWorkspaceLifecycle(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()

	server := newTestServerAtPath(t, stateDir)
	var firstIn bytes.Buffer
	var firstOut bytes.Buffer
	writeRequestFrame(t, &firstIn, 1, methodInitialize, map[string]any{"protocol_version": protocolVersion})
	writeRequestFrame(t, &firstIn, 2, methodWorkspaceAdd, map[string]any{
		"path":         workspacePath,
		"display_name": "cmdr",
	})
	writeRequestFrame(t, &firstIn, 3, methodServiceShutdown, map[string]any{})

	if err := server.Serve(context.Background(), &firstIn, &firstOut); err != nil {
		t.Fatalf("serve add flow: %v", err)
	}

	firstMessages := readFramesAsMaps(t, firstOut.Bytes())
	addResponse := responseByID(t, firstMessages, 2)
	workspaceID, ok := nestedString(addResponse, "result", "workspace", "workspace_id")
	if !ok || workspaceID == "" {
		t.Fatalf("workspace_id missing in add response: %#v", addResponse)
	}

	server = newTestServerAtPath(t, stateDir)
	var secondIn bytes.Buffer
	var secondOut bytes.Buffer
	writeRequestFrame(t, &secondIn, 1, methodInitialize, map[string]any{"protocol_version": protocolVersion})
	writeRequestFrame(t, &secondIn, 2, methodServiceStatus, map[string]any{})
	writeRequestFrame(t, &secondIn, 3, methodWorkspaceUpdate, map[string]any{
		"workspace_id": workspaceID,
		"display_name": "cmdr core",
	})
	writeRequestFrame(t, &secondIn, 4, methodWorkspaceGet, map[string]any{
		"workspace_id": workspaceID,
	})
	writeRequestFrame(t, &secondIn, 5, methodWorkspaceList, map[string]any{})
	writeRequestFrame(t, &secondIn, 6, methodWorkspaceRemove, map[string]any{
		"workspace_id": workspaceID,
	})
	writeRequestFrame(t, &secondIn, 7, methodServiceShutdown, map[string]any{})

	if err := server.Serve(context.Background(), &secondIn, &secondOut); err != nil {
		t.Fatalf("serve lifecycle: %v", err)
	}

	secondMessages := readFramesAsMaps(t, secondOut.Bytes())
	statusResponse := responseByID(t, secondMessages, 2)
	updateResponse := responseByID(t, secondMessages, 3)
	getResponse := responseByID(t, secondMessages, 4)
	listResponse := responseByID(t, secondMessages, 5)
	removeResponse := responseByID(t, secondMessages, 6)

	if got := nestedFloat(statusResponse, "result", "workspace_count"); int(got) != 1 {
		t.Fatalf("workspace_count = %v, want 1", got)
	}
	if got := nestedStringMust(t, updateResponse, "result", "workspace", "display_name"); got != "cmdr core" {
		t.Fatalf("updated display_name = %q, want %q", got, "cmdr core")
	}
	if got := nestedStringMust(t, getResponse, "result", "workspace", "display_name"); got != "cmdr core" {
		t.Fatalf("get display_name = %q, want %q", got, "cmdr core")
	}
	if got := len(nestedSlice(t, listResponse, "result", "workspaces")); got != 1 {
		t.Fatalf("workspace list count = %d, want 1", got)
	}
	if removed, _ := nestedBool(removeResponse, "result", "removed"); !removed {
		t.Fatalf("removed = false, want true")
	}

	var sawAddNotification bool
	var sawUpdateNotification bool
	var sawRemoveNotification bool
	for _, message := range append(firstMessages, secondMessages...) {
		if method, _ := nestedString(message, "method"); method != methodNotification {
			continue
		}
		kind, _ := nestedString(message, "params", "kind")
		switch kind {
		case notificationWorkspaceAdded:
			sawAddNotification = true
		case notificationWorkspaceUpdated:
			sawUpdateNotification = true
		case notificationWorkspaceRemoved:
			sawRemoveNotification = true
		}
	}
	if !sawAddNotification || !sawUpdateNotification || !sawRemoveNotification {
		t.Fatalf("notifications missing: add=%v update=%v remove=%v", sawAddNotification, sawUpdateNotification, sawRemoveNotification)
	}
}

func TestServerTaskReadFlows(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		loadCatalog: func() (*taskconfig.Catalog, error) {
			cfg, err := taskconfig.LoadDefault()
			if err != nil {
				return nil, err
			}
			return &taskconfig.Catalog{
				DefaultAlias: "default",
				Entries: []taskconfig.CatalogEntry{{
					Alias:     "default",
					Path:      "/tmp/default/config.yaml",
					Config:    cfg,
					Builtin:   true,
					BuiltinID: "default",
				}},
			}, nil
		},
		loadRegistry: func() (taskconfig.Registry, error) {
			return taskconfig.Registry{
				DefaultAlias: "default",
				Configs: []taskconfig.RegistryEntry{{
					Alias: "default",
					Path:  "default",
				}},
			}, nil
		},
		loadTaskLaunchPreferences: func() appconfig.TaskLaunchPreferences {
			return appconfig.TaskLaunchPreferences{UseWorktree: true}
		},
	})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID, awaitingRunID := seedAwaitingTask(t, workspacePath)
	server.markInitialized()

	listResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskList,
		Params: mustRawParams(t, taskListParams{WorkspaceID: workspace.WorkspaceID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.list rpc error: %+v", rpcErr)
	}
	listResult := listResultAny.(taskListResult)
	if got := len(listResult.Tasks); got != 1 {
		t.Fatalf("task.list count = %d, want 1", got)
	}
	if got := listResult.Tasks[0].Status; got != string(taskdomain.TaskStatusAwaitingUser) {
		t.Fatalf("task.list status = %q, want %q", got, taskdomain.TaskStatusAwaitingUser)
	}

	getResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{WorkspaceID: workspace.WorkspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get rpc error: %+v", rpcErr)
	}
	getResult := getResultAny.(taskGetResult)
	if getResult.InputRequest == nil {
		t.Fatal("task.get input_request = nil, want value")
	}
	if got := getResult.InputRequest.NodeRunID; got != awaitingRunID {
		t.Fatalf("task.get input_request.node_run_id = %q, want %q", got, awaitingRunID)
	}

	server.handleRuntimeEvent(workspace.WorkspaceID, taskruntime.RunEvent{
		Type:      taskruntime.EventNodeStarted,
		TaskID:    taskID,
		NodeRunID: awaitingRunID,
		NodeName:  "approve_plan",
	})
	server.handleRuntimeEvent(workspace.WorkspaceID, taskruntime.RunEvent{
		Type:      taskruntime.EventNodeProgress,
		TaskID:    taskID,
		NodeRunID: awaitingRunID,
		NodeName:  "approve_plan",
		Progress: &taskruntime.ProgressInfo{
			Message: "approval pending",
			Events: []taskexecutor.StreamEvent{
				{
					Kind: taskexecutor.StreamEventKindTool,
					Tool: &taskexecutor.ToolCall{
						Name:         "Read",
						Kind:         taskexecutor.ToolKindRead,
						Status:       taskexecutor.ToolStatusCompleted,
						InputSummary: "/tmp/plan.md",
					},
				},
			},
		},
	})

	getResultAny, _, _, rpcErr = server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{WorkspaceID: workspace.WorkspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get live output rpc error: %+v", rpcErr)
	}
	getResult = getResultAny.(taskGetResult)
	if got := getResult.LiveOutputRunID; got != awaitingRunID {
		t.Fatalf("task.get live_output_run_id = %q, want %q", got, awaitingRunID)
	}
	if got := len(getResult.LiveEvents); got != 1 {
		t.Fatalf("task.get live_events length = %d, want 1", got)
	}
	if got := getResult.LiveEvents[0].Kind; got != string(taskexecutor.StreamEventKindTool) {
		t.Fatalf("task.get live_events[0].kind = %q, want %q", got, taskexecutor.StreamEventKindTool)
	}
	if got := getResult.LiveEvents[0].InputSummary; got != "/tmp/plan.md" {
		t.Fatalf("task.get live_events[0].input_summary = %q, want %q", got, "/tmp/plan.md")
	}

	err = taskhistory.Append(workspacePath, taskID, awaitingRunID, taskexecutor.Progress{
		SessionID: "session-123",
		Events: []taskexecutor.StreamEvent{
			{
				EventID:    "evt-read",
				Seq:        1,
				EmittedAt:  time.Date(2026, 4, 3, 12, 1, 0, 0, time.UTC),
				SessionID:  "session-123",
				Kind:       taskexecutor.StreamEventKindTool,
				Provenance: taskexecutor.StreamEventProvenanceExecutorPersisted,
				Tool: &taskexecutor.ToolCall{
					Name:         "Read",
					Kind:         taskexecutor.ToolKindRead,
					Status:       taskexecutor.ToolStatusCompleted,
					InputSummary: "plan.md",
				},
			},
		},
	}, time.Date(2026, 4, 3, 12, 1, 0, 0, time.UTC))
	if err != nil {
		t.Fatalf("append history: %v", err)
	}
	err = taskhistory.Append(workspacePath, taskID, awaitingRunID, taskexecutor.Progress{
		SessionID: "session-123",
		Events: []taskexecutor.StreamEvent{
			{
				EventID:    "evt-approval",
				Seq:        2,
				EmittedAt:  time.Date(2026, 4, 3, 12, 1, 15, 0, time.UTC),
				SessionID:  "session-123",
				Kind:       taskexecutor.StreamEventKindMessage,
				Provenance: taskexecutor.StreamEventProvenanceExecutorPersisted,
				Message: &taskexecutor.MessagePart{
					MessageID: "msg-approval",
					PartID:    "part-approval",
					Role:      taskexecutor.MessageRoleAssistant,
					Type:      taskexecutor.MessagePartTypeText,
					Text:      "approval pending",
				},
			},
		},
	}, time.Date(2026, 4, 3, 12, 1, 15, 0, time.UTC))
	if err != nil {
		t.Fatalf("append message history: %v", err)
	}

	historyResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRunHistory,
		Params: mustRawParams(t, taskRunHistoryParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   awaitingRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.run_history rpc error: %+v", rpcErr)
	}
	historyResult := historyResultAny.(taskRunHistoryResult)
	if got := historyResult.Provenance; got != "executor_persisted" {
		t.Fatalf("task.run_history provenance = %q, want executor_persisted", got)
	}
	if got := historyResult.Completeness; got != "complete" {
		t.Fatalf("task.run_history completeness = %q, want complete", got)
	}
	if got := historyResult.SessionID; got != "session-123" {
		t.Fatalf("task.run_history session_id = %q, want session-123", got)
	}
	if got := len(historyResult.Events); got != 2 {
		t.Fatalf("task.run_history event count = %d, want 2", got)
	}
	if got := historyResult.Events[0].Name; got != "Read" {
		t.Fatalf("task.run_history first tool name = %q, want Read", got)
	}
	if got := historyResult.Events[1].Text; got != "approval pending" {
		t.Fatalf("task.run_history second message = %q, want approval pending", got)
	}

	inputResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskInputRequest,
		Params: mustRawParams(t, taskInputRequestParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   awaitingRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.input_request rpc error: %+v", rpcErr)
	}
	inputResult := inputResultAny.(taskInputRequestResult)
	if inputResult.InputRequest == nil || inputResult.InputRequest.Kind != string(taskruntime.InputKindHumanNode) {
		t.Fatalf("task.input_request kind = %#v, want human_node", inputResult.InputRequest)
	}

	artifactResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodArtifactList,
		Params: mustRawParams(t, artifactListParams{WorkspaceID: workspace.WorkspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("artifact.list rpc error: %+v", rpcErr)
	}
	artifactResult := artifactResultAny.(artifactListResult)
	if got := len(artifactResult.Artifacts); got != 1 {
		t.Fatalf("artifact.list count = %d, want 1", got)
	}
	if got := artifactResult.Artifacts[0].PreviewName; got != "plan.md" {
		t.Fatalf("artifact preview_name = %q, want plan.md", got)
	}

	catalogResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigCatalog,
		Params: mustRawParams(t, map[string]any{}),
	})
	if rpcErr != nil {
		t.Fatalf("config.catalog rpc error: %+v", rpcErr)
	}
	catalogResult := catalogResultAny.(configCatalogResult)
	if catalogResult.DefaultAlias != "default" {
		t.Fatalf("default_alias = %q, want default", catalogResult.DefaultAlias)
	}
	if !catalogResult.DefaultUseWorktree {
		t.Fatal("default_use_worktree = false, want true")
	}
}

func TestServerTaskGetOmitsFollowUpMetadataForCompletedNonGitTask(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedAppServerTask(t, workspacePath, "task-non-git-follow-up", "Completed plain task", workspacePath)
	server.markInitialized()

	getResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{WorkspaceID: workspace.WorkspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get rpc error: %+v", rpcErr)
	}
	getResult := getResultAny.(taskGetResult)
	if getResult.FollowUp != nil {
		t.Fatalf("task.get follow_up = %#v, want nil", getResult.FollowUp)
	}
	if got := getResult.FollowUpState; got != followUpStateBasic {
		t.Fatalf("task.get follow_up_state = %q, want %q", got, followUpStateBasic)
	}
}

func TestServerTaskGetIncludesFollowUpMetadataForCompletedRepoBackedMainCheckoutTask(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedRepoBackedMainCheckoutTask(t, workspacePath)
	server.markInitialized()

	assertTaskGetFollowUpMetadata(t, server, workspace.WorkspaceID, taskID, 3)
}

func TestServerTaskGetIncludesFollowUpMetadataForCompletedWorktreeTask(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedWorktreeTask(t, workspacePath)
	server.markInitialized()

	assertTaskGetFollowUpMetadata(t, server, workspace.WorkspaceID, taskID, 3)
}

func TestServerTaskGetDisablesFollowUpForCompletedTaskWithMissingWorktree(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedWorktreeTask(t, workspacePath)
	server.markInitialized()

	store, err := taskstore.Open(workspacePath)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	task, err := store.GetTask(context.Background(), taskID)
	if closeErr := store.Close(); err == nil && closeErr != nil {
		err = closeErr
	}
	if err != nil {
		t.Fatalf("load task: %v", err)
	}
	parentWorktreeRoot, err := worktree.FindRepoRoot(task.ExecutionDir)
	if err != nil {
		t.Fatalf("find parent worktree root: %v", err)
	}
	if err := os.RemoveAll(parentWorktreeRoot); err != nil {
		t.Fatalf("remove parent worktree root: %v", err)
	}

	getResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{WorkspaceID: workspace.WorkspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get rpc error: %+v", rpcErr)
	}
	getResult := getResultAny.(taskGetResult)
	if getResult.FollowUp != nil {
		t.Fatalf("task.get follow_up = %#v, want nil", getResult.FollowUp)
	}
	if got := getResult.FollowUpState; got != followUpStateDisabled {
		t.Fatalf("task.get follow_up_state = %q, want %q", got, followUpStateDisabled)
	}
}

func TestServerTaskGetKeepsWorktreeTaskDisabledWhenWorkspaceRepoMetadataIsGone(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedWorktreeTask(t, workspacePath)
	server.markInitialized()

	store, err := taskstore.Open(workspacePath)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	task, err := store.GetTask(context.Background(), taskID)
	if closeErr := store.Close(); err == nil && closeErr != nil {
		err = closeErr
	}
	if err != nil {
		t.Fatalf("load task: %v", err)
	}
	parentWorktreeRoot, err := worktree.FindRepoRoot(task.ExecutionDir)
	if err != nil {
		t.Fatalf("find parent worktree root: %v", err)
	}
	if err := os.RemoveAll(parentWorktreeRoot); err != nil {
		t.Fatalf("remove parent worktree root: %v", err)
	}
	if err := os.RemoveAll(filepath.Join(repoRoot, ".git")); err != nil {
		t.Fatalf("remove repo metadata: %v", err)
	}

	getResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{WorkspaceID: workspace.WorkspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get rpc error: %+v", rpcErr)
	}
	getResult := getResultAny.(taskGetResult)
	if getResult.FollowUp != nil {
		t.Fatalf("task.get follow_up = %#v, want nil", getResult.FollowUp)
	}
	if got := getResult.FollowUpState; got != followUpStateDisabled {
		t.Fatalf("task.get follow_up_state = %q, want %q", got, followUpStateDisabled)
	}
}

func TestServerTaskGetWorktreeCleanupInfoReturnsNotApplicableForCompletedPlainTask(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedAppServerTask(t, workspacePath, "task-non-git-cleanup", "Completed plain task", workspacePath)
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGetWorktreeCleanupInfo,
		Params: mustRawParams(t, taskGetWorktreeCleanupInfoParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get_worktree_cleanup_info rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskGetWorktreeCleanupInfoResult)
	if got := result.Info.State; got != worktreeCleanupStateNotApplicable {
		t.Fatalf("cleanup info state = %q, want %q", got, worktreeCleanupStateNotApplicable)
	}
	if result.Info.CanRemove {
		t.Fatal("cleanup info can_remove = true, want false")
	}
}

func TestServerTaskGetWorktreeCleanupInfoReturnsAvailableForCompletedWorktreeTask(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedWorktreeTask(t, workspacePath)
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGetWorktreeCleanupInfo,
		Params: mustRawParams(t, taskGetWorktreeCleanupInfoParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get_worktree_cleanup_info rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskGetWorktreeCleanupInfoResult)
	if got := result.Info.State; got != worktreeCleanupStateAvailable {
		t.Fatalf("cleanup info state = %q, want %q", got, worktreeCleanupStateAvailable)
	}
	if got := result.Info.RemovalScope; got != worktreeRemovalScopeSingle {
		t.Fatalf("cleanup info removal_scope = %q, want %q", got, worktreeRemovalScopeSingle)
	}
	if got := result.Info.SharedTaskCount; got != 1 {
		t.Fatalf("cleanup info shared_task_count = %d, want 1", got)
	}
	if !result.Info.CanRemove {
		t.Fatal("cleanup info can_remove = false, want true")
	}
}

func TestServerTaskGetWorktreeCleanupInfoBlocksSharedWorktreeWithLiveSibling(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	completedTaskID, liveTaskID, _ := seedSharedWorktreeTasks(t, workspacePath)
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGetWorktreeCleanupInfo,
		Params: mustRawParams(t, taskGetWorktreeCleanupInfoParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      completedTaskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get_worktree_cleanup_info rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskGetWorktreeCleanupInfoResult)
	if got := result.Info.State; got != worktreeCleanupStateBlocked {
		t.Fatalf("cleanup info state = %q, want %q", got, worktreeCleanupStateBlocked)
	}
	if got := result.Info.RemovalScope; got != worktreeRemovalScopeShared {
		t.Fatalf("cleanup info removal_scope = %q, want %q", got, worktreeRemovalScopeShared)
	}
	if got := result.Info.SharedTaskCount; got != 2 {
		t.Fatalf("cleanup info shared_task_count = %d, want 2", got)
	}
	if result.Info.CanRemove {
		t.Fatal("cleanup info can_remove = true, want false")
	}
	if got := len(result.Info.BlockedBy); got != 1 {
		t.Fatalf("cleanup info blocked_by len = %d, want 1", got)
	}
	if got := result.Info.BlockedBy[0].TaskID; got != liveTaskID {
		t.Fatalf("cleanup info blocked_by[0].task_id = %q, want %q", got, liveTaskID)
	}

	cleanupAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskCleanupWorktree,
		Params: mustRawParams(t, taskCleanupWorktreeParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      completedTaskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.cleanup_worktree rpc error: %+v", rpcErr)
	}
	cleanupResult := cleanupAny.(taskCleanupWorktreeResult)
	if got := cleanupResult.Outcome; got != worktreeCleanupOutcomeBlocked {
		t.Fatalf("cleanup outcome = %q, want %q", got, worktreeCleanupOutcomeBlocked)
	}
}

func TestServerTaskGetWorktreeCleanupInfoIgnoresUnrelatedWorktrees(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	targetTaskID := seedCompletedWorktreeTask(t, workspacePath)

	unrelatedRoot, err := worktree.Create(repoRoot, "appserver-unrelated-worktree")
	if err != nil {
		t.Fatalf("create unrelated worktree: %v", err)
	}
	unrelatedExecutionDir := filepath.Join(unrelatedRoot, "packages", "app")
	seedCompletedAppServerTask(
		t,
		workspacePath,
		"task-unrelated-worktree",
		"Completed unrelated worktree task",
		unrelatedExecutionDir,
	)
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGetWorktreeCleanupInfo,
		Params: mustRawParams(t, taskGetWorktreeCleanupInfoParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      targetTaskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get_worktree_cleanup_info rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskGetWorktreeCleanupInfoResult)
	if got := result.Info.State; got != worktreeCleanupStateAvailable {
		t.Fatalf("cleanup info state = %q, want %q", got, worktreeCleanupStateAvailable)
	}
	if got := result.Info.SharedTaskCount; got != 1 {
		t.Fatalf("cleanup info shared_task_count = %d, want 1", got)
	}
	if got := result.Info.RemovalScope; got != worktreeRemovalScopeSingle {
		t.Fatalf("cleanup info removal_scope = %q, want %q", got, worktreeRemovalScopeSingle)
	}
	if !result.Info.CanRemove {
		t.Fatal("cleanup info can_remove = false, want true")
	}
}

func TestServerTaskGetWorktreeCleanupInfoReturnsMissingAfterWorktreeRemoved(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedWorktreeTask(t, workspacePath)
	server.markInitialized()

	store, err := taskstore.Open(workspacePath)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	task, err := store.GetTask(context.Background(), taskID)
	if closeErr := store.Close(); err == nil && closeErr != nil {
		err = closeErr
	}
	if err != nil {
		t.Fatalf("load task: %v", err)
	}
	worktreeRoot, err := worktree.FindRepoRoot(task.ExecutionDir)
	if err != nil {
		t.Fatalf("find worktree root: %v", err)
	}
	if err := os.RemoveAll(worktreeRoot); err != nil {
		t.Fatalf("remove worktree root: %v", err)
	}

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGetWorktreeCleanupInfo,
		Params: mustRawParams(t, taskGetWorktreeCleanupInfoParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get_worktree_cleanup_info rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskGetWorktreeCleanupInfoResult)
	if got := result.Info.State; got != worktreeCleanupStateMissing {
		t.Fatalf("cleanup info state = %q, want %q", got, worktreeCleanupStateMissing)
	}
	if result.Info.CanRemove {
		t.Fatal("cleanup info can_remove = true, want false")
	}
}

func TestServerTaskCleanupWorktreeRemovesWorktreeButKeepsBranch(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	repoRoot := seedAppServerGitRepo(t)
	workspacePath := filepath.Join(repoRoot, "packages", "app")

	server := newTestServerWithOptions(t, stateDir, testServerOptions{})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID := seedCompletedWorktreeTask(t, workspacePath)
	server.markInitialized()

	store, err := taskstore.Open(workspacePath)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	task, err := store.GetTask(context.Background(), taskID)
	if closeErr := store.Close(); err == nil && closeErr != nil {
		err = closeErr
	}
	if err != nil {
		t.Fatalf("load task: %v", err)
	}
	worktreeRoot, err := worktree.FindRepoRoot(task.ExecutionDir)
	if err != nil {
		t.Fatalf("find worktree root: %v", err)
	}

	cleanupAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskCleanupWorktree,
		Params: mustRawParams(t, taskCleanupWorktreeParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.cleanup_worktree rpc error: %+v", rpcErr)
	}
	cleanupResult := cleanupAny.(taskCleanupWorktreeResult)
	if got := cleanupResult.Outcome; got != worktreeCleanupOutcomeRemoved {
		t.Fatalf("cleanup outcome = %q, want %q", got, worktreeCleanupOutcomeRemoved)
	}
	if cleanupResult.Info == nil {
		t.Fatal("cleanup result info = nil, want value")
	}
	if got := cleanupResult.Info.State; got != worktreeCleanupStateMissing {
		t.Fatalf("cleanup result info.state = %q, want %q", got, worktreeCleanupStateMissing)
	}
	if _, err := os.Stat(worktreeRoot); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("worktree root still exists after cleanup: %v", err)
	}

	branchOutput, err := exec.Command("git", "-C", repoRoot, "branch", "--list", worktree.BranchName("appserver-follow-up-parent")).CombinedOutput()
	if err != nil {
		t.Fatalf("git branch --list: %v (%s)", err, strings.TrimSpace(string(branchOutput)))
	}
	if got := strings.TrimSpace(string(branchOutput)); !strings.Contains(got, worktree.BranchName("appserver-follow-up-parent")) {
		t.Fatalf("branch listing = %q, want worktree branch to remain", got)
	}
}

func TestServerInitializeAdvertisesTaskGetAncestry(t *testing.T) {
	server := newTestServer(t)

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("initialize rpc error: %+v", rpcErr)
	}
	result := resultAny.(initializeResult)
	if !slices.Contains(result.Capabilities.Methods, methodTaskGetAncestry) {
		t.Fatalf("initialize capabilities missing %q: %#v", methodTaskGetAncestry, result.Capabilities.Methods)
	}
	if !slices.Contains(result.Capabilities.Methods, methodTaskGetWorktreeCleanupInfo) {
		t.Fatalf("initialize capabilities missing %q: %#v", methodTaskGetWorktreeCleanupInfo, result.Capabilities.Methods)
	}
	if !slices.Contains(result.Capabilities.Methods, methodTaskCleanupWorktree) {
		t.Fatalf("initialize capabilities missing %q: %#v", methodTaskCleanupWorktree, result.Capabilities.Methods)
	}
	if !slices.Contains(result.Capabilities.Methods, methodTaskRunHistoryFull) {
		t.Fatalf("initialize capabilities missing %q: %#v", methodTaskRunHistoryFull, result.Capabilities.Methods)
	}
	if !slices.Contains(result.Capabilities.Methods, methodRuntimeStatus) {
		t.Fatalf("initialize capabilities missing %q: %#v", methodRuntimeStatus, result.Capabilities.Methods)
	}
	if !slices.Contains(result.Capabilities.Methods, methodAgentChatRPC) {
		t.Fatalf("initialize capabilities missing %q: %#v", methodAgentChatRPC, result.Capabilities.Methods)
	}
	if !slices.Contains(result.Capabilities.Notifications, notificationAgentChatStreamItem) {
		t.Fatalf("initialize capabilities missing notification %q: %#v", notificationAgentChatStreamItem, result.Capabilities.Notifications)
	}
	if slices.Contains(result.Capabilities.Notifications, "agentchat.event") {
		t.Fatalf("initialize capabilities still advertise legacy agentchat.event: %#v", result.Capabilities.Notifications)
	}
}

func TestServerAgentChatRPCProxiesToDaemonClient(t *testing.T) {
	fake := &fakeAgentChatClient{
		call: func(_ context.Context, req appwire.RPCRequest) (appwire.RPCResponse, error) {
			if req.Method != "runtime.list" {
				t.Fatalf("method = %q, want runtime.list", req.Method)
			}
			return appwire.RPCResponse{
				Result: json.RawMessage(`{"runtimes":[{"id":"codex","label":"Codex","ready":true}]}`),
			}, nil
		},
	}
	server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
		agentChatClient: fake,
	})

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodAgentChatRPC,
		Params: mustRawParams(t, appwire.RPCRequest{Method: "runtime.list"}),
	})
	if rpcErr != nil {
		t.Fatalf("agentchat.rpc error: %+v", rpcErr)
	}
	var result map[string]any
	if err := json.Unmarshal(resultAny.(json.RawMessage), &result); err != nil {
		t.Fatalf("unmarshal result: %v", err)
	}
	runtimes := result["runtimes"].([]any)
	runtime := runtimes[0].(map[string]any)
	if runtime["id"] != "codex" {
		t.Fatalf("runtime id = %v, want codex", runtime["id"])
	}
}

func TestServerAgentChatRPCMapsDaemonErrorToTopLevelJSONRPCError(t *testing.T) {
	server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
		agentChatClient: &fakeAgentChatClient{
			call: func(context.Context, appwire.RPCRequest) (appwire.RPCResponse, error) {
				return appwire.RPCResponse{Error: "missing cwd"}, nil
			},
		},
	})

	_, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodAgentChatRPC,
		Params: mustRawParams(t, appwire.RPCRequest{Method: "session.create"}),
	})
	if rpcErr == nil || rpcErr.Message != "missing cwd" {
		t.Fatalf("rpcErr = %+v, want missing cwd", rpcErr)
	}
}

func TestServerAgentChatRPCDoesNotEmitScopedEventNotifications(t *testing.T) {
	server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
		agentChatClient: &fakeAgentChatClient{
			call: func(context.Context, appwire.RPCRequest) (appwire.RPCResponse, error) {
				return appwire.RPCResponse{
					Result: json.RawMessage(`{"ok":true}`),
				}, nil
			},
		},
	})
	session := &connectionSession{id: "session-agentchat"}

	result, notifications, _, rpcErr := server.handleSessionRequest(context.Background(), session, request{
		Method: methodAgentChatRPC,
		Params: mustRawParams(t, appwire.RPCRequest{Method: "session.load"}),
	})
	if rpcErr != nil {
		t.Fatalf("agentchat.rpc error: %+v", rpcErr)
	}
	raw, ok := result.(json.RawMessage)
	if !ok || string(raw) != `{"ok":true}` {
		t.Fatalf("result = %#v, want raw ok", result)
	}
	if len(notifications) != 0 {
		t.Fatalf("notifications = %#v, want none", notifications)
	}
}

func TestServerForwardsAgentChatEventsAsStreamItemNotifications(t *testing.T) {
	events := make(chan appwire.EventStreamItem, 1)
	server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
		agentChatClient: &fakeAgentChatClient{events: events},
	})
	sessionCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	outgoing := make(chan any, 8)
	session := &connectionSession{
		id:       "session-agentchat",
		outgoing: outgoing,
		ctx:      sessionCtx,
		cancel:   cancel,
	}

	_, _, _, rpcErr := server.handleSessionRequest(context.Background(), session, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("initialize rpc error: %+v", rpcErr)
	}
	events <- appwire.EventStreamItem{
		Kind:        appwire.EventStreamItemEvent,
		StreamEpoch: 44,
		Event: &appwire.Event{
			Type:      appwire.EventMessageDelta,
			SessionID: "sid-1",
			Seq:       4,
		},
	}

	select {
	case payload := <-outgoing:
		n := payload.(notification)
		if n.Method != notificationAgentChatStreamItem {
			t.Fatalf("notification method = %q, want %q", n.Method, notificationAgentChatStreamItem)
		}
		item := n.Params.(appwire.EventStreamItem)
		if item.Kind != appwire.EventStreamItemEvent || item.Event == nil || item.Event.SessionID != "sid-1" || item.Event.Seq != 4 {
			t.Fatalf("item = %+v, want event sid-1 seq 4", item)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for agentchat event notification")
	}

	server.mu.Lock()
	backlogLen := len(server.notificationBacklog)
	server.mu.Unlock()
	if backlogLen != 0 {
		t.Fatalf("notification backlog len = %d, want 0", backlogLen)
	}
}

func TestServerForwardsAgentChatReplayEnvelope(t *testing.T) {
	events := make(chan appwire.EventStreamItem, 1)
	server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
		agentChatClient: &fakeAgentChatClient{events: events},
	})
	sessionCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	outgoing := make(chan any, 8)
	session := &connectionSession{
		id:       "session-agentchat",
		outgoing: outgoing,
		ctx:      sessionCtx,
		cancel:   cancel,
	}

	_, _, _, rpcErr := server.handleSessionRequest(context.Background(), session, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("initialize rpc error: %+v", rpcErr)
	}
	events <- appwire.EventStreamItem{
		Kind:               appwire.EventStreamItemReplay,
		Status:             appwire.ResyncStatusReset,
		StreamEpoch:        44,
		ReplayedThroughSeq: 9,
		Events:             []appwire.Event{},
	}

	select {
	case payload := <-outgoing:
		n := payload.(notification)
		if n.Method != notificationAgentChatStreamItem {
			t.Fatalf("notification method = %q, want %q", n.Method, notificationAgentChatStreamItem)
		}
		item := n.Params.(appwire.EventStreamItem)
		if item.Kind != appwire.EventStreamItemReplay ||
			item.Status != appwire.ResyncStatusReset ||
			item.StreamEpoch != 44 ||
			item.ReplayedThroughSeq != 9 ||
			len(item.Events) != 0 {
			t.Fatalf("item = %+v, want empty reset replay envelope", item)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for replay envelope")
	}
}

func TestDecodeAgentChatStreamItemSupportsOnlyEnvelope(t *testing.T) {
	envelopeRaw, err := json.Marshal(appwire.EventStreamItem{
		Kind:               appwire.EventStreamItemReplay,
		Status:             appwire.ResyncStatusOK,
		StreamEpoch:        10,
		ReplayedThroughSeq: 2,
		Events: []appwire.Event{{
			Type:      appwire.EventMessageDelta,
			SessionID: "sid",
			Seq:       2,
		}},
	})
	if err != nil {
		t.Fatalf("marshal envelope: %v", err)
	}
	envelope, ok := decodeAgentChatStreamItem(envelopeRaw)
	if !ok || envelope.Kind != appwire.EventStreamItemReplay || len(envelope.Events) != 1 {
		t.Fatalf("envelope decode = %+v ok=%v", envelope, ok)
	}

	legacyRaw, err := json.Marshal(appwire.Event{
		Type:      appwire.EventRunFinished,
		SessionID: "sid",
		Seq:       3,
	})
	if err != nil {
		t.Fatalf("marshal legacy event: %v", err)
	}
	legacy, ok := decodeAgentChatStreamItem(legacyRaw)
	if ok {
		t.Fatalf("legacy decode = %+v ok=%v, want rejected", legacy, ok)
	}
}

func TestServerInitializeDoesNotStartDuplicateAgentChatEventProxy(t *testing.T) {
	subscribeCalls := make(chan struct{}, 2)
	server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
		agentChatClient: &fakeAgentChatClient{
			subscribe: func(ctx context.Context, _, _ uint64) (<-chan appwire.EventStreamItem, error) {
				subscribeCalls <- struct{}{}
				events := make(chan appwire.EventStreamItem)
				go func() {
					<-ctx.Done()
					close(events)
				}()
				return events, nil
			},
		},
	})
	sessionCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	session := &connectionSession{
		id:       "session-agentchat",
		outgoing: make(chan any, 8),
		ctx:      sessionCtx,
		cancel:   cancel,
	}

	for i := 0; i < 2; i++ {
		_, _, _, rpcErr := server.handleSessionRequest(context.Background(), session, request{
			Method: methodInitialize,
			Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
		})
		if rpcErr != nil {
			t.Fatalf("initialize %d rpc error: %+v", i+1, rpcErr)
		}
	}

	select {
	case <-subscribeCalls:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for first agentchat subscription")
	}
	select {
	case <-subscribeCalls:
		t.Fatal("duplicate agentchat subscription started for same session")
	case <-time.After(100 * time.Millisecond):
	}
}

func TestServerAgentChatEventProxyReconnectsFromCursor(t *testing.T) {
	type subscribeCall struct {
		streamEpoch uint64
		afterSeq    uint64
		events      chan appwire.EventStreamItem
		close       func()
	}
	headRaw, err := json.Marshal(appwire.ReplayHeadResult{StreamEpoch: 99, ReplayedThroughSeq: 7})
	if err != nil {
		t.Fatalf("marshal replay head: %v", err)
	}
	subscribeCalls := make(chan subscribeCall, 2)
	server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
		agentChatClient: &fakeAgentChatClient{
			call: func(_ context.Context, req appwire.RPCRequest) (appwire.RPCResponse, error) {
				if req.Method == "events.head" {
					return appwire.RPCResponse{Result: headRaw}, nil
				}
				return appwire.RPCResponse{}, nil
			},
			subscribe: func(ctx context.Context, streamEpoch, afterSeq uint64) (<-chan appwire.EventStreamItem, error) {
				events := make(chan appwire.EventStreamItem, 1)
				var closeOnce sync.Once
				closeEvents := func() {
					closeOnce.Do(func() { close(events) })
				}
				subscribeCalls <- subscribeCall{
					streamEpoch: streamEpoch,
					afterSeq:    afterSeq,
					events:      events,
					close:       closeEvents,
				}
				go func() {
					<-ctx.Done()
					closeEvents()
				}()
				return events, nil
			},
		},
	})
	sessionCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	outgoing := make(chan any, 8)
	session := &connectionSession{
		id:       "session-agentchat",
		outgoing: outgoing,
		ctx:      sessionCtx,
		cancel:   cancel,
	}

	_, _, _, rpcErr := server.handleSessionRequest(context.Background(), session, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("initialize rpc error: %+v", rpcErr)
	}

	var first subscribeCall
	select {
	case first = <-subscribeCalls:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for first agentchat subscription")
	}
	if first.streamEpoch != 99 || first.afterSeq != 0 {
		t.Fatalf("first subscription = epoch %d after %d, want epoch 99 after 0", first.streamEpoch, first.afterSeq)
	}
	first.events <- appwire.EventStreamItem{
		Kind: appwire.EventStreamItemEvent,
		Event: &appwire.Event{
			Type:      appwire.EventMessageDelta,
			SessionID: "sid-1",
			Seq:       4,
		},
	}
	first.close()

	select {
	case <-outgoing:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for first forwarded event")
	}

	var second subscribeCall
	select {
	case second = <-subscribeCalls:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for reconnect subscription")
	}
	if second.streamEpoch != 99 || second.afterSeq != 4 {
		t.Fatalf("second subscription = epoch %d after %d, want epoch 99 after 4", second.streamEpoch, second.afterSeq)
	}
}

func TestServerAgentChatEventProxyRetriesSubscribeErrorsFromCursor(t *testing.T) {
	type subscribeCall struct {
		streamEpoch uint64
		afterSeq    uint64
	}
	headRaw, err := json.Marshal(appwire.ReplayHeadResult{StreamEpoch: 77, ReplayedThroughSeq: 12})
	if err != nil {
		t.Fatalf("marshal replay head: %v", err)
	}
	subscribeCalls := make(chan subscribeCall, 2)
	var subscribeMu sync.Mutex
	subscribeCount := 0
	server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
		agentChatClient: &fakeAgentChatClient{
			call: func(_ context.Context, req appwire.RPCRequest) (appwire.RPCResponse, error) {
				if req.Method == "events.head" {
					return appwire.RPCResponse{Result: headRaw}, nil
				}
				return appwire.RPCResponse{}, nil
			},
			subscribe: func(ctx context.Context, streamEpoch, afterSeq uint64) (<-chan appwire.EventStreamItem, error) {
				subscribeMu.Lock()
				subscribeCount++
				count := subscribeCount
				subscribeMu.Unlock()
				subscribeCalls <- subscribeCall{streamEpoch: streamEpoch, afterSeq: afterSeq}
				if count == 1 {
					return nil, errors.New("daemon stream unavailable")
				}
				events := make(chan appwire.EventStreamItem, 1)
				go func() {
					<-ctx.Done()
					close(events)
				}()
				return events, nil
			},
		},
	})
	sessionCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	session := &connectionSession{
		id:       "session-agentchat",
		outgoing: make(chan any, 8),
		ctx:      sessionCtx,
		cancel:   cancel,
	}

	_, _, _, rpcErr := server.handleSessionRequest(context.Background(), session, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("initialize rpc error: %+v", rpcErr)
	}

	var first subscribeCall
	select {
	case first = <-subscribeCalls:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for first agentchat subscription")
	}
	if first.streamEpoch != 77 || first.afterSeq != 0 {
		t.Fatalf("first subscription = epoch %d after %d, want epoch 77 after 0", first.streamEpoch, first.afterSeq)
	}
	var second subscribeCall
	select {
	case second = <-subscribeCalls:
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for retry agentchat subscription")
	}
	if second.streamEpoch != 77 || second.afterSeq != 0 {
		t.Fatalf("second subscription = epoch %d after %d, want epoch 77 after 0", second.streamEpoch, second.afterSeq)
	}
}

func TestServerRuntimeStatusReflectsAppServerTaskRuntimes(t *testing.T) {
	t.Parallel()

	wantLaunchers := map[appconfig.RuntimeID]string{
		appconfig.RuntimeCodex:      "codex",
		appconfig.RuntimeClaudeCode: "claude",
		appconfig.RuntimeOpenCode:   "opencode",
	}

	tests := []struct {
		name               string
		availableLaunchers map[string]bool
		wantAutomatic      appconfig.RuntimeID
		wantDetected       bool
		wantAvailability   map[appconfig.RuntimeID]bool
	}{
		{
			name:               "codex detected first",
			availableLaunchers: map[string]bool{"codex": true, "claude": true},
			wantAutomatic:      appconfig.RuntimeCodex,
			wantDetected:       true,
			wantAvailability: map[appconfig.RuntimeID]bool{
				appconfig.RuntimeCodex:      true,
				appconfig.RuntimeClaudeCode: true,
				appconfig.RuntimeOpenCode:   false,
			},
		},
		{
			name:               "claude detected when codex missing",
			availableLaunchers: map[string]bool{"claude": true},
			wantAutomatic:      appconfig.RuntimeClaudeCode,
			wantDetected:       true,
			wantAvailability: map[appconfig.RuntimeID]bool{
				appconfig.RuntimeCodex:      false,
				appconfig.RuntimeClaudeCode: true,
				appconfig.RuntimeOpenCode:   false,
			},
		},
		{
			name:               "codex fallback when preferred runtimes missing",
			availableLaunchers: map[string]bool{"opencode": true},
			wantAutomatic:      appconfig.RuntimeCodex,
			wantDetected:       false,
			wantAvailability: map[appconfig.RuntimeID]bool{
				appconfig.RuntimeCodex:      false,
				appconfig.RuntimeClaudeCode: false,
				appconfig.RuntimeOpenCode:   true,
			},
		},
	}

	for _, tt := range tests {
		tt := tt
		t.Run(tt.name, func(t *testing.T) {
			server := newTestServerWithOptions(t, filepath.Join(t.TempDir(), "appserver"), testServerOptions{
				lookPath: func(binary string) (string, error) {
					if tt.availableLaunchers[binary] {
						return filepath.Join("/tmp/fake-bin", binary), nil
					}
					return "", os.ErrNotExist
				},
			})
			server.markInitialized()

			resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
				Method: methodRuntimeStatus,
				Params: mustRawParams(t, map[string]any{}),
			})
			if rpcErr != nil {
				t.Fatalf("runtime.status rpc error: %+v", rpcErr)
			}

			result := resultAny.(runtimeStatusResult)
			if result.Automatic.RuntimeID != tt.wantAutomatic {
				t.Fatalf("automatic runtime_id = %q, want %q", result.Automatic.RuntimeID, tt.wantAutomatic)
			}
			if result.Automatic.RuntimeName != runtimeDisplayName(tt.wantAutomatic) {
				t.Fatalf("automatic runtime_name = %q, want %q", result.Automatic.RuntimeName, runtimeDisplayName(tt.wantAutomatic))
			}
			if result.Automatic.Launcher != wantLaunchers[tt.wantAutomatic] {
				t.Fatalf("automatic launcher = %q, want %q", result.Automatic.Launcher, wantLaunchers[tt.wantAutomatic])
			}
			if result.Automatic.Detected != tt.wantDetected {
				t.Fatalf("automatic detected = %v, want %v", result.Automatic.Detected, tt.wantDetected)
			}
			if result.Automatic.Available != tt.wantAvailability[tt.wantAutomatic] {
				t.Fatalf("automatic available = %v, want %v", result.Automatic.Available, tt.wantAvailability[tt.wantAutomatic])
			}

			runtimeIDs := make([]appconfig.RuntimeID, 0, len(result.Runtimes))
			for _, runtime := range result.Runtimes {
				runtimeIDs = append(runtimeIDs, runtime.RuntimeID)
				wantAvailable, ok := tt.wantAvailability[runtime.RuntimeID]
				if !ok {
					t.Fatalf("unexpected runtime %q in runtime.status", runtime.RuntimeID)
				}
				if runtime.Available != wantAvailable {
					t.Fatalf("runtime %q available = %v, want %v", runtime.RuntimeID, runtime.Available, wantAvailable)
				}
				if runtime.RuntimeName != runtimeDisplayName(runtime.RuntimeID) {
					t.Fatalf("runtime %q runtime_name = %q, want %q", runtime.RuntimeID, runtime.RuntimeName, runtimeDisplayName(runtime.RuntimeID))
				}
				if runtime.Launcher != wantLaunchers[runtime.RuntimeID] {
					t.Fatalf("runtime %q launcher = %q, want %q", runtime.RuntimeID, runtime.Launcher, wantLaunchers[runtime.RuntimeID])
				}
			}
			if !slices.Equal(runtimeIDs, []appconfig.RuntimeID{
				appconfig.RuntimeCodex,
				appconfig.RuntimeClaudeCode,
				appconfig.RuntimeOpenCode,
			}) {
				t.Fatalf("runtime.status runtimes = %#v, want codex/claude-code/opencode", runtimeIDs)
			}
		})
	}
}

func TestServerTaskGetAncestryReturnsRootToParentChain(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	rootTaskID, parentTaskID, childTaskID := seedTaskAncestryChain(t, workspacePath)
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGetAncestry,
		Params: mustRawParams(t, taskGetParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      childTaskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get_ancestry rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskGetAncestryResult)
	if got := len(result.Ancestors); got != 2 {
		t.Fatalf("task.get_ancestry count = %d, want 2", got)
	}
	if got := result.Ancestors[0].TaskID; got != rootTaskID {
		t.Fatalf("task.get_ancestry[0].task_id = %q, want %q", got, rootTaskID)
	}
	if got := result.Ancestors[0].Description; got != "Stabilize authentication pipeline" {
		t.Fatalf("task.get_ancestry[0].description = %q, want %q", got, "Stabilize authentication pipeline")
	}
	if got := result.Ancestors[0].Status; got != string(taskdomain.TaskStatusDone) {
		t.Fatalf("task.get_ancestry[0].status = %q, want %q", got, taskdomain.TaskStatusDone)
	}
	if got := result.Ancestors[0].ParentTaskID; got != "" {
		t.Fatalf("task.get_ancestry[0].parent_task_id = %q, want empty", got)
	}
	if got := result.Ancestors[1].TaskID; got != parentTaskID {
		t.Fatalf("task.get_ancestry[1].task_id = %q, want %q", got, parentTaskID)
	}
	if got := result.Ancestors[1].Description; got != "Harden refresh token handling" {
		t.Fatalf("task.get_ancestry[1].description = %q, want %q", got, "Harden refresh token handling")
	}
	if got := result.Ancestors[1].Status; got != string(taskdomain.TaskStatusDone) {
		t.Fatalf("task.get_ancestry[1].status = %q, want %q", got, taskdomain.TaskStatusDone)
	}
	if got := result.Ancestors[1].ParentTaskID; got != rootTaskID {
		t.Fatalf("task.get_ancestry[1].parent_task_id = %q, want %q", got, rootTaskID)
	}

	rootResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGetAncestry,
		Params: mustRawParams(t, taskGetParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      rootTaskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get_ancestry root rpc error: %+v", rpcErr)
	}
	rootResult := rootResultAny.(taskGetAncestryResult)
	if got := len(rootResult.Ancestors); got != 0 {
		t.Fatalf("task.get_ancestry root count = %d, want 0", got)
	}
}

func TestServerTaskGetAncestryRejectsCycleCorruption(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	rootTaskID, _, childTaskID := seedTaskAncestryChain(t, workspacePath)
	server.markInitialized()

	db, err := sql.Open("sqlite", taskstore.DBPath(workspacePath))
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}
	defer db.Close()
	_, err = db.Exec(`
		INSERT INTO task_edges (parent_task_id, child_task_id, relation_kind, created_at)
		VALUES (?, ?, ?, ?)`,
		childTaskID,
		rootTaskID,
		taskdomain.TaskRelationFollowUp,
		time.Date(2026, 4, 3, 12, 30, 0, 0, time.UTC).Format(time.RFC3339Nano),
	)
	if err != nil {
		t.Fatalf("insert corrupt lineage edge: %v", err)
	}

	_, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGetAncestry,
		Params: mustRawParams(t, taskGetParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      childTaskID,
		}),
	})
	if rpcErr == nil {
		t.Fatal("task.get_ancestry rpc error = nil, want lineage corruption error")
	}
	if rpcErr.Code != errorCodeInternalError {
		t.Fatalf("task.get_ancestry error code = %d, want %d", rpcErr.Code, errorCodeInternalError)
	}
	if !strings.Contains(rpcErr.Message, taskstore.ErrTaskLineageCorrupt.Error()) {
		t.Fatalf("task.get_ancestry error message = %q, want corruption detail", rpcErr.Message)
	}
}

func TestServerTaskRunHistoryFallsBackToProviderTranscript(t *testing.T) {
	workspacePath := t.TempDir()
	codexHome := t.TempDir()
	t.Setenv("CODEX_HOME", codexHome)

	server := newTestServer(t)
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	store, err := taskstore.Open(workspacePath)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	defer func() { _ = store.Close() }()

	taskID := "task-provider-history"
	materialized := materializeEmbeddedDefaultTestConfig(t, workspacePath, taskID)
	configBytes, err := os.ReadFile(materialized.ConfigPath)
	if err != nil {
		t.Fatalf("read materialized config: %v", err)
	}
	configText := strings.Replace(string(configBytes), "runtime: claude-code", "runtime: codex", 1)
	configText = strings.Replace(configText, "runtime: default", "runtime: codex", 1)
	if err := os.WriteFile(materialized.ConfigPath, []byte(configText), 0o644); err != nil {
		t.Fatalf("force codex runtime: %v", err)
	}

	now := time.Date(2026, 4, 8, 10, 0, 0, 0, time.UTC)
	task := taskdomain.Task{
		ID:           taskID,
		Description:  "provider history",
		ConfigAlias:  "default",
		ConfigPath:   materialized.ConfigPath,
		WorkDir:      taskstore.NormalizeWorkDir(workspacePath),
		ExecutionDir: taskstore.NormalizeWorkDir(workspacePath),
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err := store.CreateTask(context.Background(), task); err != nil {
		t.Fatalf("create task: %v", err)
	}
	run := taskdomain.NodeRun{
		ID:        "run-provider-history",
		TaskID:    taskID,
		NodeName:  "draft_plan",
		Status:    taskdomain.NodeRunRunning,
		SessionID: "019d-provider-history",
		StartedAt: now,
	}
	if err := store.SaveNodeRun(context.Background(), run); err != nil {
		t.Fatalf("save run: %v", err)
	}

	transcriptPath := filepath.Join(codexHome, "sessions", "2026", "04", "08", "rollout-2026-04-08T10-00-00-019d-provider-history.jsonl")
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript dir: %v", err)
	}
	content := "" +
		"{\"timestamp\":\"2026-04-08T10:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"019d-provider-history\",\"cwd\":\"" + task.ExecutionDir + "\"}}\n" +
		"{\"timestamp\":\"2026-04-08T10:00:01Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"call_id\":\"call-1\",\"name\":\"exec_command\",\"arguments\":\"{\\\"cmd\\\":\\\"pwd\\\"}\"}}\n" +
		"{\"timestamp\":\"2026-04-08T10:00:02Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"done\"}]}}\n" +
		"{\"timestamp\":\"2026-04-08T10:00:03Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\"}}\n"
	if err := os.WriteFile(transcriptPath, []byte(content), 0o644); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	historyResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRunHistory,
		Params: mustRawParams(t, taskRunHistoryParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   run.ID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.run_history rpc error: %+v", rpcErr)
	}
	historyResult := historyResultAny.(taskRunHistoryResult)
	if got := historyResult.Provenance; got != "provider_backfilled" {
		t.Fatalf("task.run_history provenance = %q, want provider_backfilled", got)
	}
	if got := historyResult.Completeness; got != "complete" {
		t.Fatalf("task.run_history completeness = %q, want complete", got)
	}
	if got := len(historyResult.Events); got != 2 {
		t.Fatalf("task.run_history event count = %d, want 2", got)
	}
	if got := historyResult.Events[0].Name; got != "exec_command" {
		t.Fatalf("task.run_history first tool name = %q, want exec_command", got)
	}
	if got := historyResult.Events[1].Text; got != "done" {
		t.Fatalf("task.run_history assistant text = %q, want done", got)
	}
}

func TestServerTaskRunHistoryKeepsProviderBackfillAfterLocalHistoryStarts(t *testing.T) {
	workspacePath := t.TempDir()
	codexHome := t.TempDir()
	t.Setenv("CODEX_HOME", codexHome)

	server := newTestServer(t)
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	store, err := taskstore.Open(workspacePath)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	defer func() { _ = store.Close() }()

	taskID := "task-provider-merged-history"
	materialized := materializeEmbeddedDefaultTestConfig(t, workspacePath, taskID)
	configBytes, err := os.ReadFile(materialized.ConfigPath)
	if err != nil {
		t.Fatalf("read materialized config: %v", err)
	}
	configText := strings.Replace(string(configBytes), "runtime: claude-code", "runtime: codex", 1)
	configText = strings.Replace(configText, "runtime: default", "runtime: codex", 1)
	if err := os.WriteFile(materialized.ConfigPath, []byte(configText), 0o644); err != nil {
		t.Fatalf("force codex runtime: %v", err)
	}

	now := time.Date(2026, 4, 8, 10, 0, 0, 0, time.UTC)
	task := taskdomain.Task{
		ID:           taskID,
		Description:  "provider merged history",
		ConfigAlias:  "default",
		ConfigPath:   materialized.ConfigPath,
		WorkDir:      taskstore.NormalizeWorkDir(workspacePath),
		ExecutionDir: taskstore.NormalizeWorkDir(workspacePath),
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err := store.CreateTask(context.Background(), task); err != nil {
		t.Fatalf("create task: %v", err)
	}
	run := taskdomain.NodeRun{
		ID:        "run-provider-merged-history",
		TaskID:    taskID,
		NodeName:  "draft_plan",
		Status:    taskdomain.NodeRunRunning,
		SessionID: "019d-provider-merged-history",
		StartedAt: now,
	}
	if err := store.SaveNodeRun(context.Background(), run); err != nil {
		t.Fatalf("save run: %v", err)
	}

	if err := taskhistory.Append(workspacePath, taskID, run.ID, taskexecutor.Progress{
		SessionID: run.SessionID,
		Events: []taskexecutor.StreamEvent{{
			EventID:    "evt-local-1",
			Seq:        1,
			EmittedAt:  now.Add(time.Second),
			SessionID:  run.SessionID,
			Kind:       taskexecutor.StreamEventKindTool,
			Provenance: taskexecutor.StreamEventProvenanceExecutorPersisted,
			Tool: &taskexecutor.ToolCall{
				CallID:       "call-1",
				Name:         "exec_command",
				Kind:         taskexecutor.ToolKindShell,
				Status:       taskexecutor.ToolStatusInProgress,
				InputSummary: "pwd",
			},
		}},
	}, now.Add(time.Second)); err != nil {
		t.Fatalf("append local history: %v", err)
	}

	transcriptPath := filepath.Join(codexHome, "sessions", "2026", "04", "08", "rollout-2026-04-08T10-00-00-019d-provider-merged-history.jsonl")
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript dir: %v", err)
	}
	content := "" +
		"{\"timestamp\":\"2026-04-08T10:00:00Z\",\"type\":\"session_meta\",\"payload\":{\"id\":\"019d-provider-merged-history\",\"cwd\":\"" + task.ExecutionDir + "\"}}\n" +
		"{\"timestamp\":\"2026-04-08T10:00:01Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"call_id\":\"call-1\",\"name\":\"exec_command\",\"arguments\":\"{\\\"cmd\\\":\\\"pwd\\\"}\"}}\n" +
		"{\"timestamp\":\"2026-04-08T10:00:02Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"call_id\":\"call-1\",\"output\":\"Exit code: 0\\nWall time: 0.1 seconds\\nOutput:\\n" + task.ExecutionDir + "\\n\"}}\n" +
		"{\"timestamp\":\"2026-04-08T10:00:03Z\",\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"done\"}]}}\n" +
		"{\"timestamp\":\"2026-04-08T10:00:04Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\"}}\n"
	if err := os.WriteFile(transcriptPath, []byte(content), 0o644); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	historyResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRunHistory,
		Params: mustRawParams(t, taskRunHistoryParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   run.ID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.run_history rpc error: %+v", rpcErr)
	}
	historyResult := historyResultAny.(taskRunHistoryResult)
	if got := historyResult.Provenance; got != "mixed_recovered" {
		t.Fatalf("task.run_history provenance = %q, want mixed_recovered", got)
	}
	if got := historyResult.Completeness; got != "complete" {
		t.Fatalf("task.run_history completeness = %q, want complete", got)
	}
	if got := len(historyResult.Events); got != 3 {
		t.Fatalf("task.run_history event count = %d, want 3", got)
	}
	if got := historyResult.Events[0].InputSummary; got != "pwd" {
		t.Fatalf("task.run_history local tool input = %q, want pwd", got)
	}
	if got := historyResult.Events[1].OutputText; !strings.Contains(got, task.ExecutionDir) {
		t.Fatalf("task.run_history merged tool output = %q, want %q", got, task.ExecutionDir)
	}
	if got := historyResult.Events[2].Text; got != "done" {
		t.Fatalf("task.run_history assistant text = %q, want done", got)
	}
}

func TestServerTaskRunHistoryExposesTypedMCPPayloadWithoutDuplicatingImageDebugData(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID, nodeRunID := seedAwaitingTask(t, workspacePath)
	server.markInitialized()

	recordedAt := time.Date(2026, 4, 8, 10, 0, 0, 0, time.UTC)
	tool := taskexecutor.NewMCPToolCall(taskexecutor.MCPToolCallParams{
		CallID:     "item_22",
		Server:     "pencil",
		Tool:       "export_nodes",
		Status:     taskexecutor.ToolStatusCompleted,
		DurationMS: 1440,
		Arguments: map[string]any{
			"nodeIds": []string{"canvas-root"},
		},
		Content: []any{
			map[string]any{"type": "text", "text": "Rendered a preview image."},
			map[string]any{"type": "image", "data": "AAA", "mimeType": "image/png"},
		},
	})
	if err := taskhistory.Append(workspacePath, taskID, nodeRunID, taskexecutor.Progress{
		SessionID: "session-mcp",
		Events: []taskexecutor.StreamEvent{{
			EventID:    "evt-mcp",
			Seq:        1,
			EmittedAt:  recordedAt,
			SessionID:  "session-mcp",
			Kind:       taskexecutor.StreamEventKindTool,
			Provenance: taskexecutor.StreamEventProvenanceExecutorPersisted,
			Raw:        tool.MCP.DebugJSON,
			Tool:       &tool,
		}},
	}, recordedAt); err != nil {
		t.Fatalf("append mcp history: %v", err)
	}

	summaryResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRunHistory,
		Params: mustRawParams(t, taskRunHistoryParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   nodeRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.run_history rpc error: %+v", rpcErr)
	}
	summaryResult := summaryResultAny.(taskRunHistoryResult)
	if got := len(summaryResult.Events); got != 1 {
		t.Fatalf("task.run_history event count = %d, want 1", got)
	}
	summaryEvent := summaryResult.Events[0]
	if summaryEvent.MCP != nil {
		t.Fatalf("task.run_history summary mcp payload = %#v, want nil", summaryEvent.MCP)
	}
	if summaryEvent.RawOutputJSON != "" {
		t.Fatalf("task.run_history summary raw_output_json = %q, want empty", summaryEvent.RawOutputJSON)
	}

	historyResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRunHistoryFull,
		Params: mustRawParams(t, taskRunHistoryParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   nodeRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.run_history_full rpc error: %+v", rpcErr)
	}
	historyResult := historyResultAny.(taskRunHistoryResult)
	if got := len(historyResult.Events); got != 1 {
		t.Fatalf("task.run_history_full event count = %d, want 1", got)
	}
	event := historyResult.Events[0]
	if got := event.ToolKind; got != string(taskexecutor.ToolKindMCP) {
		t.Fatalf("tool kind = %q, want mcp", got)
	}
	if got := event.DurationMS; got != 1440 {
		t.Fatalf("tool duration = %d, want 1440", got)
	}
	if event.MCP == nil {
		t.Fatal("task.run_history mcp payload = nil, want typed payload")
	}
	if got := event.MCP.Server; got != "pencil" {
		t.Fatalf("mcp server = %q, want pencil", got)
	}
	if got := len(event.MCP.OutputBlocks); got != 2 {
		t.Fatalf("mcp output block count = %d, want 2", got)
	}
	if got := event.MCP.OutputBlocks[1].DataURL; got != "data:image/png;base64,AAA" {
		t.Fatalf("mcp image data url = %q, want data url", got)
	}
	if strings.Contains(event.Raw, "data:image") {
		t.Fatalf("event raw leaked image payload: %s", event.Raw)
	}
	if strings.Contains(event.RawOutputJSON, "data:image") {
		t.Fatalf("raw_output_json leaked image payload: %s", event.RawOutputJSON)
	}
}

func TestSessionHistoryEventDTOMarshalPreservesDurationMSByKind(t *testing.T) {
	payload, err := json.Marshal([]sessionHistoryEventDTO{
		{
			Kind:       string(taskexecutor.StreamEventKindTool),
			CallID:     "item_22",
			ToolKind:   string(taskexecutor.ToolKindMCP),
			Status:     string(taskexecutor.ToolStatusCompleted),
			DurationMS: 1440,
		},
		{
			Kind:              string(taskexecutor.StreamEventKindUsage),
			InputTokens:       128,
			CachedInputTokens: 32,
			OutputTokens:      64,
			TotalTokens:       192,
			DurationMS:        920,
		},
	})
	if err != nil {
		t.Fatalf("marshal session history events: %v", err)
	}

	var decoded []map[string]any
	if err := json.Unmarshal(payload, &decoded); err != nil {
		t.Fatalf("unmarshal session history events: %v", err)
	}
	if got := decoded[0]["duration_ms"]; got != float64(1440) {
		t.Fatalf("tool duration_ms = %#v, want 1440", got)
	}
	if got := decoded[1]["duration_ms"]; got != float64(920) {
		t.Fatalf("usage duration_ms = %#v, want 920", got)
	}
}

func TestServerTaskRunHistoryIgnoresPartialTrailingChunk(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID, nodeRunID := seedAwaitingTask(t, workspacePath)
	server.markInitialized()

	recordedAt := time.Date(2026, 4, 8, 10, 0, 0, 0, time.UTC)
	if err := taskhistory.Append(workspacePath, taskID, nodeRunID, taskexecutor.Progress{
		SessionID: "session-123",
		Events: []taskexecutor.StreamEvent{
			{
				EventID:    "evt-first",
				Seq:        1,
				EmittedAt:  recordedAt,
				SessionID:  "session-123",
				Kind:       taskexecutor.StreamEventKindMessage,
				Provenance: taskexecutor.StreamEventProvenanceExecutorPersisted,
				Message: &taskexecutor.MessagePart{
					MessageID: "msg-first",
					PartID:    "part-first",
					Role:      taskexecutor.MessageRoleAssistant,
					Type:      taskexecutor.MessagePartTypeText,
					Text:      "first chunk",
				},
			},
		},
	}, recordedAt); err != nil {
		t.Fatalf("append first event: %v", err)
	}
	path := taskstore.RunHistoryPath(workspacePath, taskID, nodeRunID)
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		t.Fatalf("open history file: %v", err)
	}
	if _, err := file.WriteString(`{"event_id":"evt-partial","seq":2,"kind":"message","message":{"text":"partial"}`); err != nil {
		_ = file.Close()
		t.Fatalf("append partial trailing record: %v", err)
	}
	if err := file.Close(); err != nil {
		t.Fatalf("close history file: %v", err)
	}

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRunHistory,
		Params: mustRawParams(t, taskRunHistoryParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   nodeRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.run_history rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskRunHistoryResult)
	if got := len(result.Events); got != 1 {
		t.Fatalf("history event count = %d, want 1", got)
	}
	if got := result.Events[0].Text; got != "first chunk" {
		t.Fatalf("first history message = %q, want first chunk", got)
	}
}

func TestServerTaskRunHistoryReadsPersistedHistoryWithoutConfig(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID, nodeRunID := seedAwaitingTask(t, workspacePath)
	server.markInitialized()

	recordedAt := time.Date(2026, 4, 8, 10, 0, 0, 0, time.UTC)
	if err := taskhistory.Append(workspacePath, taskID, nodeRunID, taskexecutor.Progress{
		SessionID: "session-123",
		Events: []taskexecutor.StreamEvent{{
			EventID:    "evt-first",
			Seq:        1,
			EmittedAt:  recordedAt,
			SessionID:  "session-123",
			Kind:       taskexecutor.StreamEventKindMessage,
			Provenance: taskexecutor.StreamEventProvenanceExecutorPersisted,
			Message: &taskexecutor.MessagePart{
				MessageID: "msg-first",
				PartID:    "part-first",
				Role:      taskexecutor.MessageRoleAssistant,
				Type:      taskexecutor.MessagePartTypeText,
				Text:      "persisted survives",
			},
		}},
	}, recordedAt); err != nil {
		t.Fatalf("append history: %v", err)
	}
	if err := os.Remove(taskstore.ConfigPath(workspacePath, taskID)); err != nil {
		t.Fatalf("remove config: %v", err)
	}

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRunHistory,
		Params: mustRawParams(t, taskRunHistoryParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   nodeRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.run_history rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskRunHistoryResult)
	if got := result.Provenance; got != "executor_persisted" {
		t.Fatalf("history provenance = %q, want executor_persisted", got)
	}
	if got := len(result.Events); got != 1 {
		t.Fatalf("history event count = %d, want 1", got)
	}
	if got := result.Events[0].Text; got != "persisted survives" {
		t.Fatalf("history message = %q, want persisted survives", got)
	}
}

func TestServerTaskGetClearsLiveOutputAfterTerminalEvent(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID, nodeRunID := seedAwaitingTask(t, workspacePath)
	server.markInitialized()

	server.handleRuntimeEvent(workspace.WorkspaceID, taskruntime.RunEvent{
		Type:      taskruntime.EventNodeStarted,
		TaskID:    taskID,
		NodeRunID: nodeRunID,
		NodeName:  "approve_plan",
	})
	server.handleRuntimeEvent(workspace.WorkspaceID, taskruntime.RunEvent{
		Type:      taskruntime.EventNodeProgress,
		TaskID:    taskID,
		NodeRunID: nodeRunID,
		NodeName:  "approve_plan",
		Progress: &taskruntime.ProgressInfo{
			Events: []taskexecutor.StreamEvent{{
				Kind: taskexecutor.StreamEventKindTool,
				Tool: &taskexecutor.ToolCall{
					Name:         "Read",
					Kind:         taskexecutor.ToolKindRead,
					Status:       taskexecutor.ToolStatusCompleted,
					InputSummary: "plan.md",
				},
			}},
		},
	})

	getResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{WorkspaceID: workspace.WorkspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get before terminal rpc error: %+v", rpcErr)
	}
	getResult := getResultAny.(taskGetResult)
	if len(getResult.LiveEvents) == 0 {
		t.Fatal("task.get live_events = empty before terminal event, want events")
	}

	server.handleRuntimeEvent(workspace.WorkspaceID, taskruntime.RunEvent{
		Type:      taskruntime.EventNodeCompleted,
		TaskID:    taskID,
		NodeRunID: nodeRunID,
		NodeName:  "approve_plan",
	})

	getResultAny, _, _, rpcErr = server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{WorkspaceID: workspace.WorkspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get after terminal rpc error: %+v", rpcErr)
	}
	getResult = getResultAny.(taskGetResult)
	if got := len(getResult.LiveEvents); got != 0 {
		t.Fatalf("task.get live_events length after terminal = %d, want 0", got)
	}
	if getResult.LiveOutputRunID != "" {
		t.Fatalf("task.get live_output_run_id after terminal = %q, want empty", getResult.LiveOutputRunID)
	}
}

func TestServerTaskMutationsRouteByWorkspaceAndCorrelateNotifications(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	fakeService := newFakeRuntimeService()
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		runtimeFactory: func(workDir string) (runtimeService, error) {
			if workDir != taskstore.NormalizeWorkDir(workspacePath) {
				t.Fatalf("runtime factory workDir = %q, want %q", workDir, taskstore.NormalizeWorkDir(workspacePath))
			}
			return fakeService, nil
		},
	})
	defer func() { _ = server.runtimes.closeAll() }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	var notifications []notification
	server.setNotificationSink(func(n notification) {
		notifications = append(notifications, n)
	})
	defer server.setNotificationSink(nil)

	startResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskStart,
		Params: mustRawParams(t, taskStartParams{
			WorkspaceID:     workspace.WorkspaceID,
			ClientCommandID: "cmd-1",
			Description:     "Ship it",
			ConfigAlias:     "default",
			ConfigPath:      "/tmp/default/config.yaml",
			UseWorktree:     true,
			ImageAttachments: []taskruntime.ImageAttachmentInput{{
				Name:       "start.png",
				MIMEType:   "image/png",
				SizeBytes:  4,
				DataBase64: "AAAAAA==",
			}},
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.start rpc error: %+v", rpcErr)
	}
	startResult := startResultAny.(commandAcceptedResult)
	if !startResult.Accepted || startResult.ClientCommandID != "cmd-1" {
		t.Fatalf("task.start accepted result = %#v", startResult)
	}

	dispatches := fakeService.Dispatched()
	if len(dispatches) != 1 {
		t.Fatalf("dispatch count = %d, want 1", len(dispatches))
	}
	if got := dispatches[0].WorkDir; got != taskstore.NormalizeWorkDir(workspacePath) {
		t.Fatalf("dispatch work_dir = %q, want %q", got, taskstore.NormalizeWorkDir(workspacePath))
	}
	if got := dispatches[0].ImageAttachments; len(got) != 1 || got[0].Name != "start.png" {
		t.Fatalf("dispatch image attachments = %#v, want start.png", got)
	}

	server.handleRuntimeEvent(workspace.WorkspaceID, taskruntime.RunEvent{
		Type:   taskruntime.EventTaskCreated,
		TaskID: "task-123",
	})
	if len(notifications) != 1 {
		t.Fatalf("notification count = %d, want 1", len(notifications))
	}
	params := notifications[0].Params.(notificationParams)
	if params.Kind != string(taskruntime.EventTaskCreated) {
		t.Fatalf("notification kind = %q, want %q", params.Kind, taskruntime.EventTaskCreated)
	}
	if params.WorkspaceID != workspace.WorkspaceID {
		t.Fatalf("notification workspace_id = %q, want %q", params.WorkspaceID, workspace.WorkspaceID)
	}
	payload := params.Payload.(taskNotificationPayload)
	if payload.ClientCommandID != "cmd-1" {
		t.Fatalf("notification client_command_id = %q, want cmd-1", payload.ClientCommandID)
	}

	submitResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskSubmitInput,
		Params: mustRawParams(t, taskSubmitInputParams{
			WorkspaceID:     workspace.WorkspaceID,
			ClientCommandID: "cmd-2",
			TaskID:          "task-123",
			NodeRunID:       "run-1",
			Payload:         map[string]interface{}{"approved": true},
			ImageAttachments: []taskruntime.ImageAttachmentInput{{
				Name:       "approval.png",
				MIMEType:   "image/png",
				SizeBytes:  4,
				DataBase64: "AAAAAA==",
			}},
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.submit_input rpc error: %+v", rpcErr)
	}
	submitResult := submitResultAny.(commandAcceptedResult)
	if !submitResult.Accepted {
		t.Fatalf("task.submit_input accepted = false")
	}
	dispatches = fakeService.Dispatched()
	if got := len(dispatches); got != 2 {
		t.Fatalf("dispatch count after submit = %d, want 2", got)
	}
	if dispatches[1].Type != taskruntime.CommandSubmitInput {
		t.Fatalf("second dispatch type = %q, want %q", dispatches[1].Type, taskruntime.CommandSubmitInput)
	}
	if got := dispatches[1].ImageAttachments; len(got) != 1 || got[0].Name != "approval.png" {
		t.Fatalf("submit image attachments = %#v, want approval.png", got)
	}
}

func TestServerTaskStartFollowUpForwardsExplicitMode(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	fakeService := newFakeRuntimeService()
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		runtimeFactory: func(workDir string) (runtimeService, error) {
			return fakeService, nil
		},
	})
	defer func() { _ = server.runtimes.closeAll() }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskStartFollowUp,
		Params: mustRawParams(t, taskStartFollowUpParams{
			WorkspaceID:     workspace.WorkspaceID,
			ClientCommandID: "cmd-follow-up",
			ParentTaskID:    "task-parent",
			Description:     "Continue from the worktree",
			ConfigAlias:     "default",
			ConfigPath:      "/tmp/default/config.yaml",
			FollowUpMode:    taskruntime.FollowUpModeForkWithChanges,
			ImageAttachments: []taskruntime.ImageAttachmentInput{{
				Name:       "follow-up.webp",
				MIMEType:   "image/webp",
				SizeBytes:  4,
				DataBase64: "AAAAAA==",
			}},
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.start_follow_up rpc error: %+v", rpcErr)
	}
	result := resultAny.(commandAcceptedResult)
	if !result.Accepted || result.ClientCommandID != "cmd-follow-up" {
		t.Fatalf("task.start_follow_up accepted result = %#v", result)
	}

	dispatches := fakeService.Dispatched()
	if len(dispatches) != 1 {
		t.Fatalf("dispatch count = %d, want 1", len(dispatches))
	}
	if got := dispatches[0].Type; got != taskruntime.CommandStartFollowUp {
		t.Fatalf("dispatch type = %q, want %q", got, taskruntime.CommandStartFollowUp)
	}
	if got := dispatches[0].FollowUpMode; got != taskruntime.FollowUpModeForkWithChanges {
		t.Fatalf("dispatch follow_up_mode = %q, want %q", got, taskruntime.FollowUpModeForkWithChanges)
	}
	if got := dispatches[0].ImageAttachments; len(got) != 1 || got[0].Name != "follow-up.webp" {
		t.Fatalf("dispatch image attachments = %#v, want follow-up.webp", got)
	}
}

func TestServerTaskStartSmokeRunsOptInCodexAppServer(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	fakeDir := t.TempDir()
	writeSmokeCodexAppServerBinary(t, filepath.Join(fakeDir, "codex"))
	basePath := os.Getenv("PATH")
	t.Setenv("PATH", fakeDir+string(os.PathListSeparator)+basePath)
	t.Setenv(codex.EnvExecutorMode, codex.ModeAppServer)

	notifications := make(chan notification, 64)
	server.setNotificationSink(func(n notification) {
		notifications <- n
	})
	defer server.setNotificationSink(nil)

	startResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskStart,
		Params: mustRawParams(t, taskStartParams{
			WorkspaceID: workspace.WorkspaceID,
			Description: "Smoke codex app-server",
			ConfigAlias: taskconfig.BuiltinIDSingleRun,
			ConfigPath:  singleRunConfigPathForAppServerTest(t),
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.start rpc error: %+v", rpcErr)
	}
	startResult := startResultAny.(commandAcceptedResult)
	if !startResult.Accepted {
		t.Fatal("task.start accepted = false")
	}

	created := waitForNotificationWhere(t, notifications, 5*time.Second, func(params notificationParams) bool {
		return params.Kind == string(taskruntime.EventTaskCreated)
	})
	createdPayload := created.Payload.(taskNotificationPayload)
	taskID := createdPayload.Event.TaskID
	if taskID == "" {
		t.Fatal("task.created task_id = empty, want value")
	}

	completed := waitForNotificationWhere(t, notifications, 5*time.Second, func(params notificationParams) bool {
		if params.Kind != string(taskruntime.EventTaskCompleted) && params.Kind != string(taskruntime.EventTaskFailed) {
			return false
		}
		payload, ok := params.Payload.(taskNotificationPayload)
		return ok && payload.Event.TaskID == taskID
	})
	if completed.Kind != string(taskruntime.EventTaskCompleted) {
		payload := completed.Payload.(taskNotificationPayload)
		message := ""
		if payload.Event.Error != nil {
			message = payload.Event.Error.Message
		}
		t.Fatalf("task completed notification kind = %q, want %q (%s)", completed.Kind, taskruntime.EventTaskCompleted, message)
	}

	getResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get rpc error: %+v", rpcErr)
	}
	getResult := getResultAny.(taskGetResult)
	if got := getResult.Task.Status; got != string(taskdomain.TaskStatusDone) {
		t.Fatalf("task.get status = %q, want %q", got, taskdomain.TaskStatusDone)
	}

	nodeRunID := ""
	for _, run := range getResult.Task.NodeRuns {
		if run.NodeName == "handle_request" {
			nodeRunID = run.ID
			break
		}
	}
	if nodeRunID == "" {
		t.Fatalf("handle_request node run missing in task.get: %#v", getResult.Task.NodeRuns)
	}

	historyResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRunHistory,
		Params: mustRawParams(t, taskRunHistoryParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   nodeRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.run_history rpc error: %+v", rpcErr)
	}
	historyResult := historyResultAny.(taskRunHistoryResult)
	if got := historyResult.SessionID; got != "thread-smoke" {
		t.Fatalf("task.run_history session_id = %q, want thread-smoke", got)
	}
	if got := historyResult.Provenance; got != "executor_persisted" {
		t.Fatalf("task.run_history provenance = %q, want executor_persisted", got)
	}
	if got := historyResult.Completeness; got != "complete" {
		t.Fatalf("task.run_history completeness = %q, want complete", got)
	}
	if got := len(historyResult.Events); got < 6 {
		t.Fatalf("task.run_history event count = %d, want >= 6", got)
	}

	var (
		sawCommentary bool
		sawReasoning  bool
		sawMCP        bool
		sawUsage      bool
	)
	for _, event := range historyResult.Events {
		switch {
		case event.Kind == "message" && event.MessageID == "msg-commentary" && event.PartID == "phase:commentary" && event.Text == "Inspect repo":
			sawCommentary = true
		case event.Kind == "message" && event.MessageID == "reason-1" && event.PartID == "summary" && event.PartType == "reasoning" && event.Text == "Check state":
			sawReasoning = true
		case event.Kind == "tool" && event.CallID == "mcp-1" && event.ToolKind == "mcp" && event.Status == "completed" && event.OutputText == "Loaded schema.":
			sawMCP = true
		case event.Kind == "usage" && event.InputTokens == 7 && event.OutputTokens == 5:
			sawUsage = true
		}
		if strings.Contains(event.Text, `"file_paths"`) {
			t.Fatalf("task.run_history leaked structured output envelope into message text: %q", event.Text)
		}
	}
	if !sawCommentary {
		t.Fatalf("task.run_history missing commentary snapshot: %#v", historyResult.Events)
	}
	if !sawReasoning {
		t.Fatalf("task.run_history missing reasoning snapshot: %#v", historyResult.Events)
	}
	if !sawMCP {
		t.Fatalf("task.run_history missing mcp event: %#v", historyResult.Events)
	}
	if !sawUsage {
		t.Fatalf("task.run_history missing usage event: %#v", historyResult.Events)
	}
}

func TestServerTaskRecoverStaleMarksOrphanedRunFailed(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID, nodeRunID := seedRecoverableTerminalRun(t, workspacePath, nil)
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRecoverStale,
		Params: mustRawParams(t, taskRecoverStaleParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   nodeRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.recover_stale rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskRecoverStaleResult)
	if result.Outcome != "recovered_failed" {
		t.Fatalf("task.recover_stale outcome = %q, want recovered_failed", result.Outcome)
	}

	model, rpcErr := server.openWorkspaceReadModel(workspace)
	if rpcErr != nil {
		t.Fatalf("open read model: %+v", rpcErr)
	}
	defer func() { _ = model.Close() }()
	run, err := model.store.GetNodeRun(context.Background(), nodeRunID)
	if err != nil {
		t.Fatalf("get recovered node run: %v", err)
	}
	if got := string(run.Status); got != string(taskdomain.NodeRunFailed) {
		t.Fatalf("recovered run status = %q, want %q", got, taskdomain.NodeRunFailed)
	}
	if got := run.FailureReason; got != taskdomain.FailureReasonOrphanedAfterRestart {
		t.Fatalf("recovered run failure_reason = %q, want %q", got, taskdomain.FailureReasonOrphanedAfterRestart)
	}
}

func TestServerWorkspaceReconcileStaleMarksOrphanedRunFailed(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	_, nodeRunID := seedRecoverableTerminalRun(t, workspacePath, nil)
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceReconcile,
		Params: mustRawParams(t, workspaceReconcileParams{
			WorkspaceID: workspace.WorkspaceID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("workspace.reconcile_stale rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceReconcileResult)
	if result.Outcome != workspaceReconcileOutcomeReconciled {
		t.Fatalf("workspace.reconcile_stale outcome = %q, want %q", result.Outcome, workspaceReconcileOutcomeReconciled)
	}
	if got := server.runtimes.snapshot(workspace.WorkspaceID).State; got != "cold" {
		t.Fatalf("workspace actor state = %q, want cold", got)
	}

	model, rpcErr := server.openWorkspaceReadModel(workspace)
	if rpcErr != nil {
		t.Fatalf("open read model: %+v", rpcErr)
	}
	defer func() { _ = model.Close() }()
	run, err := model.store.GetNodeRun(context.Background(), nodeRunID)
	if err != nil {
		t.Fatalf("get recovered node run: %v", err)
	}
	if got := string(run.Status); got != string(taskdomain.NodeRunFailed) {
		t.Fatalf("recovered run status = %q, want %q", got, taskdomain.NodeRunFailed)
	}
	if got := run.FailureReason; got != taskdomain.FailureReasonOrphanedAfterRestart {
		t.Fatalf("recovered run failure_reason = %q, want %q", got, taskdomain.FailureReasonOrphanedAfterRestart)
	}
}

func TestServerWorkspaceReconcileStaleReturnsNoopWithoutRunningRuns(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceReconcile,
		Params: mustRawParams(t, workspaceReconcileParams{
			WorkspaceID: workspace.WorkspaceID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("workspace.reconcile_stale rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceReconcileResult)
	if result.Outcome != workspaceReconcileOutcomeNoop {
		t.Fatalf("workspace.reconcile_stale outcome = %q, want %q", result.Outcome, workspaceReconcileOutcomeNoop)
	}
}

func TestServerWorkspaceReconcileStaleReturnsBusyWhenActorIsActive(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	fakeService := newFakeRuntimeService()
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		runtimeFactory: func(string) (runtimeService, error) {
			return fakeService, nil
		},
	})
	defer func() { _ = server.runtimes.closeAll() }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	seedRecoverableTerminalRun(t, workspacePath, nil)
	server.markInitialized()

	if _, err := server.runtimes.ensure(workspace); err != nil {
		t.Fatalf("ensure runtime actor: %v", err)
	}

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodWorkspaceReconcile,
		Params: mustRawParams(t, workspaceReconcileParams{
			WorkspaceID: workspace.WorkspaceID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("workspace.reconcile_stale rpc error: %+v", rpcErr)
	}
	result := resultAny.(workspaceReconcileResult)
	if result.Outcome != workspaceReconcileOutcomeBusy {
		t.Fatalf("workspace.reconcile_stale outcome = %q, want %q", result.Outcome, workspaceReconcileOutcomeBusy)
	}
}

func TestServerTaskRecoverStaleRecoversCompletedRun(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	server := newTestServerAtPath(t, stateDir)
	defer func() { _ = server.Shutdown(context.Background(), false) }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID, nodeRunID := seedRecoverableTerminalRun(
		t,
		workspacePath,
		[]byte("{\"kind\":\"result\",\"result\":{\"summary\":\"Recovered summary\",\"file_paths\":[\"summary.md\"]}}\n"),
	)
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRecoverStale,
		Params: mustRawParams(t, taskRecoverStaleParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   nodeRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.recover_stale rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskRecoverStaleResult)
	if result.Outcome != "recovered_done" {
		t.Fatalf("task.recover_stale outcome = %q, want recovered_done", result.Outcome)
	}

	model, rpcErr := server.openWorkspaceReadModel(workspace)
	if rpcErr != nil {
		t.Fatalf("open read model: %+v", rpcErr)
	}
	defer func() { _ = model.Close() }()
	run, err := model.store.GetNodeRun(context.Background(), nodeRunID)
	if err != nil {
		t.Fatalf("get recovered node run: %v", err)
	}
	if got := string(run.Status); got != string(taskdomain.NodeRunDone) {
		t.Fatalf("recovered run status = %q, want %q", got, taskdomain.NodeRunDone)
	}
}

func TestServerTaskRecoverStaleReturnsBusyWhenActorIsActive(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	fakeService := newFakeRuntimeService()
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		runtimeFactory: func(string) (runtimeService, error) {
			return fakeService, nil
		},
	})
	defer func() { _ = server.runtimes.closeAll() }()

	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}
	taskID, nodeRunID := seedRecoverableTerminalRun(t, workspacePath, nil)
	server.markInitialized()

	if _, err := server.runtimes.ensure(workspace); err != nil {
		t.Fatalf("ensure runtime actor: %v", err)
	}

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRecoverStale,
		Params: mustRawParams(t, taskRecoverStaleParams{
			WorkspaceID: workspace.WorkspaceID,
			TaskID:      taskID,
			NodeRunID:   nodeRunID,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.recover_stale rpc error: %+v", rpcErr)
	}
	result := resultAny.(taskRecoverStaleResult)
	if result.Outcome != "busy" {
		t.Fatalf("task.recover_stale outcome = %q, want busy", result.Outcome)
	}
}

func TestServeConnEOFDoesNotCloseRuntime(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	fakeService := newFakeRuntimeService()
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		runtimeFactory: func(workDir string) (runtimeService, error) {
			return fakeService, nil
		},
	})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}

	err = server.runtimes.dispatch(workspace, taskruntime.RunCommand{Type: taskruntime.CommandStartTask})
	if err != nil {
		t.Fatalf("dispatch runtime command: %v", err)
	}

	var in bytes.Buffer
	var out bytes.Buffer
	writeRequestFrame(t, &in, 1, methodInitialize, map[string]any{"protocol_version": protocolVersion})

	if err := server.ServeConn(context.Background(), &in, &out, ConnectionOptions{}); err != nil {
		t.Fatalf("serve conn: %v", err)
	}

	if got := fakeService.CloseCalls(); got != 0 {
		t.Fatalf("close calls = %d, want 0", got)
	}
	if got := fakeService.PrepareShutdownCalls(); got != 0 {
		t.Fatalf("prepare shutdown calls = %d, want 0", got)
	}
}

func TestLateNotificationSinkAfterSessionCloseDoesNotPanic(t *testing.T) {
	server := newTestServer(t)
	sessionCtx, cancel := context.WithCancel(context.Background())
	defer cancel()
	session := &connectionSession{
		id:       "session-a",
		outgoing: make(chan any, 8),
		ctx:      sessionCtx,
		cancel:   cancel,
	}

	_, _, _, rpcErr := server.handleSessionRequest(context.Background(), session, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("initialize rpc error: %+v", rpcErr)
	}

	server.mu.Lock()
	sink := server.notificationSink
	server.mu.Unlock()
	if sink == nil {
		t.Fatal("notification sink = nil, want attached sink")
	}

	server.detachClientSession(session.id)
	session.closeOutgoing()

	sink(notification{
		JSONRPC: jsonRPCVersion,
		Method:  methodNotification,
		Params:  notificationParams{Kind: string(taskruntime.EventNodeStarted)},
	})
}

func TestInitializeRejectsSecondInteractiveClientButAllowsPassiveProbe(t *testing.T) {
	server := newTestServer(t)
	sessionA := &connectionSession{id: "session-a", outgoing: make(chan any, 8)}
	sessionB := &connectionSession{id: "session-b", outgoing: make(chan any, 8)}
	probe := &connectionSession{id: "probe", outgoing: make(chan any, 8)}

	_, _, _, rpcErr := server.handleSessionRequest(context.Background(), sessionA, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("first initialize rpc error: %+v", rpcErr)
	}
	defer server.detachClientSession(sessionA.id)

	_, _, _, rpcErr = server.handleSessionRequest(context.Background(), sessionB, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr == nil || rpcErr.Code != errorCodeBusy {
		t.Fatalf("second initialize rpc error = %+v, want busy", rpcErr)
	}

	_, _, _, rpcErr = server.handleSessionRequest(context.Background(), probe, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion, Passive: true}),
	})
	if rpcErr != nil {
		t.Fatalf("passive initialize rpc error: %+v", rpcErr)
	}
	if probe.attached {
		t.Fatal("passive probe attached interactive session")
	}
}

func TestReconnectReplaysBackloggedNotificationWithClientCommandID(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "appserver")
	workspacePath := t.TempDir()
	fakeService := newFakeRuntimeService()
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		runtimeFactory: func(workDir string) (runtimeService, error) {
			return fakeService, nil
		},
	})
	workspace, _, err := server.registry.Add(workspacePath, "cmdr")
	if err != nil {
		t.Fatalf("add workspace: %v", err)
	}

	sessionA := &connectionSession{id: "session-a", outgoing: make(chan any, 8)}
	_, _, _, rpcErr := server.handleSessionRequest(context.Background(), sessionA, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("initialize sessionA rpc error: %+v", rpcErr)
	}

	retryResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskRetryNode,
		Params: mustRawParams(t, taskRetryNodeParams{
			WorkspaceID:     workspace.WorkspaceID,
			ClientCommandID: "cmd-retry",
			TaskID:          "task-123",
			NodeRunID:       "run-old",
		}),
	})
	if rpcErr != nil {
		t.Fatalf("task.retry_node rpc error: %+v", rpcErr)
	}
	retryResult := retryResultAny.(commandAcceptedResult)
	if !retryResult.Accepted {
		t.Fatal("task.retry_node accepted = false")
	}

	server.detachClientSession(sessionA.id)
	sessionA.closeOutgoing()

	server.handleRuntimeEvent(workspace.WorkspaceID, taskruntime.RunEvent{
		Type:      taskruntime.EventNodeStarted,
		TaskID:    "task-123",
		NodeRunID: "run-new",
		NodeName:  "upsert_plan",
	})

	sessionB := &connectionSession{id: "session-b", outgoing: make(chan any, 8)}
	_, notifications, _, rpcErr := server.handleSessionRequest(context.Background(), sessionB, request{
		Method: methodInitialize,
		Params: mustRawParams(t, initializeParams{ProtocolVersion: protocolVersion}),
	})
	if rpcErr != nil {
		t.Fatalf("initialize sessionB rpc error: %+v", rpcErr)
	}
	if len(notifications) != 1 {
		t.Fatalf("backlog notification count = %d, want 1", len(notifications))
	}
	payload := notifications[0].Params.(notificationParams).Payload.(taskNotificationPayload)
	if payload.ClientCommandID != "cmd-retry" {
		t.Fatalf("backlog client_command_id = %q, want cmd-retry", payload.ClientCommandID)
	}
}

func TestServiceShutdownReturnsAckAndRequestsGracefulShutdown(t *testing.T) {
	server := newTestServer(t)

	var in bytes.Buffer
	out := &shutdownAwareBuffer{t: t, server: server}
	writeRequestFrame(t, &in, 1, methodInitialize, map[string]any{"protocol_version": protocolVersion})
	writeRequestFrame(t, &in, 2, methodServiceShutdown, map[string]any{})

	if err := server.ServeConn(context.Background(), &in, out, ConnectionOptions{}); err != nil {
		t.Fatalf("serve conn: %v", err)
	}
	if !server.GracefulShutdownRequested() {
		t.Fatal("graceful shutdown = false, want true")
	}

	messages := readFramesAsMaps(t, out.Bytes())
	shutdownResponse := responseByID(t, messages, 2)
	if accepted, _ := nestedBool(shutdownResponse, "result", "accepted"); !accepted {
		t.Fatalf("service.shutdown accepted = %#v, want true", shutdownResponse)
	}
}

func TestServerConfigRuntimeFlows(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	stateDir := filepath.Join(t.TempDir(), "appserver")
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		loadConfig: func() (appconfig.Config, error) {
			return appconfig.Config{
				Runtimes: map[appconfig.RuntimeID]appconfig.RuntimeSettings{
					appconfig.RuntimeCodex: {},
				},
			}, nil
		},
	})
	server.markInitialized()

	catalogResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigCatalog,
		Params: mustRawParams(t, map[string]any{}),
	})
	if rpcErr != nil {
		t.Fatalf("config.catalog rpc error: %+v", rpcErr)
	}
	catalogResult := catalogResultAny.(configCatalogResult)
	if len(catalogResult.Entries) == 0 {
		t.Fatal("config.catalog entries = 0, want builtins")
	}
	defaultAlias := catalogResult.DefaultAlias

	getResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigGet,
		Params: mustRawParams(t, configGetParams{Alias: defaultAlias}),
	})
	if rpcErr != nil {
		t.Fatalf("config.get rpc error: %+v", rpcErr)
	}
	getResult := getResultAny.(configGetResult)
	if !getResult.Entry.Builtin {
		t.Fatal("config.get builtin = false, want true")
	}
	if getResult.Entry.Revision == "" {
		t.Fatal("config.get revision = empty, want value")
	}
	if getResult.Entry.Config == nil {
		t.Fatal("config.get config = nil, want value")
	}

	cloneResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigClone,
		Params: mustRawParams(t, configCloneParams{
			SourceAlias: defaultAlias,
			NewAlias:    "custom-plan",
		}),
	})
	if rpcErr != nil {
		t.Fatalf("config.clone rpc error: %+v", rpcErr)
	}
	cloneResult := cloneResultAny.(configCloneResult)
	if cloneResult.Entry.Builtin {
		t.Fatal("cloned config builtin = true, want false")
	}
	if cloneResult.Entry.Config == nil {
		t.Fatal("cloned config payload = nil")
	}
	initialRevision := cloneResult.Entry.Revision

	validDraft := *cloneResult.Entry.Config
	validDraft.Description = "Custom plan"
	validateResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigValidate,
		Params: mustRawParams(t, configValidateParams{Config: &validDraft}),
	})
	if rpcErr != nil {
		t.Fatalf("config.validate rpc error: %+v", rpcErr)
	}
	validateResult := validateResultAny.(configValidateResult)
	if !validateResult.Valid {
		t.Fatalf("config.validate valid = false, want true (error=%q)", validateResult.Error)
	}
	if validateResult.RuntimeID != appconfig.RuntimeCodex {
		t.Fatalf("validated runtime = %q, want %q", validateResult.RuntimeID, appconfig.RuntimeCodex)
	}
	if !validateResult.RuntimeConfigured {
		t.Fatal("validated runtime_configured = false, want true")
	}

	invalidDraft := validDraft
	invalidDraft.Runtime = appconfig.RuntimeClaudeCode
	invalidResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigValidate,
		Params: mustRawParams(t, configValidateParams{Config: &invalidDraft}),
	})
	if rpcErr != nil {
		t.Fatalf("invalid config.validate rpc error: %+v", rpcErr)
	}
	invalidResult := invalidResultAny.(configValidateResult)
	if invalidResult.Valid {
		t.Fatal("invalid config.validate valid = true, want false")
	}
	if !strings.Contains(invalidResult.Error, `runtime "claude-code" is not configured`) {
		t.Fatalf("invalid config.validate error = %q, want runtime-not-configured", invalidResult.Error)
	}

	saveResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigSave,
		Params: mustRawParams(t, configSaveParams{
			Alias:            cloneResult.Entry.Alias,
			ExpectedRevision: initialRevision,
			Config:           &validDraft,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("config.save rpc error: %+v", rpcErr)
	}
	saveResult := saveResultAny.(configSaveResult)
	if saveResult.Entry.Description != "Custom plan" {
		t.Fatalf("saved description = %q, want %q", saveResult.Entry.Description, "Custom plan")
	}
	if saveResult.Entry.Revision == "" || saveResult.Entry.Revision == initialRevision {
		t.Fatalf("saved revision = %q, want new revision after save", saveResult.Entry.Revision)
	}

	_, _, _, rpcErr = server.handleRequest(context.Background(), request{
		Method: methodConfigSave,
		Params: mustRawParams(t, configSaveParams{
			Alias:            cloneResult.Entry.Alias,
			ExpectedRevision: initialRevision,
			Config:           &validDraft,
		}),
	})
	if rpcErr == nil || rpcErr.Code != errorCodeConfigConflict {
		t.Fatalf("stale config.save rpc error = %+v, want config conflict", rpcErr)
	}

	builtinDraft := *getResult.Entry.Config
	builtinDraft.Description = "Builtin default edited"
	builtinSaveAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigSave,
		Params: mustRawParams(t, configSaveParams{
			Alias:            defaultAlias,
			ExpectedRevision: getResult.Entry.Revision,
			Config:           &builtinDraft,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("builtin config.save rpc error: %+v", rpcErr)
	}
	builtinSave := builtinSaveAny.(configSaveResult)
	if builtinSave.Entry.Description != "Builtin default edited" {
		t.Fatalf("builtin config.save description = %q, want updated value", builtinSave.Entry.Description)
	}

	resetAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigReset,
		Params: mustRawParams(t, configResetParams{Alias: defaultAlias}),
	})
	if rpcErr != nil {
		t.Fatalf("config.reset rpc error: %+v", rpcErr)
	}
	resetResult := resetAny.(configResetResult)
	if resetResult.Entry.Description != getResult.Entry.Description {
		t.Fatalf("config.reset description = %q, want %q", resetResult.Entry.Description, getResult.Entry.Description)
	}

	renameResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigRename,
		Params: mustRawParams(t, configRenameParams{
			Alias:    cloneResult.Entry.Alias,
			NewAlias: "custom-plan-2",
		}),
	})
	if rpcErr != nil {
		t.Fatalf("config.rename rpc error: %+v", rpcErr)
	}
	renameResult := renameResultAny.(configRenameResult)
	if renameResult.Entry.Alias != "custom-plan-2" {
		t.Fatalf("renamed alias = %q, want %q", renameResult.Entry.Alias, "custom-plan-2")
	}

	setDefaultResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigSetDefault,
		Params: mustRawParams(t, configSetDefaultParams{Alias: renameResult.Entry.Alias}),
	})
	if rpcErr != nil {
		t.Fatalf("config.set_default rpc error: %+v", rpcErr)
	}
	setDefaultResult := setDefaultResultAny.(configSetDefaultResult)
	if !setDefaultResult.Entry.IsDefault {
		t.Fatal("config.set_default is_default = false, want true")
	}

	runtimeListAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodRuntimeList,
		Params: mustRawParams(t, map[string]any{}),
	})
	if rpcErr != nil {
		t.Fatalf("runtime.list rpc error: %+v", rpcErr)
	}
	runtimeList := runtimeListAny.(runtimeListResult)
	if got := len(runtimeList.Runtimes); got != 1 {
		t.Fatalf("runtime.list count = %d, want 1", got)
	}
	if runtimeList.Runtimes[0].RuntimeID != appconfig.RuntimeCodex {
		t.Fatalf("runtime.list[0] = %q, want %q", runtimeList.Runtimes[0].RuntimeID, appconfig.RuntimeCodex)
	}

	deleteResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigDelete,
		Params: mustRawParams(t, configDeleteParams{Alias: renameResult.Entry.Alias}),
	})
	if rpcErr != nil {
		t.Fatalf("config.delete rpc error: %+v", rpcErr)
	}
	deleteResult := deleteResultAny.(configDeleteResult)
	if !deleteResult.Removed {
		t.Fatal("config.delete removed = false, want true")
	}

	catalogAfterDeleteAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigCatalog,
		Params: mustRawParams(t, map[string]any{}),
	})
	if rpcErr != nil {
		t.Fatalf("config.catalog after delete rpc error: %+v", rpcErr)
	}
	catalogAfterDelete := catalogAfterDeleteAny.(configCatalogResult)
	if catalogAfterDelete.DefaultAlias != taskconfig.DefaultAlias {
		t.Fatalf("default alias after delete = %q, want %q", catalogAfterDelete.DefaultAlias, taskconfig.DefaultAlias)
	}
}

func TestServerConfigSetBuiltinRuntimes(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	stateDir := filepath.Join(t.TempDir(), "appserver")
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		loadConfig: func() (appconfig.Config, error) {
			return appconfig.Config{
				Runtimes: map[appconfig.RuntimeID]appconfig.RuntimeSettings{
					appconfig.RuntimeCodex:      {},
					appconfig.RuntimeClaudeCode: {},
				},
			}, nil
		},
	})
	server.markInitialized()

	resultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigSetBuiltinRuntimes,
		Params: mustRawParams(t, configSetBuiltinRuntimesParams{RuntimeID: appconfig.RuntimeClaudeCode}),
	})
	if rpcErr != nil {
		t.Fatalf("config.set_builtin_runtimes rpc error: %+v", rpcErr)
	}
	result := resultAny.(configCatalogResult)
	if len(result.Entries) == 0 {
		t.Fatal("config.set_builtin_runtimes entries = 0")
	}
	for _, entry := range result.Entries {
		if !entry.Builtin {
			continue
		}
		if entry.RuntimeID != appconfig.RuntimeClaudeCode {
			t.Fatalf("builtin %q runtime = %q, want %q", entry.Alias, entry.RuntimeID, appconfig.RuntimeClaudeCode)
		}
		if !entry.RuntimeExplicit {
			t.Fatalf("builtin %q runtime_explicit = false, want true", entry.Alias)
		}
	}

	if _, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigSetBuiltinRuntimes,
		Params: mustRawParams(t, configSetBuiltinRuntimesParams{RuntimeID: appconfig.RuntimeID("ghost")}),
	}); rpcErr == nil || rpcErr.Code != errorCodeInvalidParams {
		t.Fatalf("config.set_builtin_runtimes invalid runtime rpc error = %+v, want invalid params", rpcErr)
	}

	if _, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigSetBuiltinRuntimes,
		Params: mustRawParams(t, configSetBuiltinRuntimesParams{RuntimeID: ""}),
	}); rpcErr == nil || rpcErr.Code != errorCodeInvalidParams {
		t.Fatalf("config.set_builtin_runtimes empty runtime rpc error = %+v, want invalid params", rpcErr)
	}
}

func TestServerConfigPromptFlows(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	stateDir := filepath.Join(t.TempDir(), "appserver")
	server := newTestServerWithOptions(t, stateDir, testServerOptions{
		loadConfig: func() (appconfig.Config, error) {
			return appconfig.Config{
				Runtimes: map[appconfig.RuntimeID]appconfig.RuntimeSettings{
					appconfig.RuntimeCodex: {},
				},
			}, nil
		},
	})
	server.markInitialized()

	catalog, err := taskconfig.LoadCatalog()
	if err != nil {
		t.Fatalf("load catalog: %v", err)
	}
	defaultAlias := catalog.DefaultAlias

	getBuiltinAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigPromptGet,
		Params: mustRawParams(t, configPromptGetParams{
			Alias:    defaultAlias,
			NodeName: "draft_plan",
		}),
	})
	if rpcErr != nil {
		t.Fatalf("builtin config.prompt.get rpc error: %+v", rpcErr)
	}
	getBuiltin := getBuiltinAny.(configPromptGetResult)
	if !getBuiltin.Prompt.Builtin || getBuiltin.Prompt.ReadOnly {
		t.Fatalf("builtin prompt flags = builtin:%v readonly:%v, want true/false", getBuiltin.Prompt.Builtin, getBuiltin.Prompt.ReadOnly)
	}
	if getBuiltin.Prompt.Path == "" || getBuiltin.Prompt.Content == "" || getBuiltin.Prompt.Revision == "" {
		t.Fatalf("builtin prompt payload incomplete: %#v", getBuiltin.Prompt)
	}

	builtinUpdatedContent := getBuiltin.Prompt.Content + "\n\nTighten verification."
	builtinSaveAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigPromptSave,
		Params: mustRawParams(t, configPromptSaveParams{
			Alias:            defaultAlias,
			NodeName:         "draft_plan",
			ExpectedRevision: getBuiltin.Prompt.Revision,
			Content:          builtinUpdatedContent,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("builtin config.prompt.save rpc error: %+v", rpcErr)
	}
	builtinSave := builtinSaveAny.(configPromptSaveResult)
	if builtinSave.Prompt.Content != builtinUpdatedContent {
		t.Fatalf("builtin prompt save content mismatch")
	}

	_, _, _, rpcErr = server.handleRequest(context.Background(), request{
		Method: methodConfigReset,
		Params: mustRawParams(t, configResetParams{Alias: defaultAlias}),
	})
	if rpcErr != nil {
		t.Fatalf("builtin prompt config.reset rpc error: %+v", rpcErr)
	}
	resetPromptAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigPromptGet,
		Params: mustRawParams(t, configPromptGetParams{
			Alias:    defaultAlias,
			NodeName: "draft_plan",
		}),
	})
	if rpcErr != nil {
		t.Fatalf("builtin prompt reload after reset rpc error: %+v", rpcErr)
	}
	resetPrompt := resetPromptAny.(configPromptGetResult)
	if resetPrompt.Prompt.Content != getBuiltin.Prompt.Content {
		t.Fatalf("builtin prompt after reset = %q, want original content", resetPrompt.Prompt.Content)
	}

	cloneAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigClone,
		Params: mustRawParams(t, configCloneParams{
			SourceAlias: defaultAlias,
			NewAlias:    "prompt-copy",
		}),
	})
	if rpcErr != nil {
		t.Fatalf("config.clone rpc error: %+v", rpcErr)
	}
	cloneResult := cloneAny.(configCloneResult)

	getCustomAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigPromptGet,
		Params: mustRawParams(t, configPromptGetParams{
			Alias:    cloneResult.Entry.Alias,
			NodeName: "draft_plan",
		}),
	})
	if rpcErr != nil {
		t.Fatalf("custom config.prompt.get rpc error: %+v", rpcErr)
	}
	getCustom := getCustomAny.(configPromptGetResult)
	if getCustom.Prompt.ReadOnly {
		t.Fatal("custom prompt readonly = true, want false")
	}

	updatedContent := getCustom.Prompt.Content + "\n\nAdd stronger implementation guardrails."
	savePromptAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodConfigPromptSave,
		Params: mustRawParams(t, configPromptSaveParams{
			Alias:            cloneResult.Entry.Alias,
			NodeName:         "draft_plan",
			ExpectedRevision: getCustom.Prompt.Revision,
			Content:          updatedContent,
		}),
	})
	if rpcErr != nil {
		t.Fatalf("custom config.prompt.save rpc error: %+v", rpcErr)
	}
	savePrompt := savePromptAny.(configPromptSaveResult)
	if savePrompt.Prompt.Content != updatedContent {
		t.Fatalf("saved prompt content mismatch")
	}
	if savePrompt.Prompt.Revision == "" || savePrompt.Prompt.Revision == getCustom.Prompt.Revision {
		t.Fatalf("saved prompt revision = %q, want new revision", savePrompt.Prompt.Revision)
	}

	_, _, _, rpcErr = server.handleRequest(context.Background(), request{
		Method: methodConfigPromptSave,
		Params: mustRawParams(t, configPromptSaveParams{
			Alias:            cloneResult.Entry.Alias,
			NodeName:         "draft_plan",
			ExpectedRevision: getCustom.Prompt.Revision,
			Content:          updatedContent,
		}),
	})
	if rpcErr == nil || rpcErr.Code != errorCodeConfigConflict {
		t.Fatalf("stale config.prompt.save rpc error = %+v, want config conflict", rpcErr)
	}

	_, _, _, rpcErr = server.handleRequest(context.Background(), request{
		Method: methodConfigPromptGet,
		Params: mustRawParams(t, configPromptGetParams{
			Alias:    cloneResult.Entry.Alias,
			NodeName: "approve_plan",
		}),
	})
	if rpcErr == nil || rpcErr.Code != errorCodeInvalidParams {
		t.Fatalf("human node config.prompt.get rpc error = %+v, want invalid params", rpcErr)
	}

	_, _, _, rpcErr = server.handleRequest(context.Background(), request{
		Method: methodConfigPromptGet,
		Params: mustRawParams(t, configPromptGetParams{
			Alias:    cloneResult.Entry.Alias,
			NodeName: "done",
		}),
	})
	if rpcErr == nil || rpcErr.Code != errorCodeInvalidParams {
		t.Fatalf("terminal node config.prompt.get rpc error = %+v, want invalid params", rpcErr)
	}
}

func newTestServer(t *testing.T) *Server {
	t.Helper()
	return newTestServerAtPath(t, filepath.Join(t.TempDir(), "appserver"))
}

func newTestServerAtPath(t *testing.T, stateDir string) *Server {
	t.Helper()
	return newTestServerWithOptions(t, stateDir, testServerOptions{})
}

type testServerOptions struct {
	runtimeFactory            runtimeServiceFactory
	agentChatClient           agentChatClient
	loadConfig                func() (appconfig.Config, error)
	loadCatalog               func() (*taskconfig.Catalog, error)
	loadRegistry              func() (taskconfig.Registry, error)
	loadTaskLaunchPreferences func() appconfig.TaskLaunchPreferences
	lookPath                  func(string) (string, error)
}

func newTestServerWithOptions(t *testing.T, stateDir string, opts testServerOptions) *Server {
	t.Helper()
	server, err := New(Options{
		StateDir:                  stateDir,
		ServerVersion:             "test",
		LoadConfig:                coalesceLoadConfig(opts.loadConfig),
		LoadCatalog:               opts.loadCatalog,
		LoadRegistry:              opts.loadRegistry,
		LoadTaskLaunchPreferences: opts.loadTaskLaunchPreferences,
		LookPath:                  opts.lookPath,
		RuntimeFactory:            opts.runtimeFactory,
		AgentChatClient:           opts.agentChatClient,
		WorktreeAvailable:         func(string) bool { return true },
	})
	if err != nil {
		t.Fatalf("new server: %v", err)
	}
	return server
}

type fakeAgentChatClient struct {
	call      func(context.Context, appwire.RPCRequest) (appwire.RPCResponse, error)
	subscribe func(context.Context, uint64, uint64) (<-chan appwire.EventStreamItem, error)
	events    <-chan appwire.EventStreamItem
}

func (f *fakeAgentChatClient) Call(ctx context.Context, req appwire.RPCRequest) (appwire.RPCResponse, error) {
	if f != nil && f.call != nil {
		return f.call(ctx, req)
	}
	return appwire.RPCResponse{}, nil
}

func (f *fakeAgentChatClient) Subscribe(ctx context.Context, streamEpoch, afterSeq uint64) (<-chan appwire.EventStreamItem, error) {
	if f != nil && f.subscribe != nil {
		return f.subscribe(ctx, streamEpoch, afterSeq)
	}
	if f != nil && f.events != nil {
		return f.events, nil
	}
	ch := make(chan appwire.EventStreamItem)
	go func() {
		<-ctx.Done()
		close(ch)
	}()
	return ch, nil
}

func coalesceLoadConfig(fn func() (appconfig.Config, error)) func() (appconfig.Config, error) {
	if fn != nil {
		return fn
	}
	return func() (appconfig.Config, error) {
		return appconfig.Default(), nil
	}
}

func writeRequestFrame(t *testing.T, dst *bytes.Buffer, id int, method string, params map[string]any) {
	t.Helper()
	writer := newFrameWriter(dst)
	if err := writer.writeJSON(map[string]any{
		"jsonrpc": jsonRPCVersion,
		"id":      id,
		"method":  method,
		"params":  params,
	}); err != nil {
		t.Fatalf("write frame: %v", err)
	}
}

func readFramesAsMaps(t *testing.T, payload []byte) []map[string]any {
	t.Helper()
	reader := newFrameReader(bytes.NewReader(payload))
	var messages []map[string]any
	for {
		frame, err := reader.readFrame()
		if err != nil {
			if err == io.EOF {
				break
			}
			t.Fatalf("read frame: %v", err)
		}
		var msg map[string]any
		if err := json.Unmarshal(frame, &msg); err != nil {
			t.Fatalf("unmarshal frame: %v", err)
		}
		messages = append(messages, msg)
	}
	return messages
}

func responseByID(t *testing.T, messages []map[string]any, id int) map[string]any {
	t.Helper()
	for _, message := range messages {
		rawID, ok := message["id"]
		if !ok {
			continue
		}
		number, ok := rawID.(float64)
		if !ok {
			continue
		}
		if int(number) == id {
			return message
		}
	}
	t.Fatalf("missing response id %d", id)
	return nil
}

func nestedString(m map[string]any, path ...string) (string, bool) {
	value, ok := nestedValue(m, path...)
	if !ok {
		return "", false
	}
	str, ok := value.(string)
	return str, ok
}

func nestedStringMust(t *testing.T, m map[string]any, path ...string) string {
	t.Helper()
	value, ok := nestedString(m, path...)
	if !ok {
		t.Fatalf("missing string at path %v in %#v", path, m)
	}
	return value
}

func nestedBool(m map[string]any, path ...string) (bool, bool) {
	value, ok := nestedValue(m, path...)
	if !ok {
		return false, false
	}
	boolean, ok := value.(bool)
	return boolean, ok
}

func nestedFloat(m map[string]any, path ...string) float64 {
	value, ok := nestedValue(m, path...)
	if !ok {
		return 0
	}
	number, _ := value.(float64)
	return number
}

func nestedSlice(t *testing.T, m map[string]any, path ...string) []any {
	t.Helper()
	value, ok := nestedValue(m, path...)
	if !ok {
		t.Fatalf("missing slice at path %v in %#v", path, m)
	}
	items, ok := value.([]any)
	if !ok {
		t.Fatalf("value at path %v is %T, want []any", path, value)
	}
	return items
}

func nestedValue(m map[string]any, path ...string) (any, bool) {
	var current any = m
	for _, segment := range path {
		nextMap, ok := current.(map[string]any)
		if !ok {
			return nil, false
		}
		value, ok := nextMap[segment]
		if !ok {
			return nil, false
		}
		current = value
	}
	return current, true
}

func mustRawParams(t *testing.T, params any) json.RawMessage {
	t.Helper()
	payload, err := json.Marshal(params)
	if err != nil {
		t.Fatalf("marshal params: %v", err)
	}
	return payload
}

func materializeEmbeddedDefaultTestConfig(t *testing.T, workDir, taskID string) *taskconfig.MaterializedConfig {
	t.Helper()
	materialized, err := taskconfig.Materialize(workDir, taskID, "")
	if err != nil {
		t.Fatalf("materialize config: %v", err)
	}
	return materialized
}

func seedAwaitingTask(t *testing.T, workDir string) (taskID string, awaitingRunID string) {
	t.Helper()
	store, err := taskstore.Open(workDir)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	defer func() { _ = store.Close() }()

	taskID = "task-awaiting"
	materialized := materializeEmbeddedDefaultTestConfig(t, workDir, taskID)

	now := time.Date(2026, 4, 3, 12, 0, 0, 0, time.UTC)
	completedAt := now.Add(30 * time.Second)
	task := taskdomain.Task{
		ID:           taskID,
		Description:  "Review desktop task startup",
		ConfigAlias:  "default",
		ConfigPath:   materialized.ConfigPath,
		WorkDir:      taskstore.NormalizeWorkDir(workDir),
		ExecutionDir: taskstore.NormalizeWorkDir(workDir),
		CreatedAt:    now,
		UpdatedAt:    now.Add(2 * time.Minute),
	}
	entryRun := taskdomain.NodeRun{
		ID:          "run-draft",
		TaskID:      taskID,
		NodeName:    "draft_plan",
		Status:      taskdomain.NodeRunDone,
		Result:      map[string]interface{}{"file_paths": []string{"plan.md"}},
		StartedAt:   now,
		CompletedAt: &completedAt,
	}
	if err := store.CreateTaskWithEntryRun(context.Background(), task, entryRun); err != nil {
		t.Fatalf("create task with entry run: %v", err)
	}

	awaitingRunID = "run-approve"
	awaitingRun := taskdomain.NodeRun{
		ID:        awaitingRunID,
		TaskID:    taskID,
		NodeName:  "approve_plan",
		Status:    taskdomain.NodeRunAwaitingUser,
		StartedAt: now.Add(time.Minute),
	}
	if err := store.SaveNodeRun(context.Background(), awaitingRun); err != nil {
		t.Fatalf("save awaiting node run: %v", err)
	}

	artifactPath := filepath.Join(taskstore.RunDir(workDir, taskID, entryRun.ID), "plan.md")
	if err := os.MkdirAll(filepath.Dir(artifactPath), 0o755); err != nil {
		t.Fatalf("mkdir artifact dir: %v", err)
	}
	if err := os.WriteFile(artifactPath, []byte("# plan\n"), 0o644); err != nil {
		t.Fatalf("write artifact: %v", err)
	}
	return taskID, awaitingRunID
}

func seedAppServerGitRepo(t *testing.T) string {
	t.Helper()
	repo := t.TempDir()
	resolved, err := filepath.EvalSymlinks(repo)
	if err != nil {
		t.Fatalf("resolve repo path: %v", err)
	}
	repo = resolved
	runTestGit(t, repo, "git", "init")
	runTestGit(t, repo, "git", "config", "user.email", "test@test.com")
	runTestGit(t, repo, "git", "config", "user.name", "Test")
	if err := os.MkdirAll(filepath.Join(repo, "packages", "app"), 0o755); err != nil {
		t.Fatalf("mkdir repo app dir: %v", err)
	}
	if err := os.WriteFile(filepath.Join(repo, "README.md"), []byte("hello"), 0o644); err != nil {
		t.Fatalf("write README: %v", err)
	}
	if err := os.WriteFile(filepath.Join(repo, "packages", "app", ".keep"), []byte("keep"), 0o644); err != nil {
		t.Fatalf("write .keep: %v", err)
	}
	if err := os.WriteFile(filepath.Join(repo, "packages", "app", "delete-me.txt"), []byte("delete"), 0o644); err != nil {
		t.Fatalf("write delete-me.txt: %v", err)
	}
	runTestGit(t, repo, "git", "add", ".")
	runTestGit(t, repo, "git", "commit", "-m", "init")
	return repo
}

func assertTaskGetFollowUpMetadata(t *testing.T, server *Server, workspaceID, taskID string, minDirtyCount int) {
	t.Helper()
	getResultAny, _, _, rpcErr := server.handleRequest(context.Background(), request{
		Method: methodTaskGet,
		Params: mustRawParams(t, taskGetParams{WorkspaceID: workspaceID, TaskID: taskID}),
	})
	if rpcErr != nil {
		t.Fatalf("task.get rpc error: %+v", rpcErr)
	}
	getResult := getResultAny.(taskGetResult)
	if getResult.FollowUp == nil {
		t.Fatal("task.get follow_up = nil, want value")
	}
	if got := getResult.FollowUpState; got != followUpStateRefine {
		t.Fatalf("task.get follow_up_state = %q, want %q", got, followUpStateRefine)
	}
	if got := getResult.FollowUp.DefaultMode; got != taskruntime.FollowUpModeContinueHere {
		t.Fatalf("task.get follow_up.default_mode = %q, want %q", got, taskruntime.FollowUpModeContinueHere)
	}
	if got := getResult.FollowUp.AvailableModes; len(got) != 3 {
		t.Fatalf("task.get follow_up.available_modes len = %d, want 3", len(got))
	}
	if got := getResult.FollowUp.UncommittedChangeCount; got < minDirtyCount {
		t.Fatalf("task.get follow_up.uncommitted_change_count = %d, want >= %d", got, minDirtyCount)
	}
}

func seedCompletedAppServerTask(t *testing.T, workDir, taskID, description, executionDir string) string {
	t.Helper()
	store, err := taskstore.Open(workDir)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	defer func() { _ = store.Close() }()

	materialized := materializeEmbeddedDefaultTestConfig(t, workDir, taskID)

	now := time.Date(2026, 4, 12, 2, 0, 0, 0, time.UTC)
	task := taskdomain.Task{
		ID:           taskID,
		Description:  description,
		ConfigAlias:  "default",
		ConfigPath:   materialized.ConfigPath,
		WorkDir:      taskstore.NormalizeWorkDir(workDir),
		ExecutionDir: taskstore.NormalizeWorkDir(executionDir),
		CreatedAt:    now,
		UpdatedAt:    now.Add(2 * time.Minute),
	}
	entryCompleted := now.Add(time.Minute)
	entryRun := taskdomain.NodeRun{
		ID:          "run-implement-" + taskID,
		TaskID:      taskID,
		NodeName:    "handle_request",
		Status:      taskdomain.NodeRunDone,
		StartedAt:   now,
		CompletedAt: &entryCompleted,
	}
	if err := store.CreateTaskWithEntryRun(context.Background(), task, entryRun); err != nil {
		t.Fatalf("create task with entry run: %v", err)
	}
	doneRun := taskdomain.NodeRun{
		ID:          "run-done-" + taskID,
		TaskID:      taskID,
		NodeName:    "done",
		Status:      taskdomain.NodeRunDone,
		StartedAt:   entryCompleted,
		CompletedAt: &entryCompleted,
	}
	if err := store.SaveNodeRun(context.Background(), doneRun); err != nil {
		t.Fatalf("save terminal run: %v", err)
	}
	return taskID
}

func seedCompletedRepoBackedMainCheckoutTask(t *testing.T, workDir string) string {
	t.Helper()
	if err := os.WriteFile(filepath.Join(workDir, ".keep"), []byte("dirty"), 0o644); err != nil {
		t.Fatalf("edit tracked file: %v", err)
	}
	if err := os.Remove(filepath.Join(workDir, "delete-me.txt")); err != nil {
		t.Fatalf("delete tracked file: %v", err)
	}
	if err := os.WriteFile(filepath.Join(workDir, "notes.md"), []byte("notes"), 0o644); err != nil {
		t.Fatalf("write untracked file: %v", err)
	}
	return seedCompletedAppServerTask(
		t,
		workDir,
		"task-main-follow-up",
		"Completed main-checkout task",
		workDir,
	)
}

func seedCompletedWorktreeTask(t *testing.T, workDir string) string {
	t.Helper()
	repoRoot, err := worktree.FindRepoRoot(workDir)
	if err != nil {
		t.Fatalf("find repo root: %v", err)
	}
	parentWorktreeRoot, err := worktree.Create(repoRoot, "appserver-follow-up-parent")
	if err != nil {
		t.Fatalf("create parent worktree: %v", err)
	}
	runTestGit(t, repoRoot, "git", "add", ".")
	if err := os.WriteFile(filepath.Join(repoRoot, "repo-head.txt"), []byte("moved"), 0o644); err != nil {
		t.Fatalf("write repo-head.txt: %v", err)
	}
	runTestGit(t, repoRoot, "git", "add", "repo-head.txt")
	runTestGit(t, repoRoot, "git", "commit", "-m", "move repo head")

	parentExecutionDir := filepath.Join(parentWorktreeRoot, "packages", "app")
	if err := os.WriteFile(filepath.Join(parentExecutionDir, ".keep"), []byte("dirty"), 0o644); err != nil {
		t.Fatalf("edit parent tracked file: %v", err)
	}
	if err := os.Remove(filepath.Join(parentExecutionDir, "delete-me.txt")); err != nil {
		t.Fatalf("delete parent tracked file: %v", err)
	}
	if err := os.WriteFile(filepath.Join(parentWorktreeRoot, "notes.md"), []byte("notes"), 0o644); err != nil {
		t.Fatalf("write parent untracked file: %v", err)
	}

	return seedCompletedAppServerTask(
		t,
		workDir,
		"task-worktree-follow-up",
		"Completed worktree task",
		parentExecutionDir,
	)
}

func seedRunningAppServerTask(t *testing.T, workDir, taskID, description, executionDir string) string {
	t.Helper()
	store, err := taskstore.Open(workDir)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	defer func() { _ = store.Close() }()

	materialized := materializeEmbeddedDefaultTestConfig(t, workDir, taskID)

	now := time.Date(2026, 4, 12, 3, 0, 0, 0, time.UTC)
	task := taskdomain.Task{
		ID:           taskID,
		Description:  description,
		ConfigAlias:  "default",
		ConfigPath:   materialized.ConfigPath,
		WorkDir:      taskstore.NormalizeWorkDir(workDir),
		ExecutionDir: taskstore.NormalizeWorkDir(executionDir),
		CreatedAt:    now,
		UpdatedAt:    now.Add(time.Minute),
	}
	entryRun := taskdomain.NodeRun{
		ID:        "run-running-" + taskID,
		TaskID:    taskID,
		NodeName:  "handle_request",
		Status:    taskdomain.NodeRunRunning,
		StartedAt: now,
	}
	if err := store.CreateTaskWithEntryRun(context.Background(), task, entryRun); err != nil {
		t.Fatalf("create running task with entry run: %v", err)
	}
	return taskID
}

func seedSharedWorktreeTasks(t *testing.T, workDir string) (completedTaskID, runningTaskID, branchID string) {
	t.Helper()
	repoRoot, err := worktree.FindRepoRoot(workDir)
	if err != nil {
		t.Fatalf("find repo root: %v", err)
	}
	branchID = "appserver-shared-worktree"
	sharedWorktreeRoot, err := worktree.Create(repoRoot, branchID)
	if err != nil {
		t.Fatalf("create shared worktree: %v", err)
	}
	executionDir := filepath.Join(sharedWorktreeRoot, "packages", "app")
	completedTaskID = seedCompletedAppServerTask(
		t,
		workDir,
		"task-shared-worktree-completed",
		"Completed shared worktree task",
		executionDir,
	)
	runningTaskID = seedRunningAppServerTask(
		t,
		workDir,
		"task-shared-worktree-running",
		"Live shared worktree task",
		executionDir,
	)

	store, err := taskstore.Open(workDir)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	defer func() { _ = store.Close() }()
	if err := store.AttachFollowUpParent(context.Background(), completedTaskID, runningTaskID, time.Date(2026, 4, 12, 3, 5, 0, 0, time.UTC)); err != nil {
		t.Fatalf("attach shared worktree lineage: %v", err)
	}
	return completedTaskID, runningTaskID, branchID
}

func runTestGit(t *testing.T, dir string, name string, args ...string) {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("command %s %v failed: %s", name, args, string(out))
	}
}

func seedTaskAncestryChain(t *testing.T, workDir string) (rootTaskID, parentTaskID, childTaskID string) {
	t.Helper()
	store, err := taskstore.Open(workDir)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	defer func() { _ = store.Close() }()

	normalizedWorkDir := taskstore.NormalizeWorkDir(workDir)
	ctx := context.Background()
	baseTime := time.Date(2026, 4, 3, 12, 0, 0, 0, time.UTC)

	createTask := func(taskID, description, nodeName string, status taskdomain.NodeRunStatus, createdAt, updatedAt time.Time, completedAt *time.Time) {
		t.Helper()
		materialized := materializeEmbeddedDefaultTestConfig(t, workDir, taskID)
		task := taskdomain.Task{
			ID:           taskID,
			Description:  description,
			ConfigAlias:  "default",
			ConfigPath:   materialized.ConfigPath,
			WorkDir:      normalizedWorkDir,
			ExecutionDir: normalizedWorkDir,
			CreatedAt:    createdAt,
			UpdatedAt:    updatedAt,
		}
		entryRun := taskdomain.NodeRun{
			ID:          "run-" + taskID,
			TaskID:      taskID,
			NodeName:    nodeName,
			Status:      status,
			StartedAt:   createdAt,
			CompletedAt: completedAt,
		}
		if err := store.CreateTaskWithEntryRun(ctx, task, entryRun); err != nil {
			t.Fatalf("create task %s: %v", taskID, err)
		}
	}

	rootTaskID = "task-ancestry-root"
	rootCompletedAt := baseTime.Add(2 * time.Minute)
	createTask(
		rootTaskID,
		"Stabilize authentication pipeline",
		"done",
		taskdomain.NodeRunDone,
		baseTime,
		baseTime.Add(3*time.Minute),
		&rootCompletedAt,
	)

	parentTaskID = "task-ancestry-parent"
	parentCompletedAt := baseTime.Add(12 * time.Minute)
	createTask(
		parentTaskID,
		"Harden refresh token handling",
		"done",
		taskdomain.NodeRunDone,
		baseTime.Add(10*time.Minute),
		baseTime.Add(13*time.Minute),
		&parentCompletedAt,
	)
	if err := store.AttachFollowUpParent(ctx, rootTaskID, parentTaskID, baseTime.Add(13*time.Minute)); err != nil {
		t.Fatalf("attach root->parent lineage: %v", err)
	}

	childTaskID = "task-ancestry-child"
	createTask(
		childTaskID,
		"Show parent task ancestry in task detail",
		"draft_plan",
		taskdomain.NodeRunRunning,
		baseTime.Add(20*time.Minute),
		baseTime.Add(21*time.Minute),
		nil,
	)
	if err := store.AttachFollowUpParent(ctx, parentTaskID, childTaskID, baseTime.Add(21*time.Minute)); err != nil {
		t.Fatalf("attach parent->child lineage: %v", err)
	}

	return rootTaskID, parentTaskID, childTaskID
}

func seedRecoverableTerminalRun(t *testing.T, workDir string, output []byte) (taskID string, nodeRunID string) {
	t.Helper()
	store, err := taskstore.Open(workDir)
	if err != nil {
		t.Fatalf("open task store: %v", err)
	}
	defer func() { _ = store.Close() }()

	taskID = "task-stale-terminal"
	_, thisFile, _, ok := goruntime.Caller(0)
	if !ok {
		t.Fatal("resolve appserver test file path")
	}
	configPath := filepath.Join(filepath.Dir(thisFile), "..", "taskconfig", "defaults", "single-run.yaml")
	materialized, err := taskconfig.Materialize(workDir, taskID, configPath)
	if err != nil {
		t.Fatalf("materialize config: %v", err)
	}

	now := time.Date(2026, 4, 12, 2, 30, 0, 0, time.UTC)
	task := taskdomain.Task{
		ID:           taskID,
		Description:  "Recover stale run",
		ConfigAlias:  "default",
		ConfigPath:   materialized.ConfigPath,
		WorkDir:      taskstore.NormalizeWorkDir(workDir),
		ExecutionDir: taskstore.NormalizeWorkDir(workDir),
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	if err := store.CreateTask(context.Background(), task); err != nil {
		t.Fatalf("create task: %v", err)
	}

	nodeRunID = "run-stale-terminal"
	run := taskdomain.NodeRun{
		ID:        nodeRunID,
		TaskID:    taskID,
		NodeName:  "handle_request",
		Status:    taskdomain.NodeRunRunning,
		StartedAt: now.Add(time.Minute),
	}
	if err := store.SaveNodeRun(context.Background(), run); err != nil {
		t.Fatalf("save node run: %v", err)
	}

	if len(output) > 0 {
		outputPath := filepath.Join(taskstore.RunDir(workDir, taskID, nodeRunID), "output.json")
		if err := os.MkdirAll(filepath.Dir(outputPath), 0o755); err != nil {
			t.Fatalf("mkdir output dir: %v", err)
		}
		if err := os.WriteFile(outputPath, output, 0o644); err != nil {
			t.Fatalf("write output: %v", err)
		}
	}

	return taskID, nodeRunID
}

func waitForNotificationWhere(t *testing.T, notifications <-chan notification, timeout time.Duration, match func(notificationParams) bool) notificationParams {
	t.Helper()
	deadline := time.After(timeout)
	for {
		select {
		case <-deadline:
			t.Fatal("timed out waiting for matching notification")
		case n := <-notifications:
			params, ok := n.Params.(notificationParams)
			if !ok {
				continue
			}
			if match(params) {
				return params
			}
		}
	}
}

func singleRunConfigPathForAppServerTest(t *testing.T) string {
	t.Helper()
	_, thisFile, _, ok := goruntime.Caller(0)
	if !ok {
		t.Fatal("resolve appserver test file path")
	}
	return filepath.Join(filepath.Dir(thisFile), "..", "taskconfig", "defaults", "single-run.yaml")
}

func writeSmokeCodexAppServerBinary(t *testing.T, path string) {
	t.Helper()
	script := `#!/bin/sh
set -eu

if [ "${1:-}" != "app-server" ]; then
  echo "unexpected args" >&2
  exit 2
fi

while IFS= read -r line; do
  case "$line" in
    *'"method":"initialize"'*)
      printf '%s\n' '{"id":1,"result":{"userAgent":"fake","codexHome":"/tmp/.codex","platformFamily":"unix","platformOs":"linux"}}'
      ;;
    *'"method":"initialized"'*)
      ;;
    *'"method":"thread/start"'*)
      printf '%s\n' '{"id":2,"result":{"thread":{"id":"thread-smoke","status":{"type":"idle"},"cwd":"/tmp/project"}}}'
      ;;
    *'"method":"turn/start"'*)
      cat <<'JSON'
{"id":3,"result":{"turn":{"id":"turn-smoke","status":"inProgress","items":[],"error":null}}}
{"method":"turn/started","params":{"threadId":"thread-smoke","turn":{"id":"turn-smoke","status":"inProgress","items":[],"error":null}}}
{"method":"item/started","params":{"threadId":"thread-smoke","turnId":"turn-smoke","item":{"type":"agentMessage","id":"msg-commentary","text":"","phase":"commentary"}}}
{"method":"item/agentMessage/delta","params":{"threadId":"thread-smoke","turnId":"turn-smoke","itemId":"msg-commentary","delta":"Inspect"}}
{"method":"item/agentMessage/delta","params":{"threadId":"thread-smoke","turnId":"turn-smoke","itemId":"msg-commentary","delta":" repo"}}
JSON
      cat <<'JSON'
{"method":"item/reasoning/summaryTextDelta","params":{"threadId":"thread-smoke","turnId":"turn-smoke","itemId":"reason-1","summaryIndex":0,"delta":"Check"}}
{"method":"item/reasoning/summaryTextDelta","params":{"threadId":"thread-smoke","turnId":"turn-smoke","itemId":"reason-1","summaryIndex":0,"delta":" state"}}
{"method":"item/started","params":{"threadId":"thread-smoke","turnId":"turn-smoke","item":{"type":"mcpToolCall","id":"mcp-1","server":"pencil","tool":"get_editor_state","arguments":{"include_schema":true},"status":"inProgress"}}}
{"method":"item/mcpToolCall/progress","params":{"threadId":"thread-smoke","turnId":"turn-smoke","itemId":"mcp-1","message":"Loaded schema."}}
{"method":"item/completed","params":{"threadId":"thread-smoke","turnId":"turn-smoke","item":{"type":"mcpToolCall","id":"mcp-1","server":"pencil","tool":"get_editor_state","arguments":{"include_schema":true},"status":"completed","durationMs":42,"result":{"content":[{"type":"text","text":"Loaded schema."}],"structuredContent":{"selection":"canvas-root"}}}}}
{"method":"item/completed","params":{"threadId":"thread-smoke","turnId":"turn-smoke","item":{"type":"agentMessage","id":"msg-final","text":"{\"kind\":\"result\",\"result\":{\"summary\":\"Smoke summary\",\"file_paths\":[\"/tmp/result.md\"]},\"clarification\":null}","phase":"final_answer"}}}
{"method":"thread/tokenUsage/updated","params":{"threadId":"thread-smoke","turnId":"turn-smoke","tokenUsage":{"total":{"totalTokens":12,"inputTokens":7,"cachedInputTokens":1,"outputTokens":5}}}}
{"method":"turn/completed","params":{"threadId":"thread-smoke","turn":{"id":"turn-smoke","status":"completed","items":[],"error":null}}}
JSON
      exit 0
      ;;
  esac
done
`
	if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
		t.Fatalf("write fake codex app-server binary: %v", err)
	}
}

type fakeRuntimeService struct {
	mu           sync.Mutex
	events       chan taskruntime.RunEvent
	dispatches   []taskruntime.RunCommand
	closeCalls   int
	prepareCalls int
}

func newFakeRuntimeService() *fakeRuntimeService {
	return &fakeRuntimeService{
		events: make(chan taskruntime.RunEvent, 16),
	}
}

func (f *fakeRuntimeService) Run(ctx context.Context) error {
	<-ctx.Done()
	return ctx.Err()
}

func (f *fakeRuntimeService) Events() <-chan taskruntime.RunEvent {
	return f.events
}

func (f *fakeRuntimeService) Dispatch(cmd taskruntime.RunCommand) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.dispatches = append(f.dispatches, cmd)
}

func (f *fakeRuntimeService) PrepareShutdown(ctx context.Context) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.prepareCalls++
	return nil
}

func (f *fakeRuntimeService) Close() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.closeCalls++
	return nil
}

func (f *fakeRuntimeService) Dispatched() []taskruntime.RunCommand {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]taskruntime.RunCommand, len(f.dispatches))
	copy(out, f.dispatches)
	return out
}

func (f *fakeRuntimeService) CloseCalls() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.closeCalls
}

func (f *fakeRuntimeService) PrepareShutdownCalls() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.prepareCalls
}

type shutdownAwareBuffer struct {
	t      *testing.T
	server *Server
	bytes.Buffer
}

func (b *shutdownAwareBuffer) Write(p []byte) (int, error) {
	b.t.Helper()
	if b.server != nil && b.server.GracefulShutdownRequested() {
		b.t.Fatal("graceful shutdown requested before shutdown response finished writing")
	}
	return b.Buffer.Write(p)
}
