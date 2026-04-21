package taskruntime

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	goruntime "runtime"
	"strings"
	"sync"
	"testing"
	"time"

	appconfig "github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/taskconfig"
	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskengine"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor"
	"github.com/LaLanMo/muxagent/cli/internal/taskhistory"
	"github.com/LaLanMo/muxagent/cli/internal/taskstore"
	"github.com/LaLanMo/muxagent/cli/internal/worktree"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

func TestServiceHappyPathCompletesDefaultFlow(t *testing.T) {
	service := newTestService(t, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan":  {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan.md")}},
			"review_plan": {{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review.md"}}}},
			"implement":   {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
			"verify":      {{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/verify.md"}}}},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "Implement login"))
	inputEvent := waitForEvent(t, service.Events(), EventInputRequested)
	require.NotNil(t, inputEvent.InputRequest)
	assert.Equal(t, InputKindHumanNode, inputEvent.InputRequest.Kind)

	service.Dispatch(RunCommand{
		Type:      CommandSubmitInput,
		TaskID:    inputEvent.TaskID,
		NodeRunID: inputEvent.NodeRunID,
		Payload:   map[string]interface{}{"approved": true},
	})
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	views, err := service.ListTaskViews(context.Background(), service.workDir)
	require.NoError(t, err)
	require.Len(t, views, 1)
	assert.Equal(t, taskdomain.TaskStatusDone, views[0].Status)
}

func TestServiceAgentRunPersistsPromptInputArtifact(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
	}
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "Implement login"))
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	requests := executor.requestsForNode("implement")
	require.Len(t, requests, 1)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	require.Len(t, runs, 2)

	var implementRun taskdomain.NodeRun
	for _, run := range runs {
		if run.NodeName == "implement" {
			implementRun = run
			break
		}
	}
	require.Equal(t, taskdomain.NodeRunDone, implementRun.Status)

	artifactPaths := taskdomain.ArtifactPaths(implementRun.Result)
	require.Len(t, artifactPaths, 1)
	implPath := filepath.Join(requests[0].ArtifactDir, findArtifactPathByBase(t, artifactPaths, "impl.md"))
	inputPath := mustRunArtifactPathForRun(t, completed.TaskView.Task, runs, implementRun, inputArtifactName)
	outputPath := mustRunArtifactPathForRun(t, completed.TaskView.Task, runs, implementRun, outputArtifactName)
	assert.FileExists(t, inputPath)
	assert.FileExists(t, implPath)
	assert.FileExists(t, outputPath)
	input := readTestFile(t, inputPath)
	assert.Equal(t, taskexecutor.AppendOutputContract(requests[0]), input)
	assert.NotContains(t, input, "## Prompt")
	assert.NotContains(t, input, "# Input")
	assert.NotContains(t, completed.TaskView.ArtifactPaths, inputPath)
	assert.Contains(t, completed.TaskView.ArtifactPaths, "impl.md")
}

func TestServiceStartTaskPersistsImageAttachmentsForAgentInput(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
	}
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	cmd := startTaskCommand(t, service, "Inspect this screenshot")
	cmd.ImageAttachments = []ImageAttachmentInput{testImageAttachmentInput(t, "screen shot.png")}
	service.Dispatch(cmd)
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)

	requests := executor.requestsForNode("implement")
	require.Len(t, requests, 1)
	require.Len(t, requests[0].ImagePaths, 1)
	assert.FileExists(t, requests[0].ImagePaths[0])

	runs, err := service.store.ListNodeRunsByTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	var implementRun taskdomain.NodeRun
	for _, run := range runs {
		if run.NodeName == "implement" {
			implementRun = run
			break
		}
	}
	images, err := readImageAttachmentManifest(completed.TaskView.Task, runs, implementRun)
	require.NoError(t, err)
	require.Len(t, images, 1)
	assert.Equal(t, "screen shot.png", images[0].OriginalFilename)
	assert.Equal(t, "image/png", images[0].MIMEType)
	assert.Equal(t, requests[0].ImagePaths[0], images[0].AbsolutePath)
	assert.Contains(t, images[0].RelativePath, "001-screen-shot.png")

	manifestPath := mustRunArtifactPathForRun(t, completed.TaskView.Task, runs, implementRun, attachmentManifestName)
	inputPath := mustRunArtifactPathForRun(t, completed.TaskView.Task, runs, implementRun, inputArtifactName)
	assert.FileExists(t, manifestPath)
	input := readTestFile(t, inputPath)
	assert.Contains(t, input, "Image attachments are available as managed local files")
	assert.Contains(t, input, images[0].AbsolutePath)
	assert.Contains(t, requests[0].Prompt, images[0].AbsolutePath)
}

func TestServiceVerifyRunUsesFilesystemOrientedWorkflowContext(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan":  {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan.md")}},
			"review_plan": {{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review.md"}}}},
			"implement":   {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
			"verify":      {{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/verify.md"}}}},
		},
	}
	service := newTestService(t, executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	description := "Implement login\nHandle SSO fallback"
	service.Dispatch(startTaskCommand(t, service, description))
	inputEvent := waitForEvent(t, service.Events(), EventInputRequested)
	require.NotNil(t, inputEvent.InputRequest)
	require.Equal(t, InputKindHumanNode, inputEvent.InputRequest.Kind)

	service.Dispatch(RunCommand{
		Type:      CommandSubmitInput,
		TaskID:    inputEvent.TaskID,
		NodeRunID: inputEvent.NodeRunID,
		Payload:   map[string]interface{}{"approved": true},
	})
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	verifyRequests := executor.requestsForNode("verify")
	require.Len(t, verifyRequests, 1)
	verifyPrompt := verifyRequests[0].Prompt
	assert.True(t, strings.HasPrefix(verifyPrompt, "<task_metadata>"))
	assert.Contains(t, verifyPrompt, "<task_dir>")
	assert.Contains(t, verifyPrompt, "<execution_dir>"+service.workDir+"</execution_dir>")
	assert.Contains(t, verifyPrompt, "Primary task for this step:\n<<< PRIMARY TASK >>>\nImplement login\nHandle SSO fallback\n<<< END PRIMARY TASK >>>")
	assert.Contains(t, verifyPrompt, "<execution_context>")
	assert.Contains(t, verifyPrompt, "Unless the user explicitly says otherwise, do all project edits, builds, tests, and commands in `&lt;execution_dir&gt;`.")
	assert.Contains(t, verifyPrompt, "<clarification_state>\n(none)\n</clarification_state>")
	assert.Contains(t, verifyPrompt, "Workflow for this config:")
	assert.Contains(t, verifyPrompt, "Read the newest accepted plan artifacts and the newest implementation artifacts for this attempt before you judge the result.")
	assert.Contains(t, verifyPrompt, "That includes existing unit tests, integration tests, end-to-end tests, builds, linters")
	assert.NotContains(t, verifyPrompt, "Current task directory:")
	assert.NotContains(t, verifyPrompt, "All run directories for this task:")
	assert.NotContains(t, verifyPrompt, "Current run directory for this step:")
	assert.NotContains(t, verifyPrompt, "For `verify`, read the newest completed `implement` run")
	assert.NotContains(t, verifyPrompt, "Artifacts:")
	assert.NotContains(t, verifyPrompt, "/tmp/review.md")
	assert.NotContains(t, verifyPrompt, `"passed":true`)
	assert.Contains(t, verifyPrompt, "decision: passed=true")

	runs, err := service.store.ListNodeRunsByTask(context.Background(), completed.TaskID)
	require.NoError(t, err)

	var reviewRun taskdomain.NodeRun
	var verifyRun taskdomain.NodeRun
	for _, run := range runs {
		if run.NodeName == "review_plan" {
			reviewRun = run
		}
		if run.NodeName == "verify" {
			verifyRun = run
		}
	}
	require.Equal(t, taskdomain.NodeRunDone, reviewRun.Status)
	require.Equal(t, taskdomain.NodeRunDone, verifyRun.Status)
	assert.Contains(t, verifyPrompt, taskstore.TaskDir(service.workDir, completed.TaskID))
	assert.Contains(t, verifyPrompt, taskstore.RunDir(service.workDir, completed.TaskID, reviewRun.ID))

	inputPath := mustRunArtifactPathForRun(t, completed.TaskView.Task, runs, verifyRun, inputArtifactName)
	input := readTestFile(t, inputPath)
	assert.True(t, strings.HasPrefix(input, "<task_metadata>"))
	assert.Contains(t, input, "<execution_dir>"+service.workDir+"</execution_dir>")
	assert.Contains(t, input, "Primary task for this step:\n<<< PRIMARY TASK >>>\nImplement login\nHandle SSO fallback\n<<< END PRIMARY TASK >>>")
	assert.Contains(t, input, "<execution_context>")
	assert.Contains(t, input, "Unless the user explicitly says otherwise, do all project edits, builds, tests, and commands in `&lt;execution_dir&gt;`.")
	assert.NotContains(t, input, "Current task directory:")
	assert.NotContains(t, input, "All run directories for this task:")
	assert.NotContains(t, input, "Current run directory for this step:")
	assert.NotContains(t, input, "Artifacts:")
	assert.NotContains(t, input, "/tmp/review.md")
	assert.NotContains(t, input, `"passed":true`)
	assert.Contains(t, input, taskstore.RunDir(service.workDir, completed.TaskID, reviewRun.ID))
}

func TestServiceClarificationUsesSameNodeRun(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{
					Kind: taskexecutor.ResultKindClarification,
					Clarification: &taskdomain.ClarificationRequest{
						Questions: []taskdomain.ClarificationQuestion{
							{
								Question:     "Need a choice",
								WhyItMatters: "Impacts plan",
								Options: []taskdomain.ClarificationOption{
									{Label: "A", Description: "Option A"},
									{Label: "B", Description: "Option B"},
								},
							},
						},
					},
				},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan.md")},
			},
			"review_plan": {{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review.md"}}}},
		},
	}
	service := newTestService(t, executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "Implement login"))
	requested := waitForEvent(t, service.Events(), EventInputRequested)
	require.Equal(t, InputKindClarification, requested.InputRequest.Kind)
	draftRequests := executor.requestsForNode("draft_plan")
	require.Len(t, draftRequests, 1)
	expectedInputPrefix := taskexecutor.AppendOutputContract(draftRequests[0])
	task, err := service.store.GetTask(context.Background(), requested.TaskID)
	require.NoError(t, err)
	beforeRuns, err := service.store.ListNodeRunsByTask(context.Background(), requested.TaskID)
	require.NoError(t, err)
	var requestedRun taskdomain.NodeRun
	for _, run := range beforeRuns {
		if run.ID == requested.NodeRunID {
			requestedRun = run
			break
		}
	}
	requestInputPath := mustRunArtifactPathForRun(t, task, beforeRuns, requestedRun, inputArtifactName)
	requestInput := readTestFile(t, requestInputPath)
	assert.True(t, strings.HasPrefix(requestInput, expectedInputPrefix))
	assert.NotContains(t, requestInput, "## Prompt")
	assert.Contains(t, requestInput, "<task_metadata>")
	assert.Contains(t, requestInput, "<current_step>draft_plan</current_step>")
	assert.Contains(t, requestInput, "<clarification_state>")
	assert.Contains(t, requestInput, "Need a choice")
	assert.Contains(t, requestInput, "Why it matters: Impacts plan")
	assert.Contains(t, requestInput, "Answer: pending")
	assert.Len(t, beforeRuns, 1)
	assert.NotContains(t, requested.InputRequest.ArtifactPaths, requestInputPath)

	service.Dispatch(RunCommand{
		Type:      CommandSubmitInput,
		TaskID:    requested.TaskID,
		NodeRunID: requested.NodeRunID,
		Payload: map[string]interface{}{
			"answers": []interface{}{
				map[string]interface{}{"selected": "A"},
			},
		},
	})
	resumed := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventNodeStarted && event.NodeRunID == requested.NodeRunID
	})
	require.NotNil(t, resumed.TaskView)
	assert.Equal(t, requested.TaskID, resumed.TaskID)
	assert.Equal(t, "draft_plan", resumed.NodeName)
	assert.Equal(t, taskdomain.TaskStatusRunning, resumed.TaskView.Status)
	waitForEvent(t, service.Events(), EventInputRequested)

	afterRuns, err := service.store.ListNodeRunsByTask(context.Background(), requested.TaskID)
	require.NoError(t, err)
	count := 0
	for _, run := range afterRuns {
		if run.NodeName == "draft_plan" {
			count++
			assert.Len(t, run.Clarifications, 1)
			artifactPaths := taskdomain.ArtifactPaths(run.Result)
			assert.Len(t, artifactPaths, 1)
			inputPath := mustRunArtifactPathForRun(t, task, afterRuns, run, inputArtifactName)
			assert.NotContains(t, artifactPaths, inputPath)
			input := readTestFile(t, inputPath)
			assert.True(t, strings.HasPrefix(input, expectedInputPrefix))
			assert.NotContains(t, input, "## Prompt")
			assert.Contains(t, input, "<task_metadata>")
			assert.Contains(t, input, "<clarification_state>")
			assert.Contains(t, input, "\"A\"")
		}
	}
	assert.Equal(t, 1, count)

	draftRequests = executor.requestsForNode("draft_plan")
	require.Len(t, draftRequests, 2)
	assert.Equal(t, appconfig.RuntimeCodex, draftRequests[0].Runtime)
	assert.Empty(t, draftRequests[0].NodeRun.SessionID)
	assert.Equal(t, appconfig.RuntimeCodex, draftRequests[1].Runtime)
	assert.Equal(t, draftRequests[0].NodeRun.ID+"-session", draftRequests[1].NodeRun.SessionID)
	require.Len(t, draftRequests[1].NodeRun.Clarifications, 1)
	require.NotNil(t, draftRequests[1].NodeRun.Clarifications[0].Response)
	assert.Contains(t, draftRequests[1].Prompt, "<task_metadata>")
	assert.Contains(t, draftRequests[1].Prompt, "<current_step>draft_plan</current_step>")
	assert.Contains(t, draftRequests[1].Prompt, "<current_iteration>1</current_iteration>")
	assert.Contains(t, draftRequests[1].Prompt, "Primary task for this step:\n<<< PRIMARY TASK >>>\nImplement login\n<<< END PRIMARY TASK >>>")
	assert.Contains(t, draftRequests[1].Prompt, "Question 1: Need a choice")
	assert.Contains(t, draftRequests[1].Prompt, "User selected:")
	assert.Contains(t, draftRequests[1].Prompt, "Stay in the same thread context")
}

func TestServicePersistsTaskConfigAlias(t *testing.T) {
	cfg, err := taskconfig.LoadDefault()
	require.NoError(t, err)
	configPath := writeOverrideConfig(t, cfg)
	service := newTestService(t, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan":  {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan.md")}},
			"review_plan": {{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review.md"}}}},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(RunCommand{
		Type:        CommandStartTask,
		Description: "Persist alias",
		ConfigAlias: "bugfix",
		ConfigPath:  configPath,
		WorkDir:     service.workDir,
	})
	inputEvent := waitForEvent(t, service.Events(), EventInputRequested)

	task, err := service.store.GetTask(context.Background(), inputEvent.TaskID)
	require.NoError(t, err)
	assert.Equal(t, "bugfix", task.ConfigAlias)
	assert.Equal(t, configPath, task.ConfigPath)
}

