package taskruntime

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/taskconfig"
	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskstore"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestSummarizeWorkflowHistoryPresentsEntriesChronologically(t *testing.T) {
	runs := []taskdomain.NodeRun{
		{
			ID:       "upsert-1",
			NodeName: "draft_plan",
			Status:   taskdomain.NodeRunDone,
			Result: map[string]interface{}{
				"file_paths": []interface{}{"/tmp/plan-v1.md"},
			},
		},
		{
			ID:       "review-1",
			NodeName: "review_plan",
			Status:   taskdomain.NodeRunDone,
			Result: map[string]interface{}{
				"passed":     false,
				"file_paths": []interface{}{"/tmp/review-v1.md"},
			},
		},
		{
			ID:       "upsert-2",
			NodeName: "draft_plan",
			Status:   taskdomain.NodeRunRunning,
		},
	}

	history := summarizeWorkflowHistory(runs)

	assert.Contains(t, history, "1. draft_plan (#1)")
	assert.Contains(t, history, "2. review_plan (#1)")
	assert.Contains(t, history, "/tmp/plan-v1.md")
	assert.Contains(t, history, "/tmp/review-v1.md")
	assert.Contains(t, history, "\"passed\":false")
	assert.Equal(t, 1, strings.Count(history, "/tmp/plan-v1.md"))
	assert.Equal(t, 1, strings.Count(history, "/tmp/review-v1.md"))
	assert.Less(t, strings.Index(history, "1. draft_plan (#1)"), strings.Index(history, "2. review_plan (#1)"))
	assert.Less(t, strings.Index(history, "/tmp/plan-v1.md"), strings.Index(history, "/tmp/review-v1.md"))
}

func TestBuildPromptWorkflowContextUsesRunDirectoriesInsteadOfInliningArtifacts(t *testing.T) {
	cfg := &taskconfig.Config{
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
				{Name: "draft_plan"},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"draft_plan": func() taskconfig.NodeDefinition {
				def := artifactAgentNode()
				def.SystemPrompt = "./prompts/draft_plan.md"
				return def
			}(),
		},
	}
	configPath := writeOverrideConfig(t, cfg)
	promptPath := filepath.Join(filepath.Dir(configPath), "prompts", "draft_plan.md")
	template := strings.Join([]string{
		"{{RUN_METADATA_XML}}",
		"",
		"Primary task for this step:",
		"<<< PRIMARY TASK >>>",
		"{{TASK_DESCRIPTION_BLOCK}}",
		"<<< END PRIMARY TASK >>>",
		"",
		"```text",
		"{{WORKFLOW_DIAGRAM}}",
		"```",
		"",
		"{{WORKFLOW_CONTEXT_XML}}",
		"",
		"{{CLARIFICATION_CONTEXT_XML}}",
	}, "\n")
	require.NoError(t, os.WriteFile(promptPath, []byte(template), 0o644))

	workDir := t.TempDir()
	runs := []taskdomain.NodeRun{
		{
			ID:       "draft-1",
			NodeName: "draft_plan",
			Status:   taskdomain.NodeRunDone,
			Result: map[string]interface{}{
				"file_paths": []interface{}{"/tmp/current-plan.md"},
			},
		},
		{
			ID:       "draft-2",
			NodeName: "draft_plan",
			Status:   taskdomain.NodeRunRunning,
		},
	}

	inherited := &inheritedContext{
		DirectParent: &inheritedTaskReference{
			Description: "parent task",
			TaskDir:     "/tmp/task-parent",
		},
		EarlierAncestors: []inheritedTaskReference{
			{
				Description: "grandparent task",
				TaskDir:     "/tmp/task-grandparent",
			},
		},
	}
	task := taskdomain.Task{ID: "child", WorkDir: workDir, Description: "child task"}

	prompt, err := buildPromptWithInheritedContext(
		task,
		cfg,
		configPath,
		runs,
		runs[1],
		"/tmp/task-artifacts/draft-2",
		inherited,
	)
	require.NoError(t, err)

	assert.Contains(t, prompt, "<task_metadata>")
	assert.Contains(t, prompt, "<task_dir>")
	assert.Contains(t, prompt, "<execution_dir>")
	assert.Contains(t, prompt, "<current_step>draft_plan</current_step>")
	assert.Contains(t, prompt, "Primary task for this step:\n<<< PRIMARY TASK >>>\nchild task\n<<< END PRIMARY TASK >>>")
	assert.Contains(t, prompt, "<execution_context>")
	assert.Contains(t, prompt, "<clarification_state>\n(none)\n</clarification_state>")
	assert.Contains(t, prompt, "Unless the user explicitly says otherwise, do all project reads, edits, builds, tests, and commands in `&lt;execution_dir&gt;`.")
	assert.Contains(t, prompt, taskstore.TaskDir(workDir, "child"))
	assert.Contains(t, prompt, "/tmp/task-artifacts/draft-2")
	assert.Contains(t, prompt, taskstore.RunDir(workDir, "child", "draft-1"))
	assert.Contains(t, prompt, "Direct parent task: parent task")
	assert.Contains(t, prompt, "Task directory: `/tmp/task-parent`")
	assert.Contains(t, prompt, "grandparent task")
	assert.NotContains(t, prompt, "Current task directory:")
	assert.NotContains(t, prompt, "All run directories for this task:")
	assert.NotContains(t, prompt, "Current run directory for this step:")
	assert.NotContains(t, prompt, "first read the newest `review_plan` artifact that rejected or redirected the work")
	assert.NotContains(t, prompt, "\"passed\":false")
	assert.NotContains(t, prompt, "/tmp/current-plan.md")
	assert.NotContains(t, prompt, "/tmp/parent-plan.md")
}