func TestServicePersistsExecutionDirAndExecutesFromWorktree(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	_, err := taskconfig.EnsureManagedDefaultAssets()
	require.NoError(t, err)

	cfg := singleAgentTerminalFixture()
	def := cfg.NodeDefinitions["implement"]
	def.SystemPrompt = "./prompts/implement.md"
	cfg.NodeDefinitions["implement"] = def
	writeConfigAtPath(t, cfg, managedDefaultTestConfigPath(t))
	overwritePromptWithBuiltinTemplate(t, managedDefaultTestConfigPath(t), "implement.md")

	repo := initRuntimeGitRepoWithCommit(t, true)
	workDir := filepath.Join(repo, "packages", "app")
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
	}
	service, err := NewService(workDir, executor)
	require.NoError(t, err)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(RunCommand{
		Type:        CommandStartTask,
		Description: "worktree task",
		ConfigAlias: taskconfig.DefaultAlias,
		ConfigPath:  managedDefaultTestConfigPath(t),
		WorkDir:     workDir,
		UseWorktree: true,
	})
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)

	task, err := service.store.GetTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	assert.Equal(t, workDir, task.WorkDir)
	assert.NotEqual(t, workDir, task.ExecutionDir)
	assert.Equal(t, task.ExecutionDir, task.ExecutionWorkDir())
	assert.FileExists(t, taskstore.DBPath(task.WorkDir))
	assert.FileExists(t, taskstore.ConfigPath(task.WorkDir, task.ID))
	assert.NoFileExists(t, taskstore.DBPath(task.ExecutionDir))

	worktreeRoot, err := worktree.FindRepoRoot(task.ExecutionDir)
	require.NoError(t, err)
	relPath, err := filepath.Rel(worktreeRoot, task.ExecutionDir)
	require.NoError(t, err)
	assert.Equal(t, filepath.Join("packages", "app"), relPath)

	requests := executor.requestsForNode("implement")
	require.Len(t, requests, 1)
	assert.Equal(t, task.ExecutionDir, requests[0].WorkDir)
	assert.Equal(t, task.WorkDir, requests[0].Task.WorkDir)
	assert.Equal(t, task.ExecutionDir, requests[0].Task.ExecutionDir)
	assert.Contains(t, requests[0].Prompt, "<execution_dir>"+task.ExecutionDir+"</execution_dir>")
	assert.Contains(t, requests[0].Prompt, "Unless the user explicitly says otherwise, do all project edits, builds, tests, and commands in `&lt;execution_dir&gt;`.")
	assert.NotContains(t, requests[0].Prompt, "<source_workdir>")
	assert.NotContains(t, requests[0].Prompt, "<execution_workspace>")
	assert.NotContains(t, requests[0].Prompt, "This task is running in a separate git worktree.")

	branchOut, err := exec.Command("git", "-C", repo, "branch", "--list", worktree.BranchName(task.ID)).CombinedOutput()
	require.NoError(t, err, string(branchOut))
	assert.Contains(t, strings.TrimSpace(string(branchOut)), worktree.BranchName(task.ID))
}

func TestServiceNormalizesExecutionDirForPlainTasksStartedFromSymlinkPath(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	_, err := taskconfig.EnsureManagedDefaultAssets()
	require.NoError(t, err)

	cfg := singleAgentTerminalFixture()
	writeConfigAtPath(t, cfg, managedDefaultTestConfigPath(t))

	repo := initRuntimeGitRepoWithCommit(t, true)
	realWorkDir := filepath.Join(repo, "packages", "app")
	symlinkRoot := filepath.Join(t.TempDir(), "workspace-link")
	require.NoError(t, os.Symlink(repo, symlinkRoot))
	symlinkWorkDir := filepath.Join(symlinkRoot, "packages", "app")

	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
	}
	service, err := NewService(realWorkDir, executor)
	require.NoError(t, err)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(RunCommand{
		Type:        CommandStartTask,
		Description: "plain task",
		ConfigAlias: taskconfig.DefaultAlias,
		ConfigPath:  managedDefaultTestConfigPath(t),
		WorkDir:     symlinkWorkDir,
	})
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)

	task, err := service.store.GetTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	assert.Equal(t, realWorkDir, task.WorkDir)
	assert.Equal(t, realWorkDir, task.ExecutionDir)
	assert.False(t, taskUsesWorktree(task))

	requests := executor.requestsForNode("implement")
	require.Len(t, requests, 1)
	assert.Equal(t, realWorkDir, requests[0].WorkDir)
}

func TestServiceWorktreeStartupRollsBackWhenRepoSubdirIsMissingInNewWorktree(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	_, err := taskconfig.EnsureManagedDefaultAssets()
	require.NoError(t, err)

	cfg := singleAgentTerminalFixture()
	writeConfigAtPath(t, cfg, managedDefaultTestConfigPath(t))

	repo := initRuntimeGitRepoWithCommit(t, false)
	workDir := filepath.Join(repo, "packages", "app")
	require.NoError(t, os.MkdirAll(workDir, 0o755))

	service, err := NewService(workDir, &fakeExecutor{})
	require.NoError(t, err)
	defer service.Close()
	service.rootCtx = context.Background()

	err = service.startTask(context.Background(), "missing subdir", taskconfig.DefaultAlias, managedDefaultTestConfigPath(t), workDir, true)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "saved worktree cwd unavailable")

	tasks, err := service.store.ListTasksByWorkDir(context.Background(), workDir)
	require.NoError(t, err)
	assert.Empty(t, tasks)

	worktreeList, err := exec.Command("git", "-C", repo, "worktree", "list", "--porcelain").CombinedOutput()
	require.NoError(t, err, string(worktreeList))
	assert.NotContains(t, string(worktreeList), filepath.Join(home, ".muxagent", "worktrees"))

	branchOut, err := exec.Command("git", "-C", repo, "branch", "--list", "muxagent/*").CombinedOutput()
	require.NoError(t, err, string(branchOut))
	assert.Empty(t, strings.TrimSpace(string(branchOut)))
}

func TestServiceStartFollowUpCreatesChildTaskAndPersistsLineage(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-impl.md")},
			},
		},
	}
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "parent task"))
	parentCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	service.Dispatch(startFollowUpCommand(parentCompleted.TaskID, "child task"))
	childCreated := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCreated && event.TaskID != parentCompleted.TaskID
	})
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID == childCreated.TaskID
	})

	parentTaskID, err := service.store.GetFollowUpParentTaskID(context.Background(), childCreated.TaskID)
	require.NoError(t, err)
	assert.Equal(t, parentCompleted.TaskID, parentTaskID)

	childTask, err := service.store.GetTask(context.Background(), childCreated.TaskID)
	require.NoError(t, err)
	parentTask, err := service.store.GetTask(context.Background(), parentCompleted.TaskID)
	require.NoError(t, err)
	assert.Equal(t, parentTask.ConfigAlias, childTask.ConfigAlias)
	assert.Equal(t, parentTask.ConfigPath, childTask.ConfigPath)
	assert.Equal(t, parentTask.WorkDir, childTask.WorkDir)
	assert.Equal(t, parentTask.ExecutionDir, childTask.ExecutionDir)
	require.NotNil(t, childCreated.TaskView)
	assert.Equal(t, parentCompleted.TaskID, childCreated.TaskView.ParentTaskID)
	assert.Equal(t, parentTask.Description, childCreated.TaskView.ParentTaskDescription)
	require.NotNil(t, childCompleted.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, childCompleted.TaskView.Status)
	assert.Equal(t, parentCompleted.TaskID, childCompleted.TaskView.ParentTaskID)
	assert.Equal(t, parentTask.Description, childCompleted.TaskView.ParentTaskDescription)

	childRuns, err := service.store.ListNodeRunsByTask(context.Background(), childCreated.TaskID)
	require.NoError(t, err)
	require.Len(t, childRuns, 2)
	assert.Equal(t, "implement", childRuns[0].NodeName)
}

func TestServiceSingleRunFollowUpUsesHandleRequestAndInheritedParentContext(t *testing.T) {
	t.Setenv("HOME", t.TempDir())

	configPath := managedDefaultTestConfigPath(t)
	writeConfigAtPath(t, singleHandleRequestFixture(), configPath)

	handleRequestPrompt := strings.Join([]string{
		"{{RUN_METADATA_XML}}",
		"",
		"Primary task for this step:",
		"<<< PRIMARY TASK >>>",
		"{{TASK_DESCRIPTION_BLOCK}}",
		"<<< END PRIMARY TASK >>>",
		"",
		"{{WORKFLOW_CONTEXT_XML}}",
		"",
		"{{CLARIFICATION_CONTEXT_XML}}",
	}, "\n")
	promptPath := filepath.Join(filepath.Dir(configPath), "prompts", "handle_request.md")
	require.NoError(t, os.WriteFile(promptPath, []byte(handleRequestPrompt), 0o644))

	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"handle_request": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-result.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-result.md")},
			},
		},
	}
	workDir := t.TempDir()
	service, err := NewService(workDir, executor)
	require.NoError(t, err)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(RunCommand{
		Type:        CommandStartTask,
		Description: "parent task",
		ConfigAlias: taskconfig.BuiltinIDSingleRun,
		ConfigPath:  configPath,
		WorkDir:     service.workDir,
	})
	parentCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	service.Dispatch(startFollowUpCommand(parentCompleted.TaskID, "child task"))
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentCompleted.TaskID
	})

	parentTask, err := service.store.GetTask(context.Background(), parentCompleted.TaskID)
	require.NoError(t, err)
	childTask, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	assert.Equal(t, parentTask.ConfigAlias, childTask.ConfigAlias)
	assert.Equal(t, parentTask.ConfigPath, childTask.ConfigPath)
	assert.Equal(t, taskconfig.BuiltinIDSingleRun, childTask.ConfigAlias)

	childRuns, err := service.store.ListNodeRunsByTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	require.Len(t, childRuns, 2)
	assert.Equal(t, "handle_request", childRuns[0].NodeName)

	handleRequests := executor.requestsForNode("handle_request")
	require.Len(t, handleRequests, 2)
	childPrompt := handleRequests[1].Prompt
	assert.Contains(t, childPrompt, "Follow-up lineage:")
	assert.Contains(t, childPrompt, "- Direct parent task: parent task")
	assert.Contains(t, childPrompt, taskstore.TaskDir(service.workDir, parentCompleted.TaskID))
	assert.Contains(t, childPrompt, filepath.Join(taskstore.TaskDir(service.workDir, parentCompleted.TaskID), "runs"))
}

func TestServiceStartFollowUpUsesExplicitConfigOverride(t *testing.T) {
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
			},
			"handle_request": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-result.md")},
			},
		},
	})
	defer service.Close()

	overridePath := writeOverrideConfig(t, singleHandleRequestFixture())

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "parent task"))
	parentCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	cmd := startFollowUpCommand(parentCompleted.TaskID, "child task")
	cmd.ConfigAlias = taskconfig.BuiltinIDSingleRun
	cmd.ConfigPath = overridePath
	service.Dispatch(cmd)
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentCompleted.TaskID
	})

	childTask, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	assert.Equal(t, taskconfig.BuiltinIDSingleRun, childTask.ConfigAlias)
	assert.Equal(t, overridePath, childTask.ConfigPath)

	childRuns, err := service.store.ListNodeRunsByTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	require.Len(t, childRuns, 2)
	assert.Equal(t, "handle_request", childRuns[0].NodeName)
}

func TestServiceStartFollowUpRejectsPartialConfigOverride(t *testing.T) {
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")}},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "parent task"))
	parentCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	tests := []struct {
		name    string
		command RunCommand
		wantErr string
	}{
		{
			name: "missing override path",
			command: RunCommand{
				Type:         CommandStartFollowUp,
				ParentTaskID: parentCompleted.TaskID,
				Description:  "child task",
				ConfigAlias:  taskconfig.BuiltinIDSingleRun,
			},
			wantErr: "provided together",
		},
		{
			name: "missing override alias",
			command: RunCommand{
				Type:         CommandStartFollowUp,
				ParentTaskID: parentCompleted.TaskID,
				Description:  "child task",
				ConfigPath:   "/tmp/single-run.yaml",
			},
			wantErr: "provided together",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := service.handleCommand(context.Background(), tt.command)
			require.Error(t, err)
			assert.Contains(t, err.Error(), tt.wantErr)
		})
	}
}

func TestServiceStartFollowUpUsesStoredConfigWhenAliasMissingFromCatalog(t *testing.T) {
	configPath := writeOverrideConfig(t, singleAgentTerminalFixture())
	service := newTestService(t, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-impl.md")},
			},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(RunCommand{
		Type:        CommandStartTask,
		Description: "parent task",
		ConfigAlias: "legacy-config",
		ConfigPath:  configPath,
		WorkDir:     service.workDir,
	})
	parentCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	service.Dispatch(startFollowUpCommand(parentCompleted.TaskID, "child task"))
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentCompleted.TaskID
	})

	childTask, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	assert.Equal(t, "legacy-config", childTask.ConfigAlias)
	assert.Equal(t, configPath, childTask.ConfigPath)

	childRuns, err := service.store.ListNodeRunsByTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	require.Len(t, childRuns, 2)
	assert.Equal(t, "implement", childRuns[0].NodeName)
}

func TestServiceStartFollowUpDefaultsToContinueHereForWorktreeParents(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	_, err := taskconfig.EnsureManagedDefaultAssets()
	require.NoError(t, err)

	cfg := singleAgentTerminalFixture()
	writeConfigAtPath(t, cfg, managedDefaultTestConfigPath(t))

	repo := initRuntimeGitRepoWithCommit(t, true)
	workDir := filepath.Join(repo, "packages", "app")
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-impl.md")},
			},
		},
	}
	service, err := NewService(workDir, executor)
	require.NoError(t, err)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	cmd := startTaskCommand(t, service, "parent worktree task")
	cmd.UseWorktree = true
	service.Dispatch(cmd)
	parentCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	service.Dispatch(startFollowUpCommand(parentCompleted.TaskID, "child worktree task"))
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentCompleted.TaskID
	})

	parentTask, err := service.store.GetTask(context.Background(), parentCompleted.TaskID)
	require.NoError(t, err)
	childTask, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	assert.NotEqual(t, parentTask.WorkDir, parentTask.ExecutionDir)
	assert.Equal(t, parentTask.ExecutionDir, childTask.ExecutionDir)
	assert.Equal(t, parentTask.WorkDir, childTask.WorkDir)

	repoRoot, err := worktree.FindRepoRoot(parentTask.WorkDir)
	require.NoError(t, err)
	assert.Len(t, gitWorktreeList(t, repoRoot), 2)
}

func TestServiceStartFollowUpDefaultsToContinueHereForRepoBackedMainCheckoutParents(t *testing.T) {
	parentTask := seedCompletedMainCheckoutParentTask(t)
	service := parentTask.service
	defer service.Close()

	service.Dispatch(startFollowUpCommand(parentTask.completed.TaskID, "child main-checkout task"))
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentTask.completed.TaskID
	})

	parent, err := service.store.GetTask(context.Background(), parentTask.completed.TaskID)
	require.NoError(t, err)
	child, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	assert.Equal(t, parent.WorkDir, child.WorkDir)
	assert.Equal(t, parent.ExecutionDir, child.ExecutionDir)

	repoRoot, err := worktree.FindRepoRoot(parent.WorkDir)
	require.NoError(t, err)
	assert.Len(t, gitWorktreeList(t, repoRoot), 1)
}

func TestServiceStartFollowUpContinueHereRejectsRunningSiblingInSameCheckout(t *testing.T) {
	parentTask := seedCompletedWorktreeParentTask(t)
	service := parentTask.service
	defer service.Close()

	seedLiveTaskInCheckout(t, service, parentTask.task, "sibling-running", taskdomain.NodeRunRunning)

	err := service.startFollowUpTask(
		context.Background(),
		parentTask.completed.TaskID,
		"blocked child",
		"",
		"",
		FollowUpModeContinueHere,
	)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "still active in this checkout")
}

func TestServiceStartFollowUpContinueHereRejectsRunningPlainSiblingInSameCheckout(t *testing.T) {
	parentTask := seedCompletedMainCheckoutParentTask(t)
	service := parentTask.service
	defer service.Close()

	seedLiveTaskInCheckout(t, service, parentTask.task, "plain-sibling-running", taskdomain.NodeRunRunning)

	err := service.startFollowUpTask(
		context.Background(),
		parentTask.completed.TaskID,
		"blocked child",
		"",
		"",
		FollowUpModeContinueHere,
	)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "still active in this checkout")
}

func TestServiceStartFollowUpContinueHereRejectsAwaitingSiblingInSameCheckout(t *testing.T) {
	parentTask := seedCompletedWorktreeParentTask(t)
	service := parentTask.service
	defer service.Close()

	seedLiveTaskInCheckout(t, service, parentTask.task, "sibling-awaiting", taskdomain.NodeRunAwaitingUser)

	err := service.startFollowUpTask(
		context.Background(),
		parentTask.completed.TaskID,
		"blocked child",
		"",
		"",
		FollowUpModeContinueHere,
	)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "still active in this checkout")
}

func TestServiceStartFollowUpContinueHereRejectsAwaitingPlainSiblingInSameCheckout(t *testing.T) {
	parentTask := seedCompletedMainCheckoutParentTask(t)
	service := parentTask.service
	defer service.Close()

	seedLiveTaskInCheckout(t, service, parentTask.task, "plain-sibling-awaiting", taskdomain.NodeRunAwaitingUser)

	err := service.startFollowUpTask(
		context.Background(),
		parentTask.completed.TaskID,
		"blocked child",
		"",
		"",
		FollowUpModeContinueHere,
	)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "still active in this checkout")
}

func TestServiceStartFollowUpForkHeadUsesParentHeadInsteadOfRepoHEAD(t *testing.T) {
	parentTask := seedCompletedWorktreeParentTask(t)
	service := parentTask.service
	defer service.Close()

	parentCheckoutRoot, err := worktree.FindRepoRoot(parentTask.task.ExecutionDir)
	require.NoError(t, err)
	parentHead, err := worktree.HeadCommit(parentCheckoutRoot)
	require.NoError(t, err)

	repoRoot, err := worktree.FindRepoRoot(parentTask.task.WorkDir)
	require.NoError(t, err)
	repoHead := advanceRuntimeRepoHead(t, repoRoot, "repo-head.txt", "repo head moved")
	require.NotEqual(t, parentHead, repoHead)

	service.Dispatch(startFollowUpCommandWithMode(
		parentTask.completed.TaskID,
		"fork from head",
		FollowUpModeForkHead,
	))
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentTask.completed.TaskID
	})

	childTask, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	childCheckoutRoot, err := worktree.FindRepoRoot(childTask.ExecutionDir)
	require.NoError(t, err)
	childHead, err := worktree.HeadCommit(childCheckoutRoot)
	require.NoError(t, err)

	assert.NotEqual(t, parentTask.task.ExecutionDir, childTask.ExecutionDir)
	assert.Equal(t, parentHead, childHead)
	assert.NotEqual(t, repoHead, childHead)
}

func TestServiceStartFollowUpForkHeadFromRepoBackedMainCheckoutIgnoresUncommittedChanges(t *testing.T) {
	parentTask := seedCompletedMainCheckoutParentTask(t)
	service := parentTask.service
	defer service.Close()

	repoRoot, err := worktree.FindRepoRoot(parentTask.task.WorkDir)
	require.NoError(t, err)
	parentHead, err := worktree.HeadCommit(repoRoot)
	require.NoError(t, err)

	mainTrackedFile := filepath.Join(parentTask.task.ExecutionDir, ".keep")
	mainDeletedFile := filepath.Join(parentTask.task.ExecutionDir, "delete-me.txt")
	mainUntrackedFile := filepath.Join(parentTask.task.ExecutionDir, "notes.md")
	require.NoError(t, os.WriteFile(mainTrackedFile, []byte("dirty main checkout change"), 0o644))
	require.NoError(t, os.Remove(mainDeletedFile))
	require.NoError(t, os.WriteFile(mainUntrackedFile, []byte("main checkout notes"), 0o644))

	service.Dispatch(startFollowUpCommandWithMode(
		parentTask.completed.TaskID,
		"fork head from main checkout",
		FollowUpModeForkHead,
	))
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentTask.completed.TaskID
	})

	childTask, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	childCheckoutRoot, err := worktree.FindRepoRoot(childTask.ExecutionDir)
	require.NoError(t, err)
	childHead, err := worktree.HeadCommit(childCheckoutRoot)
	require.NoError(t, err)

	assert.Equal(t, parentHead, childHead)
	assert.Equal(t, "keep", readTestFile(t, filepath.Join(childTask.ExecutionDir, ".keep")))
	assert.FileExists(t, filepath.Join(childTask.ExecutionDir, "delete-me.txt"))
	assert.NoFileExists(t, filepath.Join(childTask.ExecutionDir, "notes.md"))
}

func TestServiceStartFollowUpForkWithChangesUsesParentHeadAndSnapshotsCheckout(t *testing.T) {
	if goruntime.GOOS == "windows" {
		t.Skip("symlink behavior is not portable on windows")
	}

	parentTask := seedCompletedWorktreeParentTask(t)
	service := parentTask.service
	defer service.Close()

	parentCheckoutRoot, err := worktree.FindRepoRoot(parentTask.task.ExecutionDir)
	require.NoError(t, err)
	parentHead, err := worktree.HeadCommit(parentCheckoutRoot)
	require.NoError(t, err)

	repoRoot, err := worktree.FindRepoRoot(parentTask.task.WorkDir)
	require.NoError(t, err)
	repoHead := advanceRuntimeRepoHead(t, repoRoot, "repo-head-2.txt", "repo head moved again")
	require.NotEqual(t, parentHead, repoHead)

	parentTrackedFile := filepath.Join(parentTask.task.ExecutionDir, ".keep")
	parentDeletedFile := filepath.Join(parentCheckoutRoot, "README.md")
	parentUntrackedFile := filepath.Join(parentCheckoutRoot, "notes.md")
	parentSymlink := filepath.Join(parentCheckoutRoot, "notes-link")
	parentExecutable := filepath.Join(parentCheckoutRoot, "run.sh")
	require.NoError(t, os.WriteFile(parentTrackedFile, []byte("parent dirty change"), 0o644))
	require.NoError(t, os.Remove(parentDeletedFile))
	require.NoError(t, os.WriteFile(parentUntrackedFile, []byte("snapshot notes"), 0o644))
	require.NoError(t, os.Symlink("notes.md", parentSymlink))
	require.NoError(t, os.WriteFile(parentExecutable, []byte("#!/bin/sh\necho snapshot\n"), 0o755))

	service.Dispatch(startFollowUpCommandWithMode(
		parentTask.completed.TaskID,
		"fork with changes",
		FollowUpModeForkWithChanges,
	))
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentTask.completed.TaskID
	})

	childTask, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	childCheckoutRoot, err := worktree.FindRepoRoot(childTask.ExecutionDir)
	require.NoError(t, err)
	childHead, err := worktree.HeadCommit(childCheckoutRoot)
	require.NoError(t, err)

	assert.Equal(t, parentHead, childHead)
	assert.NotEqual(t, repoHead, childHead)
	assert.Equal(t, "parent dirty change", readTestFile(t, filepath.Join(childTask.ExecutionDir, ".keep")))
	assert.NoFileExists(t, filepath.Join(childCheckoutRoot, "README.md"))
	assert.Equal(t, "snapshot notes", readTestFile(t, filepath.Join(childCheckoutRoot, "notes.md")))

	linkInfo, err := os.Lstat(filepath.Join(childCheckoutRoot, "notes-link"))
	require.NoError(t, err)
	assert.True(t, linkInfo.Mode()&os.ModeSymlink != 0)
	linkTarget, err := os.Readlink(filepath.Join(childCheckoutRoot, "notes-link"))
	require.NoError(t, err)
	assert.Equal(t, "notes.md", linkTarget)

	execInfo, err := os.Stat(filepath.Join(childCheckoutRoot, "run.sh"))
	require.NoError(t, err)
	assert.True(t, execInfo.Mode().Perm()&0o111 != 0)
}

func TestServiceStartFollowUpForkWithChangesFromRepoBackedMainCheckoutSkipsRuntimeState(t *testing.T) {
	parentTask := seedCompletedMainCheckoutParentTask(t)
	service := parentTask.service
	defer service.Close()

	repoRoot, err := worktree.FindRepoRoot(parentTask.task.WorkDir)
	require.NoError(t, err)
	parentHead, err := worktree.HeadCommit(repoRoot)
	require.NoError(t, err)

	mainTrackedFile := filepath.Join(parentTask.task.ExecutionDir, ".keep")
	mainDeletedFile := filepath.Join(parentTask.task.ExecutionDir, "delete-me.txt")
	mainUntrackedFile := filepath.Join(parentTask.task.ExecutionDir, "notes.md")
	require.NoError(t, os.WriteFile(mainTrackedFile, []byte("dirty main checkout change"), 0o644))
	require.NoError(t, os.Remove(mainDeletedFile))
	require.NoError(t, os.WriteFile(mainUntrackedFile, []byte("main checkout notes"), 0o644))
	require.NoError(t, os.WriteFile(taskstore.DBPath(parentTask.task.WorkDir), []byte("runtime"), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(taskstore.TaskDir(parentTask.task.WorkDir, parentTask.task.ID), "marker.txt"), []byte("parent task state"), 0o644))

	service.Dispatch(startFollowUpCommandWithMode(
		parentTask.completed.TaskID,
		"fork with changes from main checkout",
		FollowUpModeForkWithChanges,
	))
	childCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID != parentTask.completed.TaskID
	})

	childTask, err := service.store.GetTask(context.Background(), childCompleted.TaskID)
	require.NoError(t, err)
	childCheckoutRoot, err := worktree.FindRepoRoot(childTask.ExecutionDir)
	require.NoError(t, err)
	childHead, err := worktree.HeadCommit(childCheckoutRoot)
	require.NoError(t, err)

	assert.Equal(t, parentHead, childHead)
	assert.Equal(t, "dirty main checkout change", readTestFile(t, filepath.Join(childTask.ExecutionDir, ".keep")))
	assert.NoFileExists(t, filepath.Join(childTask.ExecutionDir, "delete-me.txt"))
	assert.Equal(t, "main checkout notes", readTestFile(t, filepath.Join(childTask.ExecutionDir, "notes.md")))
	assert.NoFileExists(t, taskstore.DBPath(childTask.ExecutionDir))
	assert.NoFileExists(t, filepath.Join(taskstore.TaskDir(childTask.ExecutionDir, parentTask.task.ID), "marker.txt"))
}

func TestServiceStartFollowUpFailsWhenParentWorktreeIsMissing(t *testing.T) {
	parentTask := seedCompletedWorktreeParentTask(t)
	service := parentTask.service
	defer service.Close()

	parentCheckoutRoot, err := worktree.FindRepoRoot(parentTask.task.ExecutionDir)
	require.NoError(t, err)
	require.NoError(t, os.RemoveAll(parentCheckoutRoot))

	err = service.startFollowUpTask(
		context.Background(),
		parentTask.completed.TaskID,
		"missing parent worktree",
		"",
		"",
		FollowUpModeForkHead,
	)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "follow-up parent worktree unavailable")
}

func TestServiceStartFollowUpFailsWhenParentWorktreeAndWorkspaceRepoMetadataAreMissing(t *testing.T) {
	parentTask := seedCompletedWorktreeParentTask(t)
	service := parentTask.service
	defer service.Close()

	parentCheckoutRoot, err := worktree.FindRepoRoot(parentTask.task.ExecutionDir)
	require.NoError(t, err)
	require.NoError(t, os.RemoveAll(parentCheckoutRoot))
	require.NoError(t, os.RemoveAll(filepath.Join(parentTask.task.WorkDir, ".git")))

	err = service.startFollowUpTask(
		context.Background(),
		parentTask.completed.TaskID,
		"missing parent worktree and repo metadata",
		"",
		"",
		"",
	)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "follow-up parent worktree unavailable")
}

func TestServiceStartFollowUpRejectsIncompleteParent(t *testing.T) {
	service := newTestService(t, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan":  {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan.md")}},
			"review_plan": {{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review.md"}}}},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "parent not done"))
	inputRequested := waitForEvent(t, service.Events(), EventInputRequested)

	service.Dispatch(startFollowUpCommand(inputRequested.TaskID, "child should fail"))
	commandErr := waitForEvent(t, service.Events(), EventCommandError)
	require.NotNil(t, commandErr.Error)
	assert.Contains(t, commandErr.Error.Message, "not completed")
}

func TestServiceFollowUpPromptAndInputRequestIncludeParentContext(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-plan.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-plan.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/parent-review.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/child-review.md"}}},
			},
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
			},
			"verify": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/parent-verify.md"}}},
			},
		},
	}
	service := newTestService(t, executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "parent task"))
	parentApproval := waitForEvent(t, service.Events(), EventInputRequested)
	service.Dispatch(RunCommand{
		Type:      CommandSubmitInput,
		TaskID:    parentApproval.TaskID,
		NodeRunID: parentApproval.NodeRunID,
		Payload:   map[string]interface{}{"approved": true},
	})
	parentCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	service.Dispatch(startFollowUpCommand(parentCompleted.TaskID, "child task"))
	childApproval := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventInputRequested && event.TaskID != parentCompleted.TaskID
	})
	require.NotNil(t, childApproval.InputRequest)
	inputArtifacts := strings.Join(childApproval.InputRequest.ArtifactPaths, "\n")
	assert.Contains(t, inputArtifacts, "parent-review.md")
	assert.Contains(t, inputArtifacts, "parent-verify.md")

	draftRequests := executor.requestsForNode("draft_plan")
	require.Len(t, draftRequests, 2)
	childPrompt := draftRequests[1].Prompt
	assert.Contains(t, childPrompt, "Follow-up lineage:")
	assert.Contains(t, childPrompt, "Direct parent task: parent task")
	assert.Contains(t, childPrompt, taskstore.TaskDir(service.workDir, parentCompleted.TaskID))
	assert.NotContains(t, childPrompt, "parent-plan.md")

	reloadedInput, err := service.BuildInputRequest(context.Background(), childApproval.TaskID, childApproval.NodeRunID)
	require.NoError(t, err)
	reloadedArtifacts := strings.Join(reloadedInput.ArtifactPaths, "\n")
	assert.Contains(t, reloadedArtifacts, "parent-review.md")
	assert.Contains(t, reloadedArtifacts, "parent-verify.md")
}