func TestBuildPromptWorktreeContextDirectsAgentToExecutionCheckout(t *testing.T) {
	cfg := &taskconfig.Config{
		Version: 1,
		Clarification: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		Topology: taskconfig.Topology{
			MaxIterations: 3,
			Entry:         "implement",
			Nodes: []taskconfig.NodeRef{
				{Name: "implement"},
			},
		},
		NodeDefinitions: map[string]taskconfig.NodeDefinition{
			"implement": func() taskconfig.NodeDefinition {
				def := artifactAgentNode()
				def.SystemPrompt = "./prompts/implement.md"
				return def
			}(),
		},
	}
	configPath := writeOverrideConfig(t, cfg)
	overwritePromptWithBuiltinTemplate(t, configPath, "implement.md")
	sourceWorkDir := filepath.Join(t.TempDir(), "repo", "packages", "app")
	executionDir := filepath.Join(t.TempDir(), "worktree", "packages", "app")
	require.NoError(t, os.MkdirAll(sourceWorkDir, 0o755))
	require.NoError(t, os.MkdirAll(executionDir, 0o755))

	task := taskdomain.Task{
		ID:           "task-1",
		WorkDir:      sourceWorkDir,
		ExecutionDir: executionDir,
		Description:  "Ship the fix",
	}
	run := taskdomain.NodeRun{ID: "implement-1", NodeName: "implement", Status: taskdomain.NodeRunRunning}

	prompt, err := buildPrompt(task, cfg, configPath, []taskdomain.NodeRun{run}, run, filepath.Join(t.TempDir(), "artifacts"))
	require.NoError(t, err)

	assert.Contains(t, prompt, "<execution_dir>"+executionDir+"</execution_dir>")
	assert.Contains(t, prompt, "Unless the user explicitly says otherwise, do all project reads, edits, builds, tests, and commands in `&lt;execution_dir&gt;`.")
	assert.NotContains(t, prompt, "<source_workdir>")
	assert.NotContains(t, prompt, "<execution_workspace>")
	assert.NotContains(t, prompt, "This task is running in a separate git worktree.")
}