func TestLoadInheritedContextIncludesAllParentRunsAndAncestors(t *testing.T) {
	service := newTestService(t, &fakeExecutor{})
	defer service.Close()

	ctx := context.Background()
	now := time.Now().UTC()
	tasks := []taskdomain.Task{
		{ID: "ancestor-1", Description: "ancestor task 1", WorkDir: service.workDir, CreatedAt: now, UpdatedAt: now},
		{ID: "ancestor-2", Description: "ancestor task 2", WorkDir: service.workDir, CreatedAt: now.Add(time.Second), UpdatedAt: now.Add(time.Second)},
		{ID: "ancestor-3", Description: "ancestor task 3", WorkDir: service.workDir, CreatedAt: now.Add(2 * time.Second), UpdatedAt: now.Add(2 * time.Second)},
		{ID: "ancestor-4", Description: "ancestor task 4", WorkDir: service.workDir, CreatedAt: now.Add(3 * time.Second), UpdatedAt: now.Add(3 * time.Second)},
		{ID: "ancestor-5", Description: "ancestor task 5", WorkDir: service.workDir, CreatedAt: now.Add(4 * time.Second), UpdatedAt: now.Add(4 * time.Second)},
		{ID: "ancestor-6", Description: "ancestor task 6", WorkDir: service.workDir, CreatedAt: now.Add(5 * time.Second), UpdatedAt: now.Add(5 * time.Second)},
		{ID: "parent", Description: "parent task", WorkDir: service.workDir, CreatedAt: now.Add(6 * time.Second), UpdatedAt: now.Add(6 * time.Second)},
		{ID: "child", Description: "child task", WorkDir: service.workDir, CreatedAt: now.Add(7 * time.Second), UpdatedAt: now.Add(7 * time.Second)},
	}
	for _, task := range tasks {
		require.NoError(t, service.store.CreateTask(ctx, task))
	}
	for i := 0; i < len(tasks)-1; i++ {
		require.NoError(t, service.store.AttachFollowUpParent(ctx, tasks[i].ID, tasks[i+1].ID, now.Add(time.Duration(i)*time.Minute)))
	}

	parentTask := tasks[len(tasks)-2]
	childTask := tasks[len(tasks)-1]
	for i := 1; i <= 10; i++ {
		startedAt := now.Add(time.Duration(i) * time.Hour)
		completedAt := startedAt.Add(time.Minute)
		require.NoError(t, service.store.SaveNodeRun(ctx, taskdomain.NodeRun{
			ID:          fmt.Sprintf("parent-run-%02d", i),
			TaskID:      parentTask.ID,
			NodeName:    fmt.Sprintf("step_%02d", i),
			Status:      taskdomain.NodeRunDone,
			Result:      map[string]interface{}{"file_paths": []interface{}{fmt.Sprintf("/tmp/parent-run-%02d.md", i)}},
			StartedAt:   startedAt,
			CompletedAt: &completedAt,
		}))
	}

	inherited, err := service.loadInheritedContext(ctx, childTask)
	require.NoError(t, err)
	require.NotNil(t, inherited)

	require.NotNil(t, inherited.DirectParent)
	assert.Equal(t, "parent task", inherited.DirectParent.Description)
	assert.Equal(t, taskstore.TaskDir(service.workDir, parentTask.ID), inherited.DirectParent.TaskDir)
	assert.Len(t, inherited.EarlierAncestors, 6)
	actualAncestors := make([]string, 0, len(inherited.EarlierAncestors))
	for _, ancestor := range inherited.EarlierAncestors {
		actualAncestors = append(actualAncestors, ancestor.Description+"|"+ancestor.TaskDir)
	}
	expectedAncestors := make([]string, 0, 6)
	for i := 1; i <= 6; i++ {
		expectedAncestors = append(expectedAncestors, fmt.Sprintf("ancestor task %d|%s", i, taskstore.TaskDir(service.workDir, fmt.Sprintf("ancestor-%d", i))))
	}
	assert.ElementsMatch(t, expectedAncestors, actualAncestors)
}

func TestLoadInheritedInputArtifactsIncludesAllExistingParentArtifacts(t *testing.T) {
	service := newTestService(t, &fakeExecutor{})
	defer service.Close()

	ctx := context.Background()
	now := time.Now().UTC()
	parentTask := taskdomain.Task{
		ID:          "parent-artifacts",
		Description: "parent task",
		WorkDir:     service.workDir,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	childTask := taskdomain.Task{
		ID:          "child-artifacts",
		Description: "child task",
		WorkDir:     service.workDir,
		CreatedAt:   now.Add(time.Second),
		UpdatedAt:   now.Add(time.Second),
	}
	require.NoError(t, service.store.CreateTask(ctx, parentTask))
	require.NoError(t, service.store.CreateTask(ctx, childTask))
	require.NoError(t, service.store.AttachFollowUpParent(ctx, parentTask.ID, childTask.ID, now.Add(2*time.Second)))

	artifactDir := t.TempDir()
	for i := 1; i <= 14; i++ {
		startedAt := now.Add(time.Duration(i) * time.Minute)
		completedAt := startedAt.Add(time.Second)
		artifactPath := filepath.Join(artifactDir, fmt.Sprintf("artifact-%02d.md", i))
		require.NoError(t, os.WriteFile(artifactPath, []byte(fmt.Sprintf("artifact %02d", i)), 0o644))
		require.NoError(t, service.store.SaveNodeRun(ctx, taskdomain.NodeRun{
			ID:          fmt.Sprintf("artifact-run-%02d", i),
			TaskID:      parentTask.ID,
			NodeName:    fmt.Sprintf("step_%02d", i),
			Status:      taskdomain.NodeRunDone,
			Result:      map[string]interface{}{"file_paths": []interface{}{artifactPath}},
			StartedAt:   startedAt,
			CompletedAt: &completedAt,
		}))
	}

	artifacts, err := service.loadInheritedInputArtifacts(ctx, childTask)
	require.NoError(t, err)
	require.Len(t, artifacts, 14)
	for i := 1; i <= 14; i++ {
		assert.Contains(t, strings.Join(artifacts, "\n"), fmt.Sprintf("artifact-%02d.md", i))
	}
}

func TestServiceRetryAfterRestartForFollowUpPreservesParentContext(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	_, err := taskconfig.EnsureManagedDefaultAssets()
	require.NoError(t, err)

	workDir := t.TempDir()
	firstExecutor := &queuedExecutor{
		outcomes: map[string][]executorOutcome{
			"draft_plan": {
				{result: taskexecutor.Result{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-plan.md")}},
				{err: fmt.Errorf("child draft failed")},
			},
			"review_plan": {
				{result: taskexecutor.Result{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/parent-review.md"}}}},
				{result: taskexecutor.Result{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/child-review.md"}}}},
			},
			"implement": {
				{result: taskexecutor.Result{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")}},
			},
			"verify": {
				{result: taskexecutor.Result{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/parent-verify.md"}}}},
			},
		},
	}
	firstService, err := NewService(workDir, firstExecutor)
	require.NoError(t, err)

	ctx, cancel := context.WithCancel(context.Background())
	go func() { _ = firstService.Run(ctx) }()

	firstService.Dispatch(startTaskCommand(t, firstService, "parent task"))
	parentApproval := waitForEvent(t, firstService.Events(), EventInputRequested)
	firstService.Dispatch(RunCommand{
		Type:      CommandSubmitInput,
		TaskID:    parentApproval.TaskID,
		NodeRunID: parentApproval.NodeRunID,
		Payload:   map[string]interface{}{"approved": true},
	})
	parentCompleted := waitForEvent(t, firstService.Events(), EventTaskCompleted)

	firstService.Dispatch(startFollowUpCommand(parentCompleted.TaskID, "child task"))
	childFailed := waitForEventWhere(t, firstService.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskFailed && event.TaskID != parentCompleted.TaskID
	})
	childTaskID := childFailed.TaskID
	failedRunID := childFailed.NodeRunID
	cancel()
	require.NoError(t, firstService.Close())

	secondService, err := NewService(workDir, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-plan.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/child-review.md"}}},
			},
		},
	})
	require.NoError(t, err)
	defer secondService.Close()

	require.NoError(t, secondService.retryNode(context.Background(), childTaskID, failedRunID, false))
	waitForEventWhere(t, secondService.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventInputRequested && event.TaskID == childTaskID
	})

	retryRequests := secondService.executor.(*fakeExecutor).requestsForNode("draft_plan")
	require.Len(t, retryRequests, 1)
	assert.Contains(t, retryRequests[0].Prompt, "Follow-up lineage:")
	assert.Contains(t, retryRequests[0].Prompt, "Direct parent task: parent task")
	assert.Contains(t, retryRequests[0].Prompt, taskstore.TaskDir(workDir, parentCompleted.TaskID))
	assert.NotContains(t, retryRequests[0].Prompt, "parent-plan.md")
}

func TestServiceFollowUpPromptUsesOlderAncestorsAsTaskDirectoryReferences(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("grand-plan.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-plan.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-plan.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/grand-review.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/parent-review.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/child-review.md"}}},
			},
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("grand-impl.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
			},
			"verify": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/grand-verify.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/parent-verify.md"}}},
			},
		},
	}
	service := newTestService(t, executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "grandparent task"))
	grandApproval := waitForEvent(t, service.Events(), EventInputRequested)
	service.Dispatch(RunCommand{
		Type:      CommandSubmitInput,
		TaskID:    grandApproval.TaskID,
		NodeRunID: grandApproval.NodeRunID,
		Payload:   map[string]interface{}{"approved": true},
	})
	grandCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	service.Dispatch(startFollowUpCommand(grandCompleted.TaskID, "parent task"))
	parentApproval := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventInputRequested && event.TaskID != grandCompleted.TaskID
	})
	service.Dispatch(RunCommand{
		Type:      CommandSubmitInput,
		TaskID:    parentApproval.TaskID,
		NodeRunID: parentApproval.NodeRunID,
		Payload:   map[string]interface{}{"approved": true},
	})
	parentCompleted := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID == parentApproval.TaskID
	})

	service.Dispatch(startFollowUpCommand(parentCompleted.TaskID, "child task"))
	waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventInputRequested && event.TaskID != grandCompleted.TaskID && event.TaskID != parentCompleted.TaskID
	})

	draftRequests := executor.requestsForNode("draft_plan")
	require.Len(t, draftRequests, 3)
	childPrompt := draftRequests[2].Prompt
	assert.Contains(t, childPrompt, "Follow-up lineage:")
	assert.Contains(t, childPrompt, "Direct parent task: parent task")
	assert.Contains(t, childPrompt, taskstore.TaskDir(service.workDir, parentCompleted.TaskID))
	assert.Contains(t, childPrompt, "Earlier ancestors are available only if the direct parent is not enough:")
	assert.Contains(t, childPrompt, "grandparent task")
	assert.Contains(t, childPrompt, taskstore.TaskDir(service.workDir, grandCompleted.TaskID))
	assert.NotContains(t, childPrompt, "grand-review.md")
	assert.NotContains(t, childPrompt, "grand-verify.md")
}

func TestServiceFollowUpPostCommitStartupFailureMarksEntryRunFailed(t *testing.T) {
	workDir := t.TempDir()
	configPath := writeOverrideConfig(t, singleAgentTerminalFixture())

	service, err := NewService(workDir, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
			},
		},
	})
	require.NoError(t, err)
	defer service.Close()
	service.beforeStartNode = func(task taskdomain.Task, run taskdomain.NodeRun) error {
		if task.Description == "broken child" {
			return fmt.Errorf("forced startup failure")
		}
		return nil
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(RunCommand{
		Type:        CommandStartTask,
		Description: "parent task",
		ConfigAlias: taskconfig.DefaultAlias,
		ConfigPath:  configPath,
		WorkDir:     workDir,
	})
	parentCompleted := waitForEvent(t, service.Events(), EventTaskCompleted)

	err = service.startFollowUpTask(context.Background(), parentCompleted.TaskID, "broken child", "", "", "")
	require.Error(t, err)
	views, err := service.ListTaskViews(context.Background(), workDir)
	require.NoError(t, err)
	require.Len(t, views, 2)
	var childTaskID string
	for _, view := range views {
		if view.Task.ID != parentCompleted.TaskID {
			childTaskID = view.Task.ID
			break
		}
	}
	require.NotEmpty(t, childTaskID)
	childFailed := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskFailed && event.TaskID == childTaskID
	})

	runs, err := service.store.ListNodeRunsByTask(context.Background(), childTaskID)
	require.NoError(t, err)
	require.Len(t, runs, 1)
	assert.Equal(t, taskdomain.NodeRunFailed, runs[0].Status)
	assert.Equal(t, childFailed.NodeRunID, runs[0].ID)
}

func TestServiceStartTaskRequiresExplicitConfigIdentity(t *testing.T) {
	service := newTestService(t, &fakeExecutor{})
	defer service.Close()

	tests := []struct {
		name    string
		command RunCommand
		wantErr string
	}{
		{
			name: "missing alias",
			command: RunCommand{
				Type:        CommandStartTask,
				Description: "Missing alias",
				ConfigPath:  managedDefaultTestConfigPath(t),
				WorkDir:     service.workDir,
			},
			wantErr: "task config alias is required",
		},
		{
			name: "missing path",
			command: RunCommand{
				Type:        CommandStartTask,
				Description: "Missing path",
				ConfigAlias: taskconfig.DefaultAlias,
				WorkDir:     service.workDir,
			},
			wantErr: "task config path is required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := service.handleCommand(context.Background(), tt.command)
			require.Error(t, err)
			assert.Contains(t, err.Error(), tt.wantErr)
		})
	}
}

func TestServiceReviewRejectLoopsBackToDraftPlan(t *testing.T) {
	service := newTestService(t, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-2.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": false, "file_paths": []interface{}{"/tmp/review-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-2.md"}}},
			},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "Implement login"))
	inputRequested := waitForEvent(t, service.Events(), EventInputRequested)
	assert.Equal(t, "approve_plan", inputRequested.NodeName)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), inputRequested.TaskID)
	require.NoError(t, err)
	draftCount := 0
	reviewCount := 0
	for _, run := range runs {
		switch run.NodeName {
		case "draft_plan":
			draftCount++
		case "review_plan":
			reviewCount++
		}
	}
	assert.Equal(t, 2, draftCount)
	assert.Equal(t, 2, reviewCount)
}

func TestServiceYoloVerifyFailureLoopsBackToImplement(t *testing.T) {
	service := newTestServiceWithConfig(t, yoloRuntimeFixture(), &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-1.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-1.md"}}},
			},
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl-2.md")},
			},
			"verify": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": false, "summary": "missing test coverage", "file_paths": []interface{}{"/tmp/verify-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "summary": "wave complete", "file_paths": []interface{}{"/tmp/verify-2.md"}}},
			},
			"evaluate_progress": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"next_node": "done", "reason": "task complete", "next_focus": "", "file_paths": []interface{}{"/tmp/eval-1.md"}}},
			},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "yolo verify retry"))
	completed := waitForTaskSuccess(t, service.Events())
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	assertNodeRunCounts(t, runs, map[string]int{
		"draft_plan":        1,
		"review_plan":       1,
		"implement":         2,
		"verify":            2,
		"evaluate_progress": 1,
		"done":              1,
	})
	assert.Equal(t, []string{
		"draft_plan",
		"review_plan",
		"implement",
		"verify",
		"implement",
		"verify",
		"evaluate_progress",
		"done",
	}, nodeRunNames(runs))
}

func TestServiceYoloEvaluateProgressStartsNextPlanningWave(t *testing.T) {
	service := newTestServiceWithConfig(t, yoloRuntimeFixture(), &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-2.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-2.md"}}},
			},
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl-2.md")},
			},
			"verify": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "summary": "wave one complete", "file_paths": []interface{}{"/tmp/verify-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "summary": "wave two complete", "file_paths": []interface{}{"/tmp/verify-2.md"}}},
			},
			"evaluate_progress": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"next_node": "draft_plan", "reason": "remaining daemon integration work", "next_focus": "plan the daemon integration wave", "file_paths": []interface{}{"/tmp/eval-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"next_node": "done", "reason": "task complete", "next_focus": "", "file_paths": []interface{}{"/tmp/eval-2.md"}}},
			},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "yolo multi-wave"))
	completed := waitForTaskSuccess(t, service.Events())
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	assertNodeRunCounts(t, runs, map[string]int{
		"draft_plan":        2,
		"review_plan":       2,
		"implement":         2,
		"verify":            2,
		"evaluate_progress": 2,
		"done":              1,
	})
	assert.Equal(t, []string{
		"draft_plan",
		"review_plan",
		"implement",
		"verify",
		"evaluate_progress",
		"draft_plan",
		"review_plan",
		"implement",
		"verify",
		"evaluate_progress",
		"done",
	}, nodeRunNames(runs))
}

func TestServiceHumanNodeSubmissionCreatesAuditArtifactAndFeedsNextPrompt(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-2.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-2.md"}}},
			},
		},
	}
	service := newTestService(t, executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "reject once"))
	firstApproval := waitForEvent(t, service.Events(), EventInputRequested)
	require.Equal(t, InputKindHumanNode, firstApproval.InputRequest.Kind)

	service.Dispatch(RunCommand{
		Type:             CommandSubmitInput,
		TaskID:           firstApproval.TaskID,
		NodeRunID:        firstApproval.NodeRunID,
		ImageAttachments: []ImageAttachmentInput{testImageAttachmentInput(t, "approval.png")},
		Payload: map[string]interface{}{
			"approved": false,
			"feedback": "Need more detail",
		},
	})
	secondApproval := waitForEvent(t, service.Events(), EventInputRequested)
	require.Equal(t, "approve_plan", secondApproval.NodeName)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), firstApproval.TaskID)
	require.NoError(t, err)

	var approvalRun taskdomain.NodeRun
	for _, run := range runs {
		if run.ID == firstApproval.NodeRunID {
			approvalRun = run
			break
		}
	}
	require.Equal(t, taskdomain.NodeRunDone, approvalRun.Status)
	artifactPaths := taskdomain.ArtifactPaths(approvalRun.Result)
	require.Empty(t, artifactPaths)
	task, err := service.store.GetTask(context.Background(), firstApproval.TaskID)
	require.NoError(t, err)
	outputPath := mustRunArtifactPathForRun(t, task, runs, approvalRun, outputArtifactName)
	inputPath := mustRunArtifactPathForRun(t, task, runs, approvalRun, inputArtifactName)
	assert.FileExists(t, outputPath)
	assert.FileExists(t, inputPath)
	assert.Equal(t, false, approvalRun.Result["approved"])
	assert.Equal(t, "Need more detail", approvalRun.Result["feedback"])

	data, err := os.ReadFile(outputPath)
	require.NoError(t, err)
	var envelope map[string]interface{}
	require.NoError(t, json.Unmarshal(data, &envelope))
	assert.Equal(t, "human_node_result", envelope["kind"])
	assert.Equal(t, "approve_plan", envelope["node_name"])
	result, ok := envelope["result"].(map[string]interface{})
	require.True(t, ok)
	assert.Equal(t, false, result["approved"])
	assert.Equal(t, "Need more detail", result["feedback"])
	assert.NotContains(t, string(data), "image_attachments")
	assert.NotContains(t, string(data), "approval.png")
	input := readTestFile(t, inputPath)
	assert.Contains(t, input, "Submitted:")
	assert.Contains(t, input, "\"approved\": false")
	assert.Contains(t, input, "\"feedback\": \"Need more detail\"")
	assert.Contains(t, input, "## Image Attachments")
	assert.Contains(t, input, "approval.png")
	images, err := readImageAttachmentManifest(task, runs, approvalRun)
	require.NoError(t, err)
	require.Len(t, images, 1)
	assert.Equal(t, "approval.png", images[0].OriginalFilename)
	assert.FileExists(t, images[0].AbsolutePath)

	draftPrompts := executor.requestsForNode("draft_plan")
	require.Len(t, draftPrompts, 2)
	require.Len(t, draftPrompts[1].ImagePaths, 1)
	assert.Equal(t, images[0].AbsolutePath, draftPrompts[1].ImagePaths[0])
	assert.Contains(t, draftPrompts[1].Prompt, images[0].AbsolutePath)
	assert.NotContains(t, draftPrompts[1].Prompt, outputPath)
	assert.NotContains(t, draftPrompts[1].Prompt, inputPath)

	view, _, err := service.LoadTaskView(context.Background(), firstApproval.TaskID)
	require.NoError(t, err)
	assert.NotContains(t, view.ArtifactPaths, outputPath)
	assert.NotContains(t, view.ArtifactPaths, inputPath)
}

func TestServicePublishesProgressAndPersistsSessionIDBeforeCompletion(t *testing.T) {
	blockRelease := make(chan struct{})
	blockStarted := make(chan struct{}, 1)
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), &blockingExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
		progressByNode: map[string][]taskexecutor.Progress{
			"implement": {
				{SessionID: "thread-123"},
				{Message: "planning changes"},
				{Message: "editing files"},
				{Message: "running tests"},
				{Message: "writing artifact"},
				{Message: "wrapping up"},
			},
		},
		blockNode:    "implement",
		blockRelease: blockRelease,
		blockStarted: blockStarted,
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "stream progress"))
	<-blockStarted

	progressEvent := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventNodeProgress &&
			event.NodeName == "implement" &&
			event.Progress != nil &&
			event.Progress.SessionID == "thread-123"
	})
	runs, err := service.store.ListNodeRunsByTask(context.Background(), progressEvent.TaskID)
	require.NoError(t, err)
	require.Len(t, runs, 1)
	assert.Equal(t, taskdomain.NodeRunRunning, runs[0].Status)
	assert.Equal(t, "thread-123", runs[0].SessionID)

	close(blockRelease)
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)
}

func TestServicePersistsNormalizedRunHistory(t *testing.T) {
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
		progress: map[string][]taskexecutor.Progress{
			"implement": {
				{
					SessionID: "session-456",
					Events: []taskexecutor.StreamEvent{
						{
							Kind: taskexecutor.StreamEventKindTool,
							Tool: &taskexecutor.ToolCall{
								CallID:       "tool-1",
								Name:         "Read",
								Kind:         taskexecutor.ToolKindRead,
								Status:       taskexecutor.ToolStatusCompleted,
								InputSummary: "plan.md",
							},
						},
					},
				},
				{Message: "wrapping up"},
			},
		},
	}
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), executor)
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "persist history"))
	completed := waitForTaskSuccess(t, service.Events())
	require.NotNil(t, completed.TaskView)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	var implementRun taskdomain.NodeRun
	for _, run := range runs {
		if run.NodeName == "implement" {
			implementRun = run
			break
		}
	}
	require.NotEmpty(t, implementRun.ID)

	history, err := taskhistory.ReadAll(service.workDir, completed.TaskID, implementRun.ID)
	require.NoError(t, err)
	require.Len(t, history, 1)
	assert.Equal(t, "session-456", history[0].SessionID)
	assert.Equal(t, "tool", history[0].Kind)
	require.NotNil(t, history[0].Tool)
	assert.Equal(t, "Read", history[0].Tool.Name)
}

func TestServiceRejectsCrossTaskNodeRunInput(t *testing.T) {
	service := newTestService(t, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-2.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-2.md"}}},
			},
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl-2.md")},
			},
			"verify": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/verify-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/verify-2.md"}}},
			},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "task one"))
	first := waitForEvent(t, service.Events(), EventInputRequested)
	service.Dispatch(startTaskCommand(t, service, "task two"))
	second := waitForEvent(t, service.Events(), EventInputRequested)

	_, err := service.BuildInputRequest(context.Background(), first.TaskID, second.NodeRunID)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")

	err = service.submitInput(context.Background(), first.TaskID, second.NodeRunID, map[string]interface{}{"approved": true})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "does not belong")

	run, err := service.store.GetNodeRun(context.Background(), second.NodeRunID)
	require.NoError(t, err)
	assert.Equal(t, taskdomain.NodeRunAwaitingUser, run.Status)
}

func TestServiceStartsSecondTaskWhileFirstAgentRunIsStillExecuting(t *testing.T) {
	blockRelease := make(chan struct{})
	blockStarted := make(chan struct{}, 2)
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), &blockingExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl-2.md")},
			},
		},
		blockNode:    "implement",
		blockRelease: blockRelease,
		blockStarted: blockStarted,
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "task one"))
	firstCreated := waitForEvent(t, service.Events(), EventTaskCreated)
	waitForEventWhere(t, service.Events(), time.Second, func(event RunEvent) bool {
		return event.Type == EventNodeStarted && event.TaskID == firstCreated.TaskID
	})
	<-blockStarted

	service.Dispatch(startTaskCommand(t, service, "task two"))
	secondCreated := waitForEventWhere(t, service.Events(), time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCreated && event.TaskID != firstCreated.TaskID
	})
	require.NotNil(t, secondCreated.TaskView)
	assert.Equal(t, "task two", secondCreated.TaskView.Task.Description)
	waitForEventWhere(t, service.Events(), time.Second, func(event RunEvent) bool {
		return event.Type == EventNodeStarted && event.TaskID == secondCreated.TaskID
	})

	close(blockRelease)

	completed := map[string]struct{}{}
	for len(completed) < 2 {
		event := waitForEvent(t, service.Events(), EventTaskCompleted)
		completed[event.TaskID] = struct{}{}
	}
	_, sawFirst := completed[firstCreated.TaskID]
	_, sawSecond := completed[secondCreated.TaskID]
	assert.True(t, sawFirst)
	assert.True(t, sawSecond)
}

func TestServiceTaskFailureDoesNotAlsoPublishCommandError(t *testing.T) {
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), &fakeExecutor{
		errors: map[string][]error{
			"implement": {fmt.Errorf("executor bootstrap failed")},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "fail once"))
	failed := waitForEvent(t, service.Events(), EventTaskFailed)
	require.NotNil(t, failed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusFailed, failed.TaskView.Status)
	require.NotNil(t, failed.Error)
	assert.Equal(t, "executor bootstrap failed", failed.Error.Message)
	assertNoEventTypeWithin(t, service.Events(), EventCommandError, 300*time.Millisecond)
}

func TestServiceRejectsInvalidClarificationPayload(t *testing.T) {
	cases := []struct {
		name    string
		payload map[string]interface{}
		wantErr string
	}{
		{
			name:    "missing answers",
			payload: map[string]interface{}{},
			wantErr: "answers array",
		},
		{
			name: "single select receives array",
			payload: map[string]interface{}{
				"answers": []interface{}{
					map[string]interface{}{"selected": []interface{}{"A"}},
				},
			},
			wantErr: "single string value",
		},
		{
			name: "missing selected",
			payload: map[string]interface{}{
				"answers": []interface{}{
					map[string]interface{}{},
				},
			},
			wantErr: "must contain selected",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			service := newTestService(t, &fakeExecutor{
				steps: map[string][]taskexecutor.Result{
					"draft_plan": {
						{
							Kind: taskexecutor.ResultKindClarification,
							Clarification: &taskdomain.ClarificationRequest{
								Questions: []taskdomain.ClarificationQuestion{
									{
										Question:     "Need a choice",
										WhyItMatters: "Impacts plan",
										Options: []taskdomain.ClarificationOption{
											{Label: "A", Description: "Option A"},
											{Label: "B", Description: "Option B"},
										},
									},
								},
							},
						},
					},
				},
			})
			defer service.Close()

			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			go func() { _ = service.Run(ctx) }()

			service.Dispatch(startTaskCommand(t, service, "clarify"))
			event := waitForEvent(t, service.Events(), EventInputRequested)
			require.Equal(t, InputKindClarification, event.InputRequest.Kind)
			task, err := service.store.GetTask(context.Background(), event.TaskID)
			require.NoError(t, err)
			runs, err := service.store.ListNodeRunsByTask(context.Background(), event.TaskID)
			require.NoError(t, err)
			var eventRun taskdomain.NodeRun
			for _, run := range runs {
				if run.ID == event.NodeRunID {
					eventRun = run
					break
				}
			}
			inputPath := mustRunArtifactPathForRun(t, task, runs, eventRun, inputArtifactName)
			beforeInput := readTestFile(t, inputPath)

			err = service.submitInput(context.Background(), event.TaskID, event.NodeRunID, tc.payload)
			require.Error(t, err)
			assert.Contains(t, err.Error(), tc.wantErr)

			run, err := service.store.GetNodeRun(context.Background(), event.NodeRunID)
			require.NoError(t, err)
			assert.Equal(t, taskdomain.NodeRunAwaitingUser, run.Status)
			require.Len(t, run.Clarifications, 1)
			assert.Nil(t, run.Clarifications[0].Response)
			assert.Equal(t, beforeInput, readTestFile(t, inputPath))
		})
	}
}

func TestServiceJoinAllWaitsForAllBranchesBeforeJoining(t *testing.T) {
	service := newTestServiceWithConfig(t, joinAllRuntimeFixture(), &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"start": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("start.md")}},
			"left":  {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("left.md")}},
			"right": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("right.md")}},
			"join":  {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("join.md")}},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "join"))
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	assertNodeRunCounts(t, runs, map[string]int{
		"start": 1,
		"left":  1,
		"right": 1,
		"join":  1,
		"end":   1,
	})
}

func TestServiceDoesNotCompleteUntilAllActiveTerminalRunsFinish(t *testing.T) {
	blockRelease := make(chan struct{})
	blockStarted := make(chan struct{}, 1)
	service := newTestServiceWithConfig(t, parallelTerminalFixture(), &blockingExecutor{
		steps: map[string][]taskexecutor.Result{
			"start": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("start.md")}},
			"left":  {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("left.md")}},
			"right": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("right.md")}},
		},
		blockNode:    "right",
		blockRelease: blockRelease,
		blockStarted: blockStarted,
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "parallel terminals"))
	<-blockStarted
	waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventNodeCompleted && event.NodeName == "left"
	})
	assertNoEventTypeWithin(t, service.Events(), EventTaskCompleted, 300*time.Millisecond)

	close(blockRelease)
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)
}