func TestDefaultPromptTemplatesReadLikeStepInstructions(t *testing.T) {
	workDir := t.TempDir()
	materialized, err := taskconfig.Materialize(workDir, "task-1", "")
	require.NoError(t, err)

	cases := []struct {
		name     string
		contains []string
		excludes []string
	}{
		{
			name: "draft_plan",
			contains: []string{
				"{{RUN_METADATA_XML}}",
				"You are in the `draft_plan` step of this workflow.",
				"Primary task for this step:",
				"<<< PRIMARY TASK >>>",
				"{{TASK_DESCRIPTION_BLOCK}}",
				"<<< END PRIMARY TASK >>>",
				"{{WORKFLOW_DIAGRAM}}",
				"{{WORKFLOW_CONTEXT_XML}}",
				"{{CLARIFICATION_CONTEXT_XML}}",
				"What the plan must contain",
				"Clarification rules",
				"List every artifact you wrote in `file_paths`.",
			},
			excludes: []string{
				"ArtifactDir: {{ARTIFACT_DIR}}",
				"{{WORKFLOW_CONTEXT}}",
				"{{CLARIFICATION_CONTEXT}}",
				"Output\n",
			},
		},
		{
			name: "review_plan",
			contains: []string{
				"{{RUN_METADATA_XML}}",
				"You are in the `review_plan` step of this workflow.",
				"Primary task for this step:",
				"<<< PRIMARY TASK >>>",
				"{{TASK_DESCRIPTION_BLOCK}}",
				"<<< END PRIMARY TASK >>>",
				"{{WORKFLOW_DIAGRAM}}",
				"{{WORKFLOW_CONTEXT_XML}}",
				"{{CLARIFICATION_CONTEXT_XML}}",
				"Review checklist",
				"Pass bar",
				"passed",
			},
			excludes: []string{
				"ArtifactDir: {{ARTIFACT_DIR}}",
				"{{WORKFLOW_CONTEXT}}",
				"{{CLARIFICATION_CONTEXT}}",
				"Output\n",
			},
		},
		{
			name: "implement",
			contains: []string{
				"{{RUN_METADATA_XML}}",
				"You are in the `implement` step of this workflow.",
				"Primary task for this step:",
				"<<< PRIMARY TASK >>>",
				"{{TASK_DESCRIPTION_BLOCK}}",
				"<<< END PRIMARY TASK >>>",
				"{{WORKFLOW_DIAGRAM}}",
				"{{WORKFLOW_CONTEXT_XML}}",
				"{{CLARIFICATION_CONTEXT_XML}}",
				"Implementation rules",
				"Implementation summary artifact",
				"List only supporting artifacts under {{ARTIFACT_DIR}} in `file_paths`.",
			},
			excludes: []string{
				"ArtifactDir: {{ARTIFACT_DIR}}",
				"{{WORKFLOW_CONTEXT}}",
				"{{CLARIFICATION_CONTEXT}}",
				"Output\n",
			},
		},
		{
			name: "verify",
			contains: []string{
				"{{RUN_METADATA_XML}}",
				"You are in the `verify` step of this workflow.",
				"Primary task for this step:",
				"<<< PRIMARY TASK >>>",
				"{{TASK_DESCRIPTION_BLOCK}}",
				"<<< END PRIMARY TASK >>>",
				"{{WORKFLOW_DIAGRAM}}",
				"{{WORKFLOW_CONTEXT_XML}}",
				"{{CLARIFICATION_CONTEXT_XML}}",
				"Verification checklist",
				"Use the original task as a guardrail for explicit requirements the plan may have missed.",
				"passed",
			},
			excludes: []string{
				"ArtifactDir: {{ARTIFACT_DIR}}",
				"{{WORKFLOW_CONTEXT}}",
				"{{CLARIFICATION_CONTEXT}}",
				"Output\n",
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			def := materialized.Config.NodeDefinitions[tc.name]
			promptText, err := taskconfig.ReadPromptText(materialized.ConfigPath, def)
			require.NoError(t, err)
			for _, want := range tc.contains {
				assert.Contains(t, promptText, want)
			}
			for _, unwanted := range tc.excludes {
				assert.NotContains(t, promptText, unwanted)
			}
		})
	}
}

func TestBuildWorkflowDiagramUsesClearBuiltinShapes(t *testing.T) {
	cases := []struct {
		name     string
		cfg      *taskconfig.Config
		contains []string
	}{
		{
			name: "default",
			cfg:  &taskconfig.Config{Topology: taskconfig.Topology{Nodes: []taskconfig.NodeRef{{Name: "draft_plan"}, {Name: "review_plan"}, {Name: "approve_plan"}, {Name: "implement"}, {Name: "verify"}, {Name: "done"}}}},
			contains: []string{
				"review_plan",
				"passed=true --> approve_plan (human)",
				"approved=true --> implement",
				"passed=true --> done (terminal)",
			},
		},
		{
			name: "plan-only",
			cfg:  &taskconfig.Config{Topology: taskconfig.Topology{Nodes: []taskconfig.NodeRef{{Name: "draft_plan"}, {Name: "review_plan"}, {Name: "done"}}}},
			contains: []string{
				"review_plan",
				"passed=false --> draft_plan",
				"passed=true --> done (terminal)",
			},
		},
		{
			name: "single-run",
			cfg:  &taskconfig.Config{Topology: taskconfig.Topology{Nodes: []taskconfig.NodeRef{{Name: "handle_request"}, {Name: "done"}}}},
			contains: []string{
				"handle_request",
				"done (terminal)",
			},
		},
		{
			name: "autonomous",
			cfg:  &taskconfig.Config{Topology: taskconfig.Topology{Nodes: []taskconfig.NodeRef{{Name: "draft_plan"}, {Name: "review_plan"}, {Name: "implement"}, {Name: "verify"}, {Name: "done"}}}},
			contains: []string{
				"review_plan",
				"passed=true --> implement",
				"passed=true --> done (terminal)",
			},
		},
		{
			name: "yolo",
			cfg:  &taskconfig.Config{Topology: taskconfig.Topology{Nodes: []taskconfig.NodeRef{{Name: "draft_plan"}, {Name: "review_plan"}, {Name: "implement"}, {Name: "verify"}, {Name: "evaluate_progress"}, {Name: "done"}}}},
			contains: []string{
				"evaluate_progress",
				"next_node=draft_plan --> draft_plan",
				"next_node=done --> done (terminal)",
			},
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			diagram := buildWorkflowDiagram(tc.cfg)
			for _, want := range tc.contains {
				assert.Contains(t, diagram, want)
			}
		})
	}
}