func TestServiceRetryNodeCreatesNewRunAndRecoversFailedTask(t *testing.T) {
	cfg := singleAgentTerminalFixture()
	cfg.Topology.MaxIterations = 2
	cfg.Topology.Nodes[0].MaxIterations = 2
	service := newTestServiceWithConfig(t, cfg, &fakeExecutor{
		errors: map[string][]error{
			"implement": {fmt.Errorf("runtime unavailable")},
		},
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "retry after failure"))
	failed := waitForEvent(t, service.Events(), EventTaskFailed)
	require.NotNil(t, failed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusFailed, failed.TaskView.Status)

	service.Dispatch(RunCommand{
		Type:      CommandRetryNode,
		TaskID:    failed.TaskID,
		NodeRunID: failed.NodeRunID,
	})
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), failed.TaskID)
	require.NoError(t, err)
	assertNodeRunCounts(t, runs, map[string]int{
		"implement": 2,
		"done":      1,
	})
	require.Equal(t, taskdomain.TriggerReasonManualRetry, runs[1].TriggeredBy.Reason)
	assert.Equal(t, failed.NodeRunID, runs[1].TriggeredBy.NodeRunID)
}

func TestServiceDispatchesCommandErrorInsteadOfTaskFailureForInvalidRetry(t *testing.T) {
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "command error"))
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)

	service.Dispatch(RunCommand{
		Type:      CommandRetryNode,
		TaskID:    completed.TaskID,
		NodeRunID: "missing-run",
	})

	commandErr := waitForEvent(t, service.Events(), EventCommandError)
	require.NotNil(t, commandErr.Error)
	assert.Contains(t, commandErr.Error.Message, "no retryable failed or blocked step")
	assertNoEventTypeWithin(t, service.Events(), EventTaskFailed, 300*time.Millisecond)
}

func TestServiceRetryNodeRequiresForceAfterMaxIterations(t *testing.T) {
	cfg := singleAgentTerminalFixture()
	cfg.Topology.MaxIterations = 1
	cfg.Topology.Nodes[0].MaxIterations = 1
	service := newTestServiceWithConfig(t, cfg, &fakeExecutor{
		errors: map[string][]error{
			"implement": {fmt.Errorf("bad environment")},
		},
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "force retry"))
	failed := waitForEvent(t, service.Events(), EventTaskFailed)

	err := service.retryNode(context.Background(), failed.TaskID, failed.NodeRunID, false)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "retry unavailable")

	err = service.retryNode(context.Background(), failed.TaskID, failed.NodeRunID, true)
	require.NoError(t, err)

	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), failed.TaskID)
	require.NoError(t, err)
	require.Len(t, runs, 3)
	require.NotNil(t, runs[1].TriggeredBy)
	assert.Equal(t, taskdomain.TriggerReasonManualRetryForce, runs[1].TriggeredBy.Reason)
}

func TestServiceForceRetryTargetsBlockedNodeAfterIterationLimitLoopback(t *testing.T) {
	service := newTestServiceWithConfig(t, reviewLoopLimitFixture(), &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-1.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-2.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": false, "file_paths": []interface{}{"/tmp/review-1.md"}}},
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-2.md"}}},
			},
		},
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "loop hits limit"))
	failed := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskFailed && event.NodeName == "draft_plan"
	})
	require.NotNil(t, failed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusFailed, failed.TaskView.Status)

	runs, err := service.store.ListNodeRunsByTask(context.Background(), failed.TaskID)
	require.NoError(t, err)
	cfg, err := taskconfig.Load(taskstore.ConfigPath(service.workDir, failed.TaskID))
	require.NoError(t, err)
	assertNodeRunCounts(t, runs, map[string]int{
		"draft_plan":  1,
		"review_plan": 1,
	})
	blockedSteps, err := taskengine.DeriveBlockedSteps(cfg, runs)
	require.NoError(t, err)
	require.Len(t, blockedSteps, 1)
	blockedDraft := blockedSteps[0]
	var review taskdomain.NodeRun
	for _, run := range runs {
		if run.NodeName == "review_plan" {
			review = run
		}
	}
	assert.Equal(t, "draft_plan", blockedDraft.NodeName)
	assert.Equal(t, 2, blockedDraft.Iteration)
	assert.Contains(t, blockedDraft.Reason, "exceeded max_iterations")
	require.NotNil(t, blockedDraft.TriggeredBy)
	assert.Equal(t, review.ID, blockedDraft.TriggeredBy.NodeRunID)
	assert.Equal(t, "draft_plan", failed.TaskView.CurrentNodeName)

	err = service.continueBlockedStep(context.Background(), failed.TaskID)
	require.NoError(t, err)

	completed := waitForEventWhere(t, service.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID == failed.TaskID
	})
	require.NotNil(t, completed.TaskView)
	assert.Equal(t, taskdomain.TaskStatusDone, completed.TaskView.Status)

	view, _, err := service.LoadTaskView(context.Background(), failed.TaskID)
	require.NoError(t, err)
	assert.Equal(t, taskdomain.TaskStatusDone, view.Status)

	runs, err = service.store.ListNodeRunsByTask(context.Background(), failed.TaskID)
	require.NoError(t, err)
	assertNodeRunCounts(t, runs, map[string]int{
		"draft_plan":  2,
		"review_plan": 2,
		"done":        1,
	})
	draftRequests := service.executor.(*fakeExecutor).requestsForNode("draft_plan")
	require.Len(t, draftRequests, 2)
	lastDraft := draftRequests[len(draftRequests)-1]
	require.NotNil(t, lastDraft.NodeRun.TriggeredBy)
	assert.Equal(t, review.ID, lastDraft.NodeRun.TriggeredBy.NodeRunID)
	assert.Equal(t, taskdomain.TriggerReasonManualContinueForce, lastDraft.NodeRun.TriggeredBy.Reason)

	blockedSteps, err = taskengine.DeriveBlockedSteps(cfg, runs)
	require.NoError(t, err)
	assert.Empty(t, blockedSteps)
}

func TestBlockedStepCanBeReloadedAndContinuedAfterServiceRestart(t *testing.T) {
	cfg := reviewLoopLimitFixture()
	workDir := t.TempDir()
	configPath := writeOverrideConfig(t, cfg)

	firstService, err := NewService(workDir, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-1.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": false, "file_paths": []interface{}{"/tmp/review-1.md"}}},
			},
		},
	})
	require.NoError(t, err)

	ctx, cancel := context.WithCancel(context.Background())
	go func() { _ = firstService.Run(ctx) }()
	firstService.Dispatch(RunCommand{
		Type:        CommandStartTask,
		Description: "blocked restart",
		ConfigAlias: taskconfig.DefaultAlias,
		ConfigPath:  configPath,
		WorkDir:     workDir,
	})
	failed := waitForEventWhere(t, firstService.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskFailed && event.NodeName == "draft_plan"
	})
	taskID := failed.TaskID
	cancel()
	require.NoError(t, firstService.Close())

	secondService, err := NewService(workDir, &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"draft_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("plan-2.md")},
			},
			"review_plan": {
				{Kind: taskexecutor.ResultKindResult, Result: map[string]interface{}{"passed": true, "file_paths": []interface{}{"/tmp/review-2.md"}}},
			},
		},
	})
	require.NoError(t, err)
	defer secondService.Close()

	view, _, err := secondService.LoadTaskView(context.Background(), taskID)
	require.NoError(t, err)
	require.NotNil(t, view.CurrentIssue)
	assert.Equal(t, taskdomain.TaskIssueBlockedStep, view.CurrentIssue.Kind)
	require.Len(t, view.BlockedSteps, 1)
	assert.Equal(t, "draft_plan", view.BlockedSteps[0].NodeName)

	err = secondService.continueBlockedStep(context.Background(), taskID)
	require.NoError(t, err)

	waitForEventWhere(t, secondService.Events(), 5*time.Second, func(event RunEvent) bool {
		return event.Type == EventTaskCompleted && event.TaskID == taskID
	})

	view, _, err = secondService.LoadTaskView(context.Background(), taskID)
	require.NoError(t, err)
	assert.Equal(t, taskdomain.TaskStatusDone, view.Status)
	assert.Empty(t, view.BlockedSteps)
}

func TestNewServiceReconcilesStaleRunningRunsOnStartup(t *testing.T) {
	workDir := t.TempDir()
	store, err := taskstore.Open(workDir)
	require.NoError(t, err)

	now := time.Now().UTC()
	task := taskdomain.Task{
		ID:          "task-stale",
		Description: "stale",
		WorkDir:     workDir,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	require.NoError(t, store.CreateTask(context.Background(), task))
	_, err = taskconfig.Materialize(workDir, task.ID, "")
	require.NoError(t, err)
	require.NoError(t, store.SaveNodeRun(context.Background(), taskdomain.NodeRun{
		ID:        "run-stale",
		TaskID:    task.ID,
		NodeName:  "draft_plan",
		Status:    taskdomain.NodeRunRunning,
		StartedAt: now,
	}))
	require.NoError(t, store.Close())

	service, err := NewService(workDir, &fakeExecutor{steps: map[string][]taskexecutor.Result{}})
	require.NoError(t, err)
	defer service.Close()

	runs, err := service.store.ListNodeRunsByTask(context.Background(), task.ID)
	require.NoError(t, err)
	require.Len(t, runs, 1)
	assert.Equal(t, taskdomain.NodeRunFailed, runs[0].Status)
	assert.Equal(t, taskdomain.FailureReasonOrphanedAfterRestart, runs[0].FailureReason)
	require.NotNil(t, runs[0].CompletedAt)
}

func TestNewServiceRecoversCompletedRunFromOutputEnvelopeOnStartup(t *testing.T) {
	workDir := t.TempDir()
	configPath := writeOverrideConfig(t, singleAgentTerminalFixture())
	store, err := taskstore.Open(workDir)
	require.NoError(t, err)

	now := time.Now().UTC()
	task := taskdomain.Task{
		ID:          "task-recover",
		Description: "recover",
		WorkDir:     workDir,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	require.NoError(t, store.CreateTask(context.Background(), task))
	_, err = taskconfig.Materialize(workDir, task.ID, configPath)
	require.NoError(t, err)
	run := taskdomain.NodeRun{
		ID:        "run-recover",
		TaskID:    task.ID,
		NodeName:  "implement",
		Status:    taskdomain.NodeRunRunning,
		StartedAt: now,
	}
	require.NoError(t, store.SaveNodeRun(context.Background(), run))

	outputPath := filepath.Join(taskstore.RunDir(workDir, task.ID, run.ID), "output.json")
	require.NoError(t, os.MkdirAll(filepath.Dir(outputPath), 0o755))
	require.NoError(t, os.WriteFile(outputPath, []byte("{\"kind\":\"result\",\"result\":{\"file_paths\":[\"plan.md\"]}}\n"), 0o644))
	require.NoError(t, store.Close())

	service, err := NewService(workDir, &fakeExecutor{steps: map[string][]taskexecutor.Result{}})
	require.NoError(t, err)
	defer service.Close()

	runs, err := service.store.ListNodeRunsByTask(context.Background(), task.ID)
	require.NoError(t, err)
	require.Len(t, runs, 2)
	assertNodeRunCounts(t, runs, map[string]int{
		"implement": 1,
		"done":      1,
	})
	var implementRun taskdomain.NodeRun
	var doneRun taskdomain.NodeRun
	for _, candidate := range runs {
		switch candidate.NodeName {
		case "implement":
			implementRun = candidate
		case "done":
			doneRun = candidate
		}
	}
	assert.Equal(t, taskdomain.NodeRunDone, implementRun.Status)
	assert.Equal(t, map[string]any{"file_paths": []any{"plan.md"}}, implementRun.Result)
	assert.Empty(t, implementRun.FailureReason)
	require.NotNil(t, implementRun.CompletedAt)
	assert.Equal(t, taskdomain.NodeRunDone, doneRun.Status)

	view, _, err := service.LoadTaskView(context.Background(), task.ID)
	require.NoError(t, err)
	assert.Equal(t, taskdomain.TaskStatusDone, view.Status)
}

func TestNewServiceRecoversSubmittedHumanNodeOnStartup(t *testing.T) {
	workDir := t.TempDir()
	configPath := writeOverrideConfig(t, humanApprovalFixture())
	store, err := taskstore.Open(workDir)
	require.NoError(t, err)

	now := time.Now().UTC()
	task := taskdomain.Task{
		ID:          "task-human-recover",
		Description: "human recover",
		WorkDir:     workDir,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	require.NoError(t, store.CreateTask(context.Background(), task))
	_, err = taskconfig.Materialize(workDir, task.ID, configPath)
	require.NoError(t, err)
	run := taskdomain.NodeRun{
		ID:        "run-human-recover",
		TaskID:    task.ID,
		NodeName:  "approve_plan",
		Status:    taskdomain.NodeRunAwaitingUser,
		StartedAt: now,
	}
	require.NoError(t, store.SaveNodeRun(context.Background(), run))
	_, err = materializeHumanNodeArtifact(task, run, []taskdomain.NodeRun{run}, map[string]interface{}{"approved": true}, now.Add(time.Second))
	require.NoError(t, err)
	require.NoError(t, store.Close())

	service, err := NewService(workDir, &fakeExecutor{})
	require.NoError(t, err)
	defer service.Close()

	runs, err := service.store.ListNodeRunsByTask(context.Background(), task.ID)
	require.NoError(t, err)
	require.Len(t, runs, 2)
	assertNodeRunCounts(t, runs, map[string]int{
		"approve_plan": 1,
		"done":         1,
	})

	var recovered taskdomain.NodeRun
	for _, candidate := range runs {
		if candidate.NodeName == "approve_plan" {
			recovered = candidate
			break
		}
	}
	assert.Equal(t, taskdomain.NodeRunDone, recovered.Status)
	assert.Equal(t, map[string]any{"approved": true}, recovered.Result)
	require.NotNil(t, recovered.CompletedAt)

	view, _, err := service.LoadTaskView(context.Background(), task.ID)
	require.NoError(t, err)
	assert.Equal(t, taskdomain.TaskStatusDone, view.Status)
}

func TestNewServiceDoesNotAbortWhenStaleRunConfigIsMissing(t *testing.T) {
	workDir := t.TempDir()
	configPath := writeOverrideConfig(t, singleAgentTerminalFixture())
	store, err := taskstore.Open(workDir)
	require.NoError(t, err)

	now := time.Now().UTC()
	task := taskdomain.Task{
		ID:          "task-missing-config",
		Description: "missing config",
		WorkDir:     workDir,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	require.NoError(t, store.CreateTask(context.Background(), task))
	_, err = taskconfig.Materialize(workDir, task.ID, configPath)
	require.NoError(t, err)
	require.NoError(t, os.Remove(taskstore.ConfigPath(workDir, task.ID)))
	require.NoError(t, store.SaveNodeRun(context.Background(), taskdomain.NodeRun{
		ID:        "run-missing-config",
		TaskID:    task.ID,
		NodeName:  "implement",
		Status:    taskdomain.NodeRunRunning,
		StartedAt: now,
	}))
	require.NoError(t, store.Close())

	service, err := NewService(workDir, &fakeExecutor{})
	require.NoError(t, err)
	defer service.Close()

	run, err := service.store.GetNodeRun(context.Background(), "run-missing-config")
	require.NoError(t, err)
	assert.Equal(t, taskdomain.NodeRunFailed, run.Status)
	assert.Equal(t, taskdomain.FailureReasonOrphanedAfterRestart, run.FailureReason)
}

func TestPrepareShutdownMarksRunningRunsInterrupted(t *testing.T) {
	blockRelease := make(chan struct{})
	blockStarted := make(chan struct{}, 1)
	service := newTestServiceWithConfig(t, singleAgentTerminalFixture(), &blockingExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("impl.md")}},
		},
		blockNode:    "implement",
		blockRelease: blockRelease,
		blockStarted: blockStarted,
	})
	defer service.Close()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "shutdown"))
	<-blockStarted
	require.NoError(t, service.PrepareShutdown(context.Background()))
	cancel()
	close(blockRelease)

	runs, err := service.store.ListNodeRunsByStatus(context.Background(), taskdomain.NodeRunFailed)
	require.NoError(t, err)
	require.NotEmpty(t, runs)
	assert.Equal(t, taskdomain.FailureReasonInterruptedByUser, runs[0].FailureReason)
}

type fakeExecutor struct {
	mu       sync.Mutex
	steps    map[string][]taskexecutor.Result
	progress map[string][]taskexecutor.Progress
	errors   map[string][]error
	requests []taskexecutor.Request
}

func (f *fakeExecutor) Execute(ctx context.Context, req taskexecutor.Request, progress func(taskexecutor.Progress)) (taskexecutor.Result, error) {
	f.mu.Lock()
	f.requests = append(f.requests, req)
	progressItems := append([]taskexecutor.Progress(nil), f.progress[req.NodeRun.NodeName]...)
	errSequence := f.errors[req.NodeRun.NodeName]
	if len(errSequence) > 0 {
		execErr := errSequence[0]
		f.errors[req.NodeRun.NodeName] = errSequence[1:]
		f.mu.Unlock()
		if progress != nil {
			for _, item := range progressItems {
				progress(item)
			}
		}
		return taskexecutor.Result{}, execErr
	}
	sequence := f.steps[req.NodeRun.NodeName]
	if len(sequence) == 0 {
		f.mu.Unlock()
		return taskexecutor.Result{}, fmt.Errorf("unexpected node %s", req.NodeRun.NodeName)
	}
	result := sequence[0]
	f.steps[req.NodeRun.NodeName] = sequence[1:]
	f.mu.Unlock()
	if progress != nil {
		if len(progressItems) == 0 {
			progressItems = []taskexecutor.Progress{{Message: fmt.Sprintf("running %s", req.NodeRun.NodeName)}}
		}
		for _, item := range progressItems {
			progress(item)
		}
	}
	return materializeExecutorArtifacts(req, result)
}

func (f *fakeExecutor) requestsForNode(nodeName string) []taskexecutor.Request {
	f.mu.Lock()
	defer f.mu.Unlock()
	var requests []taskexecutor.Request
	for _, req := range f.requests {
		if req.NodeRun.NodeName == nodeName {
			requests = append(requests, req)
		}
	}
	return requests
}

type executorOutcome struct {
	result taskexecutor.Result
	err    error
}

type queuedExecutor struct {
	mu       sync.Mutex
	outcomes map[string][]executorOutcome
	requests []taskexecutor.Request
}

func (q *queuedExecutor) Execute(ctx context.Context, req taskexecutor.Request, progress func(taskexecutor.Progress)) (taskexecutor.Result, error) {
	q.mu.Lock()
	q.requests = append(q.requests, req)
	sequence := q.outcomes[req.NodeRun.NodeName]
	if len(sequence) == 0 {
		q.mu.Unlock()
		return taskexecutor.Result{}, fmt.Errorf("unexpected node %s", req.NodeRun.NodeName)
	}
	outcome := sequence[0]
	q.outcomes[req.NodeRun.NodeName] = sequence[1:]
	q.mu.Unlock()
	if outcome.err != nil {
		return taskexecutor.Result{}, outcome.err
	}
	return materializeExecutorArtifacts(req, outcome.result)
}

func newTestService(t *testing.T, executor taskexecutor.Executor) *Service {
	t.Helper()
	t.Setenv("HOME", t.TempDir())
	_, err := taskconfig.EnsureManagedDefaultAssets()
	require.NoError(t, err)
	workDir := t.TempDir()
	service, err := NewService(workDir, executor)
	require.NoError(t, err)
	return service
}

func newTestServiceWithConfig(t *testing.T, cfg *taskconfig.Config, executor taskexecutor.Executor) *Service {
	t.Helper()
	t.Setenv("HOME", t.TempDir())
	configPath := managedDefaultTestConfigPath(t)
	writeConfigAtPath(t, cfg, configPath)
	workDir := t.TempDir()
	service, err := NewService(workDir, executor)
	require.NoError(t, err)
	return service
}

func managedDefaultTestConfigPath(t *testing.T) string {
	t.Helper()
	path, err := taskconfig.DefaultConfigPath()
	require.NoError(t, err)
	return path
}

func startTaskCommand(t *testing.T, service *Service, description string) RunCommand {
	t.Helper()
	return RunCommand{
		Type:        CommandStartTask,
		Description: description,
		ConfigAlias: taskconfig.DefaultAlias,
		ConfigPath:  managedDefaultTestConfigPath(t),
		WorkDir:     service.workDir,
	}
}

func testImageAttachmentInput(t *testing.T, name string) ImageAttachmentInput {
	t.Helper()
	data := []byte{
		0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
		0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
		0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
		0x08, 0x04, 0x00, 0x00, 0x00, 0xb5, 0x1c, 0x0c,
		0x02, 0x00, 0x00, 0x00, 0x0b, 0x49, 0x44, 0x41,
		0x54, 0x78, 0xda, 0x63, 0xfc, 0xff, 0x1f, 0x00,
		0x03, 0x03, 0x02, 0x00, 0xef, 0xbf, 0xa7, 0xdb,
		0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44,
		0xae, 0x42, 0x60, 0x82,
	}
	return ImageAttachmentInput{
		Name:       name,
		MIMEType:   "image/png",
		SizeBytes:  int64(len(data)),
		DataBase64: base64.StdEncoding.EncodeToString(data),
	}
}

func startFollowUpCommand(parentTaskID, description string) RunCommand {
	return RunCommand{
		Type:         CommandStartFollowUp,
		ParentTaskID: parentTaskID,
		Description:  description,
	}
}

func startFollowUpCommandWithMode(parentTaskID, description string, mode FollowUpMode) RunCommand {
	cmd := startFollowUpCommand(parentTaskID, description)
	cmd.FollowUpMode = mode
	return cmd
}

type completedWorktreeParent struct {
	service   *Service
	completed RunEvent
	task      taskdomain.Task
}

func seedCompletedMainCheckoutParentTask(t *testing.T) completedWorktreeParent {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	_, err := taskconfig.EnsureManagedDefaultAssets()
	require.NoError(t, err)

	cfg := singleAgentTerminalFixture()
	writeConfigAtPath(t, cfg, managedDefaultTestConfigPath(t))

	repo := initRuntimeGitRepoWithCommit(t, true)
	workDir := filepath.Join(repo, "packages", "app")
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-impl.md")},
			},
		},
	}
	service, err := NewService(workDir, executor)
	require.NoError(t, err)

	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go func() { _ = service.Run(ctx) }()

	service.Dispatch(startTaskCommand(t, service, "parent main checkout task"))
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	task, err := service.store.GetTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	return completedWorktreeParent{
		service:   service,
		completed: completed,
		task:      task,
	}
}

func seedCompletedWorktreeParentTask(t *testing.T) completedWorktreeParent {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	_, err := taskconfig.EnsureManagedDefaultAssets()
	require.NoError(t, err)

	cfg := singleAgentTerminalFixture()
	writeConfigAtPath(t, cfg, managedDefaultTestConfigPath(t))

	repo := initRuntimeGitRepoWithCommit(t, true)
	workDir := filepath.Join(repo, "packages", "app")
	executor := &fakeExecutor{
		steps: map[string][]taskexecutor.Result{
			"implement": {
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("parent-impl.md")},
				{Kind: taskexecutor.ResultKindResult, Result: resultWithArtifact("child-impl.md")},
			},
		},
	}
	service, err := NewService(workDir, executor)
	require.NoError(t, err)

	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	go func() { _ = service.Run(ctx) }()

	cmd := startTaskCommand(t, service, "parent worktree task")
	cmd.UseWorktree = true
	service.Dispatch(cmd)
	completed := waitForEvent(t, service.Events(), EventTaskCompleted)
	task, err := service.store.GetTask(context.Background(), completed.TaskID)
	require.NoError(t, err)
	return completedWorktreeParent{
		service:   service,
		completed: completed,
		task:      task,
	}
}

func seedLiveTaskInCheckout(t *testing.T, service *Service, parentTask taskdomain.Task, taskID string, status taskdomain.NodeRunStatus) {
	t.Helper()
	now := time.Now().UTC()
	liveTask := taskdomain.Task{
		ID:           taskID,
		Description:  "live sibling",
		ConfigAlias:  parentTask.ConfigAlias,
		ConfigPath:   parentTask.ConfigPath,
		WorkDir:      parentTask.WorkDir,
		ExecutionDir: parentTask.ExecutionDir,
		CreatedAt:    now,
		UpdatedAt:    now,
	}
	run := taskdomain.NodeRun{
		ID:        taskID + "-run",
		TaskID:    taskID,
		NodeName:  "implement",
		Status:    status,
		StartedAt: now,
	}
	require.NoError(t, service.store.CreateTaskWithEntryRun(context.Background(), liveTask, run))
}

func advanceRuntimeRepoHead(t *testing.T, repoRoot, fileName, content string) string {
	t.Helper()
	require.NoError(t, os.WriteFile(filepath.Join(repoRoot, fileName), []byte(content), 0o644))
	runRuntimeGit(t, repoRoot, "git", "add", fileName)
	runRuntimeGit(t, repoRoot, "git", "commit", "-m", content)
	return gitHeadForRuntime(t, repoRoot)
}

func gitWorktreeList(t *testing.T, repoRoot string) []string {
	t.Helper()
	out, err := exec.Command("git", "-C", repoRoot, "worktree", "list", "--porcelain").CombinedOutput()
	require.NoError(t, err, string(out))
	entries := []string{}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if strings.HasPrefix(line, "worktree ") {
			entries = append(entries, strings.TrimPrefix(line, "worktree "))
		}
	}
	return entries
}

func initRuntimeGitRepoWithCommit(t *testing.T, includeSubdir bool) string {
	t.Helper()

	repo := t.TempDir()
	resolved, err := filepath.EvalSymlinks(repo)
	require.NoError(t, err)
	repo = resolved
	runRuntimeGit(t, repo, "git", "init")
	runRuntimeGit(t, repo, "git", "config", "user.email", "test@test.com")
	runRuntimeGit(t, repo, "git", "config", "user.name", "Test")
	require.NoError(t, os.WriteFile(filepath.Join(repo, "README.md"), []byte("hello"), 0o644))
	if includeSubdir {
		subdir := filepath.Join(repo, "packages", "app")
		require.NoError(t, os.MkdirAll(subdir, 0o755))
		require.NoError(t, os.WriteFile(filepath.Join(subdir, ".keep"), []byte("keep"), 0o644))
		require.NoError(t, os.WriteFile(filepath.Join(subdir, "delete-me.txt"), []byte("delete"), 0o644))
	}
	runRuntimeGit(t, repo, "git", "add", ".")
	runRuntimeGit(t, repo, "git", "commit", "-m", "init")
	return repo
}

func runRuntimeGit(t *testing.T, dir string, name string, args ...string) {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	require.NoError(t, err, "command %s %v failed: %s", name, args, string(out))
}

func gitHeadForRuntime(t *testing.T, dir string) string {
	t.Helper()
	out, err := exec.Command("git", "-C", dir, "rev-parse", "HEAD").CombinedOutput()
	require.NoError(t, err, string(out))
	return strings.TrimSpace(string(out))
}

func waitForEvent(t *testing.T, events <-chan RunEvent, want EventType) RunEvent {
	t.Helper()
	timeout := time.After(5 * time.Second)
	for {
		select {
		case <-timeout:
			t.Fatalf("timed out waiting for %s", want)
		case event := <-events:
			if event.Type == want {
				return event
			}
		}
	}
}

func waitForEventWhere(t *testing.T, events <-chan RunEvent, timeout time.Duration, match func(RunEvent) bool) RunEvent {
	t.Helper()
	deadline := time.After(timeout)
	for {
		select {
		case <-deadline:
			t.Fatalf("timed out waiting for matching event")
		case event := <-events:
			if match(event) {
				return event
			}
		}
	}
}

func waitForTaskSuccess(t *testing.T, events <-chan RunEvent) RunEvent {
	t.Helper()
	timeout := time.After(5 * time.Second)
	for {
		select {
		case <-timeout:
			t.Fatalf("timed out waiting for task success")
		case event := <-events:
			switch event.Type {
			case EventTaskCompleted:
				return event
			case EventTaskFailed:
				message := ""
				if event.Error != nil {
					message = event.Error.Message
				}
				t.Fatalf("task failed instead of completing: %s", message)
			case EventCommandError:
				message := ""
				if event.Error != nil {
					message = event.Error.Message
				}
				t.Fatalf("command error instead of task completion: %s", message)
			}
		}
	}
}

func assertNoEventTypeWithin(t *testing.T, events <-chan RunEvent, want EventType, duration time.Duration) {
	t.Helper()
	deadline := time.After(duration)
	for {
		select {
		case <-deadline:
			return
		case event := <-events:
			if event.Type == want {
				t.Fatalf("unexpected %s event", want)
			}
		}
	}
}

func resultWithArtifact(name string) map[string]interface{} {
	return map[string]interface{}{
		"file_paths": []interface{}{name},
	}
}

func assertNodeRunCounts(t *testing.T, runs []taskdomain.NodeRun, want map[string]int) {
	t.Helper()
	got := map[string]int{}
	for _, run := range runs {
		got[run.NodeName]++
	}
	assert.Equal(t, want, got)
}

type blockingExecutor struct {
	mu             sync.Mutex
	steps          map[string][]taskexecutor.Result
	errors         map[string][]error
	progressByNode map[string][]taskexecutor.Progress
	blockNode      string
	blockRelease   <-chan struct{}
	blockStarted   chan<- struct{}
}

func (b *blockingExecutor) Execute(ctx context.Context, req taskexecutor.Request, progress func(taskexecutor.Progress)) (taskexecutor.Result, error) {
	b.mu.Lock()
	progressItems := append([]taskexecutor.Progress(nil), b.progressByNode[req.NodeRun.NodeName]...)
	errSequence := b.errors[req.NodeRun.NodeName]
	if len(errSequence) > 0 {
		execErr := errSequence[0]
		b.errors[req.NodeRun.NodeName] = errSequence[1:]
		b.mu.Unlock()
		if progress != nil {
			for _, item := range progressItems {
				progress(item)
			}
		}
		return taskexecutor.Result{}, execErr
	}
	sequence := b.steps[req.NodeRun.NodeName]
	if len(sequence) == 0 {
		b.mu.Unlock()
		return taskexecutor.Result{}, fmt.Errorf("unexpected node %s", req.NodeRun.NodeName)
	}
	result := sequence[0]
	b.steps[req.NodeRun.NodeName] = sequence[1:]
	b.mu.Unlock()
	if progress != nil {
		for _, item := range progressItems {
			progress(item)
		}
	}
	if req.NodeRun.NodeName == b.blockNode {
		select {
		case b.blockStarted <- struct{}{}:
		default:
		}
		select {
		case <-ctx.Done():
			return taskexecutor.Result{}, ctx.Err()
		case <-b.blockRelease:
		}
	}
	return materializeExecutorArtifacts(req, result)
}