func TestBuildClarificationResumePromptUsesStructuredContext(t *testing.T) {
	cfg := &taskconfig.Config{
		Description: "Read-only planning loop: plan and review, no implementation.",
		Topology: taskconfig.Topology{
			Entry: "draft_plan",
			Nodes: []taskconfig.NodeRef{
				{Name: "draft_plan"},
				{Name: "review_plan"},
				{Name: "done"},
			},
		},
	}
	run := taskdomain.NodeRun{
		NodeName:  "draft_plan",
		SessionID: "thread-draft_plan-1",
		Clarifications: []taskdomain.ClarificationExchange{{
			Request: taskdomain.ClarificationRequest{
				Questions: []taskdomain.ClarificationQuestion{
					{
						Question:     "Which path should we take?",
						WhyItMatters: "The plan changes based on this choice.",
						Options: []taskdomain.ClarificationOption{
							{Label: "A", Description: "Option A"},
							{Label: "B", Description: "Option B"},
						},
					},
				},
			},
			Response: &taskdomain.ClarificationResponse{
				Answers: []taskdomain.ClarificationAnswer{
					{Selected: "A"},
				},
			},
		}},
	}

	prompt, err := buildClarificationResumePrompt(
		taskdomain.Task{
			ID:          "task-1",
			WorkDir:     "/tmp/workdir",
			ConfigAlias: taskconfig.BuiltinIDPlanOnly,
			Description: "Implement login\nHandle SSO fallback",
		},
		cfg,
		[]taskdomain.NodeRun{run},
		run,
		"/tmp/task-artifacts/draft-plan",
		2,
		nil,
	)
	require.NoError(t, err)

	assert.Contains(t, prompt, "<task_metadata>")
	assert.Contains(t, prompt, "<config_alias>plan-only</config_alias>")
	assert.Contains(t, prompt, "<task_dir>")
	assert.Contains(t, prompt, "<execution_dir>/tmp/workdir</execution_dir>")
	assert.Contains(t, prompt, "<current_step>draft_plan</current_step>")
	assert.Contains(t, prompt, "<current_iteration>2</current_iteration>")
	assert.True(t, strings.HasPrefix(prompt, "<task_metadata>"))
	assert.Contains(t, prompt, "You are resuming the `draft_plan` step after the user answered your clarification request.")
	assert.Contains(t, prompt, "Primary task for this step:\n<<< PRIMARY TASK >>>\nImplement login\nHandle SSO fallback\n<<< END PRIMARY TASK >>>")
	assert.Contains(t, prompt, "Task priority rules")
	assert.Contains(t, prompt, "Workflow for this config:")
	assert.Contains(t, prompt, "passed=true --> done (terminal)")
	assert.Contains(t, prompt, "<execution_context>")
	assert.Contains(t, prompt, "Unless the user explicitly says otherwise, do all project reads, edits, builds, tests, and commands in `&lt;execution_dir&gt;`.")
	assert.Contains(t, prompt, "<clarification_state>")
	assert.Contains(t, prompt, "<clarification_exchange>")
	assert.Contains(t, prompt, "User selected:")
	assert.Contains(t, prompt, "Stay in the same thread context")
	assert.NotContains(t, prompt, "Step: draft_plan")
	assert.NotContains(t, prompt, "Mission")
}