func materializeExecutorArtifacts(req taskexecutor.Request, result taskexecutor.Result) (taskexecutor.Result, error) {
	if result.Kind == taskexecutor.ResultKindResult {
		result.Result = withDefaultSummary(req.ResultSchema, result.Result)
	}
	outputEnvelope := map[string]interface{}{
		"kind":          result.Kind,
		"result":        nil,
		"clarification": nil,
	}
	switch result.Kind {
	case taskexecutor.ResultKindResult:
		outputEnvelope["result"] = result.Result
	case taskexecutor.ResultKindClarification:
		outputEnvelope["clarification"] = result.Clarification
	}
	outputBytes, err := json.MarshalIndent(outputEnvelope, "", "  ")
	if err != nil {
		return taskexecutor.Result{}, err
	}
	outputBytes = append(outputBytes, '\n')
	if err := os.WriteFile(filepath.Join(req.ArtifactDir, outputArtifactName), outputBytes, 0o644); err != nil {
		return taskexecutor.Result{}, err
	}
	if result.Kind == taskexecutor.ResultKindResult {
		for _, rawPath := range taskdomain.ArtifactPaths(result.Result) {
			path := rawPath
			if !filepath.IsAbs(path) {
				path = filepath.Join(req.ArtifactDir, path)
			}
			if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
				return taskexecutor.Result{}, err
			}
			if err := os.WriteFile(path, []byte("artifact"), 0o644); err != nil {
				return taskexecutor.Result{}, err
			}
		}
	}
	if result.SessionID == "" {
		result.SessionID = req.NodeRun.ID + "-session"
	}
	return result, nil
}

func withDefaultSummary(schema taskconfig.JSONSchema, result map[string]interface{}) map[string]interface{} {
	if result == nil {
		return nil
	}
	if _, ok := schema.Properties["summary"]; !ok {
		return result
	}
	if _, ok := result["summary"]; ok {
		return result
	}
	cloned := make(map[string]interface{}, len(result)+1)
	for key, value := range result {
		cloned[key] = value
	}
	cloned["summary"] = "test summary"
	return cloned
}

func findArtifactPathByBase(t *testing.T, paths []string, base string) string {
	t.Helper()
	for _, path := range paths {
		if filepath.Base(path) == base {
			return path
		}
	}
	t.Fatalf("artifact %q not found in %v", base, paths)
	return ""
}

func mustRunArtifactPathForRun(t *testing.T, task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun, name string) string {
	t.Helper()
	path, err := runArtifactPathForExistingRun(task, runs, run, name)
	require.NoError(t, err)
	return path
}

func readTestFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	return string(data)
}

func writeOverrideConfig(t *testing.T, cfg *taskconfig.Config) string {
	t.Helper()
	configDir := t.TempDir()
	configPath := filepath.Join(configDir, "taskflow.yaml")
	writeConfigAtPath(t, cfg, configPath)
	return configPath
}

func writeConfigAtPath(t *testing.T, cfg *taskconfig.Config, configPath string) {
	t.Helper()
	configDir := filepath.Dir(configPath)
	promptsDir := filepath.Join(configDir, "prompts")
	require.NoError(t, os.MkdirAll(promptsDir, 0o755))

	for name, def := range cfg.NodeDefinitions {
		if def.Type == taskconfig.NodeTypeHuman || def.Type == taskconfig.NodeTypeTerminal {
			continue
		}
		if def.SystemPrompt == "" {
			def.SystemPrompt = "./prompts/" + name + ".md"
			cfg.NodeDefinitions[name] = def
		}
		path := filepath.Join(configDir, strings.TrimPrefix(def.SystemPrompt, "./"))
		require.NoError(t, os.MkdirAll(filepath.Dir(path), 0o755))
		require.NoError(t, os.WriteFile(path, []byte("# "+name), 0o644))
	}

	data, err := yaml.Marshal(cfg)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(configPath, data, 0o644))
}

func overwritePromptWithBuiltinTemplate(t *testing.T, configPath, promptName string) {
	t.Helper()
	sourcePath := filepath.Join("..", "taskconfig", "defaults", "prompts", promptName)
	data, err := os.ReadFile(sourcePath)
	require.NoError(t, err)
	destPath := filepath.Join(filepath.Dir(configPath), "prompts", promptName)
	require.NoError(t, os.MkdirAll(filepath.Dir(destPath), 0o755))
	require.NoError(t, os.WriteFile(destPath, data, 0o644))
}

func joinAllRuntimeFixture() *taskconfig.Config {
	return &taskconfig.Config{
		Version: 1,
		Clarification: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		Topology: taskconfig.Topology{
			MaxIterations: 3,
			Entry:         "start",
			Nodes: []taskconfig.NodeRef{
				{Name: "start"},
				{Name: "left"},
				{Name: "right"},
				{Name: "join", Join: taskconfig.JoinAll},
				{Name: "end"},
			},
			Edges: []taskconfig.Edge{
				{From: "start", To: "left"},
				{From: "start", To: "right"},
				{From: "left", To: "join"},
				{From: "right", To: "join"},
				{From: "join", To: "end"},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"start": artifactAgentNodeWithPrompt("./prompts/start.md"),
			"left":  artifactAgentNodeWithPrompt("./prompts/left.md"),
			"right": artifactAgentNodeWithPrompt("./prompts/right.md"),
			"join":  artifactAgentNodeWithPrompt("./prompts/join.md"),
			"end":   {Type: taskconfig.NodeTypeTerminal},
		},
	}
}

func parallelTerminalFixture() *taskconfig.Config {
	return &taskconfig.Config{
		Version: 1,
		Clarification: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		Topology: taskconfig.Topology{
			MaxIterations: 3,
			Entry:         "start",
			Nodes: []taskconfig.NodeRef{
				{Name: "start"},
				{Name: "left"},
				{Name: "right"},
				{Name: "end_left"},
				{Name: "end_right"},
			},
			Edges: []taskconfig.Edge{
				{From: "start", To: "left"},
				{From: "start", To: "right"},
				{From: "left", To: "end_left"},
				{From: "right", To: "end_right"},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"start":     artifactAgentNodeWithPrompt("./prompts/start.md"),
			"left":      artifactAgentNodeWithPrompt("./prompts/left.md"),
			"right":     artifactAgentNodeWithPrompt("./prompts/right.md"),
			"end_left":  {Type: taskconfig.NodeTypeTerminal},
			"end_right": {Type: taskconfig.NodeTypeTerminal},
		},
	}
}

func singleAgentTerminalFixture() *taskconfig.Config {
	return &taskconfig.Config{
		Version: 1,
		Clarification: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		Topology: taskconfig.Topology{
			MaxIterations: 1,
			Entry:         "implement",
			Nodes: []taskconfig.NodeRef{
				{Name: "implement"},
				{Name: "done"},
			},
			Edges: []taskconfig.Edge{
				{From: "implement", To: "done"},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"implement": artifactAgentNode(),
			"done":      {Type: taskconfig.NodeTypeTerminal},
		},
	}
}

func singleHandleRequestFixture() *taskconfig.Config {
	def := artifactAgentNodeWithPrompt("./prompts/handle_request.md")
	def.MaxClarificationRounds = 1
	return &taskconfig.Config{
		Version: 1,
		Clarification: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		Topology: taskconfig.Topology{
			MaxIterations: 1,
			Entry:         "handle_request",
			Nodes: []taskconfig.NodeRef{
				{Name: "handle_request"},
				{Name: "done"},
			},
			Edges: []taskconfig.Edge{
				{From: "handle_request", To: "done"},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"handle_request": def,
			"done":           {Type: taskconfig.NodeTypeTerminal},
		},
	}
}

func humanApprovalFixture() *taskconfig.Config {
	return &taskconfig.Config{
		Version: 1,
		Clarification: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		Topology: taskconfig.Topology{
			MaxIterations: 1,
			Entry:         "approve_plan",
			Nodes: []taskconfig.NodeRef{
				{Name: "approve_plan"},
				{Name: "done"},
			},
			Edges: []taskconfig.Edge{
				{From: "approve_plan", To: "done"},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"approve_plan": {
				Type: taskconfig.NodeTypeHuman,
				ResultSchema: taskconfig.JSONSchema{
					Type: "object",
					Properties: map[string]*taskconfig.JSONSchema{
						"approved": {Type: "boolean"},
					},
					Required:             []string{"approved"},
					AdditionalProperties: boolRef(false),
				},
			},
			"done": {Type: taskconfig.NodeTypeTerminal},
		},
	}
}

func boolRef(value bool) *bool {
	return &value
}

func reviewLoopLimitFixture() *taskconfig.Config {
	deny := false
	return &taskconfig.Config{
		Version: 1,
		Clarification: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		Topology: taskconfig.Topology{
			MaxIterations: 3,
			Entry:         "draft_plan",
			Nodes: []taskconfig.NodeRef{
				{Name: "draft_plan", MaxIterations: 1},
				{Name: "review_plan"},
				{Name: "done"},
			},
			Edges: []taskconfig.Edge{
				{From: "draft_plan", To: "review_plan"},
				{From: "review_plan", To: "draft_plan", When: taskconfig.EdgeCondition{Kind: taskconfig.ConditionWhen, Field: "passed", Equals: false}},
				{From: "review_plan", To: "done", When: taskconfig.EdgeCondition{Kind: taskconfig.ConditionWhen, Field: "passed", Equals: true}},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"draft_plan": artifactAgentNodeWithPrompt("./prompts/draft_plan.md"),
			"review_plan": {
				Type:         taskconfig.NodeTypeAgent,
				SystemPrompt: "./prompts/review_plan.md",
				ResultSchema: taskconfig.JSONSchema{
					Type:                 "object",
					AdditionalProperties: &deny,
					Required:             []string{"passed", "file_paths"},
					Properties: map[string]*taskconfig.JSONSchema{
						"passed":     {Type: "boolean"},
						"file_paths": {Type: "array", MinItems: intPtr(1), Items: &taskconfig.JSONSchema{Type: "string"}},
					},
				},
			},
			"done": {Type: taskconfig.NodeTypeTerminal},
		},
	}
}

func artifactAgentNode() taskconfig.NodeDefinition {
	deny := false
	return taskconfig.NodeDefinition{
		Type:         taskconfig.NodeTypeAgent,
		SystemPrompt: "./prompts/node.md",
		ResultSchema: taskconfig.JSONSchema{
			Type:                 "object",
			AdditionalProperties: &deny,
			Required:             []string{"file_paths"},
			Properties: map[string]*taskconfig.JSONSchema{
				"file_paths": {
					Type:     "array",
					MinItems: intPtr(1),
					Items:    &taskconfig.JSONSchema{Type: "string"},
				},
			},
		},
	}
}

func artifactAgentNodeWithPrompt(prompt string) taskconfig.NodeDefinition {
	def := artifactAgentNode()
	def.SystemPrompt = prompt
	return def
}

func yoloRuntimeFixture() *taskconfig.Config {
	deny := false
	return &taskconfig.Config{
		Version: 1,
		Clarification: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		Topology: taskconfig.Topology{
			MaxIterations: 100,
			Entry:         "draft_plan",
			Nodes: []taskconfig.NodeRef{
				{Name: "draft_plan"},
				{Name: "review_plan"},
				{Name: "implement"},
				{Name: "verify"},
				{Name: "evaluate_progress"},
				{Name: "done"},
			},
			Edges: []taskconfig.Edge{
				{From: "draft_plan", To: "review_plan"},
				{From: "review_plan", To: "draft_plan", When: taskconfig.EdgeCondition{Kind: taskconfig.ConditionWhen, Field: "passed", Equals: false}},
				{From: "review_plan", To: "implement", When: taskconfig.EdgeCondition{Kind: taskconfig.ConditionWhen, Field: "passed", Equals: true}},
				{From: "implement", To: "verify"},
				{From: "verify", To: "implement", When: taskconfig.EdgeCondition{Kind: taskconfig.ConditionWhen, Field: "passed", Equals: false}},
				{From: "verify", To: "evaluate_progress", When: taskconfig.EdgeCondition{Kind: taskconfig.ConditionWhen, Field: "passed", Equals: true}},
				{From: "evaluate_progress", To: "draft_plan", When: taskconfig.EdgeCondition{Kind: taskconfig.ConditionWhen, Field: "next_node", Equals: "draft_plan"}},
				{From: "evaluate_progress", To: "done", When: taskconfig.EdgeCondition{Kind: taskconfig.ConditionWhen, Field: "next_node", Equals: "done"}},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"draft_plan": artifactAgentNodeWithPrompt("./prompts/draft_plan.md"),
			"review_plan": {
				Type:         taskconfig.NodeTypeAgent,
				SystemPrompt: "./prompts/review_plan.md",
				ResultSchema: taskconfig.JSONSchema{
					Type:                 "object",
					AdditionalProperties: &deny,
					Required:             []string{"passed", "file_paths"},
					Properties: map[string]*taskconfig.JSONSchema{
						"passed":     {Type: "boolean"},
						"file_paths": {Type: "array", MinItems: intPtr(1), Items: &taskconfig.JSONSchema{Type: "string"}},
					},
				},
			},
			"implement": artifactAgentNodeWithPrompt("./prompts/implement.md"),
			"verify": {
				Type:         taskconfig.NodeTypeAgent,
				SystemPrompt: "./prompts/verify.md",
				ResultSchema: taskconfig.JSONSchema{
					Type:                 "object",
					AdditionalProperties: &deny,
					Required:             []string{"passed", "summary", "file_paths"},
					Properties: map[string]*taskconfig.JSONSchema{
						"passed":     {Type: "boolean"},
						"summary":    {Type: "string"},
						"file_paths": {Type: "array", MinItems: intPtr(1), Items: &taskconfig.JSONSchema{Type: "string"}},
					},
				},
			},
			"evaluate_progress": {
				Type:         taskconfig.NodeTypeAgent,
				SystemPrompt: "./prompts/evaluate_progress.md",
				ResultSchema: taskconfig.JSONSchema{
					Type:                 "object",
					AdditionalProperties: &deny,
					Required:             []string{"next_node", "reason", "next_focus", "file_paths"},
					Properties: map[string]*taskconfig.JSONSchema{
						"next_node": {
							Type: "string",
							Enum: []interface{}{"done", "draft_plan"},
						},
						"reason":     {Type: "string"},
						"next_focus": {Type: "string"},
						"file_paths": {Type: "array", MinItems: intPtr(1), Items: &taskconfig.JSONSchema{Type: "string"}},
					},
				},
			},
			"done": {Type: taskconfig.NodeTypeTerminal},
		},
	}
}

func nodeRunNames(runs []taskdomain.NodeRun) []string {
	names := make([]string, 0, len(runs))
	for _, run := range runs {
		names = append(names, run.NodeName)
	}
	return names
}

func intPtr(value int) *int {
	return &value
}

func TestConcurrentInstanceRejected(t *testing.T) {
	workDir := t.TempDir()
	svc1, err := NewService(workDir, &fakeExecutor{})
	require.NoError(t, err)
	defer svc1.Close()

	// Second instance on the same workDir must fail.
	_, err = NewService(workDir, &fakeExecutor{})
	require.Error(t, err)
	assert.Contains(t, err.Error(), "another muxagent instance is already running")

	// After closing the first service, a new one should succeed.
	require.NoError(t, svc1.Close())
	svc3, err := NewService(workDir, &fakeExecutor{})
	require.NoError(t, err)
	defer svc3.Close()
}
