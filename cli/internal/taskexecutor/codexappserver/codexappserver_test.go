package codexappserver

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/LaLanMo/muxagent/cli/internal/taskconfig"
	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestExecutorParsesResultAndProgress(t *testing.T) {
	binaryPath := writeFakeCodexAppServer(t)
	t.Setenv("FAKE_CODEX_MODE", "result")

	executor := New(binaryPath)
	req := requestFixture(t.TempDir())
	var progress []taskexecutor.Progress

	result, err := executor.Execute(context.Background(), req, func(item taskexecutor.Progress) {
		progress = append(progress, item)
	})
	require.NoError(t, err)
	assert.Equal(t, "thread-123", result.SessionID)
	assert.Equal(t, taskexecutor.ResultKindResult, result.Kind)
	assert.NotEmpty(t, result.Result["file_paths"])
	require.GreaterOrEqual(t, len(progress), 3)
	assert.Equal(t, "thread-123", progress[0].SessionID)

	var summaries []string
	for _, item := range progress {
		if item.Message != "" {
			summaries = append(summaries, item.Message)
		}
	}
	assert.Contains(t, summaries, "shell: /bin/zsh -lc 'pwd'")
	assert.Contains(t, summaries, "files: A artifact.md")
}

func TestExecutorParsesClarification(t *testing.T) {
	binaryPath := writeFakeCodexAppServer(t)
	t.Setenv("FAKE_CODEX_MODE", "clarification")

	executor := New(binaryPath)
	result, err := executor.Execute(context.Background(), requestFixture(t.TempDir()), nil)
	require.NoError(t, err)
	assert.Equal(t, taskexecutor.ResultKindClarification, result.Kind)
	require.NotNil(t, result.Clarification)
	assert.Len(t, result.Clarification.Questions, 1)
	assert.Equal(t, "Option A", result.Clarification.Questions[0].Options[0].Description)
}

func TestExecutorUsesThreadResumeForAnsweredClarification(t *testing.T) {
	binaryPath := writeFakeCodexAppServer(t)
	requestsFile := filepath.Join(t.TempDir(), "requests.jsonl")
	t.Setenv("FAKE_CODEX_MODE", "result")
	t.Setenv("FAKE_CODEX_APP_SERVER_REQUESTS_FILE", requestsFile)

	executor := New(binaryPath)
	req := requestFixture(t.TempDir())
	req.NodeRun.SessionID = "thread-123"
	req.NodeRun.Clarifications = []taskdomain.ClarificationExchange{
		{
			Request: taskdomain.ClarificationRequest{
				Questions: []taskdomain.ClarificationQuestion{{Question: "Need input"}},
			},
			Response: &taskdomain.ClarificationResponse{
				Answers: []taskdomain.ClarificationAnswer{{Selected: "A"}},
			},
		},
	}

	_, err := executor.Execute(context.Background(), req, nil)
	require.NoError(t, err)

	data, err := os.ReadFile(requestsFile)
	require.NoError(t, err)
	assert.Contains(t, string(data), `"method":"thread/resume"`)
	assert.Contains(t, string(data), `"threadId":"thread-123"`)
}

func TestExecutorFailsWhenResumeSwitchesToDifferentThread(t *testing.T) {
	binaryPath := writeFakeCodexAppServer(t)
	t.Setenv("FAKE_CODEX_MODE", "resume-different-thread")

	executor := New(binaryPath)
	req := requestFixture(t.TempDir())
	req.NodeRun.SessionID = "thread-123"
	req.NodeRun.Clarifications = []taskdomain.ClarificationExchange{
		{
			Request: taskdomain.ClarificationRequest{
				Questions: []taskdomain.ClarificationQuestion{{Question: "Need input"}},
			},
			Response: &taskdomain.ClarificationResponse{
				Answers: []taskdomain.ClarificationAnswer{{Selected: "A"}},
			},
		},
	}

	_, err := executor.Execute(context.Background(), req, nil)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "resume switched threads")
}

func TestExecutorFailsOnMalformedJSON(t *testing.T) {
	binaryPath := writeFakeCodexAppServer(t)
	t.Setenv("FAKE_CODEX_MODE", "badjson")

	executor := New(binaryPath)
	_, err := executor.Execute(context.Background(), requestFixture(t.TempDir()), nil)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "invalid codex app-server json")
}

func TestExecutorFailsOnSchemaMismatch(t *testing.T) {
	binaryPath := writeFakeCodexAppServer(t)
	t.Setenv("FAKE_CODEX_MODE", "invalid-output")

	executor := New(binaryPath)
	_, err := executor.Execute(context.Background(), requestFixture(t.TempDir()), nil)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "file_paths")
}

func TestExecutorPropagatesSubprocessFailure(t *testing.T) {
	binaryPath := writeFakeCodexAppServer(t)
	t.Setenv("FAKE_CODEX_MODE", "fail")

	executor := New(binaryPath)
	_, err := executor.Execute(context.Background(), requestFixture(t.TempDir()), nil)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "stderr boom")
}

func TestParseNotificationEmitsCommentaryMessageDeltaSnapshots(t *testing.T) {
	state := newStreamState()
	turnID := "turn-123"

	startedParams := map[string]any{
		"turnId": turnID,
		"item": map[string]any{
			"type":  "agentMessage",
			"id":    "msg-1",
			"phase": "commentary",
			"text":  "",
		},
	}
	events, completed, failed, messageText := parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/started", "params": startedParams}),
		"item/started",
		startedParams,
		turnID,
		state,
	)
	require.Empty(t, events)
	assert.False(t, completed)
	assert.Empty(t, failed)
	assert.Empty(t, messageText)

	deltaParams := map[string]any{
		"turnId": turnID,
		"itemId": "msg-1",
		"delta":  "Inspect",
	}
	events, _, _, _ = parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/agentMessage/delta", "params": deltaParams}),
		"item/agentMessage/delta",
		deltaParams,
		turnID,
		state,
	)
	require.Len(t, events, 1)
	require.NotNil(t, events[0].Message)
	assert.Equal(t, "msg-1", events[0].Message.MessageID)
	assert.Equal(t, "phase:commentary", events[0].Message.PartID)
	assert.Equal(t, "Inspect", events[0].Message.Text)

	deltaParams["delta"] = " repo"
	events, _, _, _ = parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/agentMessage/delta", "params": deltaParams}),
		"item/agentMessage/delta",
		deltaParams,
		turnID,
		state,
	)
	require.Len(t, events, 1)
	require.NotNil(t, events[0].Message)
	assert.Equal(t, "Inspect repo", events[0].Message.Text)
}

func TestParseNotificationKeepsStructuredFinalAnswerOutOfMessageStream(t *testing.T) {
	state := newStreamState()
	turnID := "turn-123"
	finalText := `{"kind":"result","result":{"file_paths":["/tmp/artifact.md"]},"clarification":null}`

	startedParams := map[string]any{
		"turnId": turnID,
		"item": map[string]any{
			"type":  "agentMessage",
			"id":    "msg-final",
			"phase": "final_answer",
			"text":  "",
		},
	}
	parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/started", "params": startedParams}),
		"item/started",
		startedParams,
		turnID,
		state,
	)

	deltaParams := map[string]any{
		"turnId": turnID,
		"itemId": "msg-final",
		"delta":  finalText,
	}
	events, completed, failed, messageText := parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/agentMessage/delta", "params": deltaParams}),
		"item/agentMessage/delta",
		deltaParams,
		turnID,
		state,
	)
	require.Empty(t, events)
	assert.False(t, completed)
	assert.Empty(t, failed)
	assert.Empty(t, messageText)

	completedParams := map[string]any{
		"turnId": turnID,
		"item": map[string]any{
			"type":  "agentMessage",
			"id":    "msg-final",
			"phase": "final_answer",
			"text":  finalText,
		},
	}
	events, _, _, messageText = parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/completed", "params": completedParams}),
		"item/completed",
		completedParams,
		turnID,
		state,
	)
	require.Empty(t, events)
	assert.Equal(t, finalText, messageText)
}

func TestParseNotificationSuppressesPartialStructuredFinalAnswerDeltas(t *testing.T) {
	state := newStreamState()
	turnID := "turn-123"

	startedParams := map[string]any{
		"turnId": turnID,
		"item": map[string]any{
			"type":  "agentMessage",
			"id":    "msg-final",
			"phase": "final_answer",
			"text":  "",
		},
	}
	parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/started", "params": startedParams}),
		"item/started",
		startedParams,
		turnID,
		state,
	)

	deltaParams := map[string]any{
		"turnId": turnID,
		"itemId": "msg-final",
		"delta":  `{"clar`,
	}
	events, completed, failed, messageText := parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/agentMessage/delta", "params": deltaParams}),
		"item/agentMessage/delta",
		deltaParams,
		turnID,
		state,
	)
	require.Empty(t, events)
	assert.False(t, completed)
	assert.Empty(t, failed)
	assert.Empty(t, messageText)

	deltaParams["delta"] = `ification":null}`
	events, completed, failed, messageText = parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/agentMessage/delta", "params": deltaParams}),
		"item/agentMessage/delta",
		deltaParams,
		turnID,
		state,
	)
	require.Empty(t, events)
	assert.False(t, completed)
	assert.Empty(t, failed)
	assert.Empty(t, messageText)
}

func TestParseNotificationEmitsReasoningSummarySnapshots(t *testing.T) {
	state := newStreamState()
	turnID := "turn-123"

	params := map[string]any{
		"turnId":       turnID,
		"itemId":       "reason-1",
		"summaryIndex": 0,
		"delta":        "Inspect",
	}
	events, completed, failed, messageText := parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/reasoning/summaryTextDelta", "params": params}),
		"item/reasoning/summaryTextDelta",
		params,
		turnID,
		state,
	)
	require.Len(t, events, 1)
	assert.False(t, completed)
	assert.Empty(t, failed)
	assert.Empty(t, messageText)
	require.NotNil(t, events[0].Message)
	assert.Equal(t, taskexecutor.MessagePartTypeReasoning, events[0].Message.Type)
	assert.Equal(t, "reason-1", events[0].Message.MessageID)
	assert.Equal(t, "summary", events[0].Message.PartID)
	assert.Equal(t, "Inspect", events[0].Message.Text)

	params["delta"] = " repo"
	events, _, _, _ = parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/reasoning/summaryTextDelta", "params": params}),
		"item/reasoning/summaryTextDelta",
		params,
		turnID,
		state,
	)
	require.Len(t, events, 1)
	require.NotNil(t, events[0].Message)
	assert.Equal(t, "Inspect repo", events[0].Message.Text)
}

func TestParseNotificationHandlesMCPToolCallLifecycle(t *testing.T) {
	state := newStreamState()
	turnID := "turn-123"

	startedParams := map[string]any{
		"turnId": turnID,
		"item": map[string]any{
			"type":      "mcpToolCall",
			"id":        "mcp-1",
			"server":    "pencil",
			"tool":      "get_editor_state",
			"arguments": map[string]any{"include_schema": true},
			"status":    "inProgress",
		},
	}
	events, completed, failed, messageText := parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/started", "params": startedParams}),
		"item/started",
		startedParams,
		turnID,
		state,
	)
	require.Len(t, events, 1)
	assert.False(t, completed)
	assert.Empty(t, failed)
	assert.Empty(t, messageText)
	require.NotNil(t, events[0].Tool)
	assert.Equal(t, taskexecutor.ToolKindMCP, events[0].Tool.Kind)
	assert.Equal(t, taskexecutor.ToolStatusInProgress, events[0].Tool.Status)
	assert.Equal(t, "pencil.get_editor_state", events[0].Tool.InputSummary)

	progressParams := map[string]any{
		"turnId":  turnID,
		"itemId":  "mcp-1",
		"message": "Loaded the editor schema.",
	}
	events, _, _, _ = parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/mcpToolCall/progress", "params": progressParams}),
		"item/mcpToolCall/progress",
		progressParams,
		turnID,
		state,
	)
	require.Len(t, events, 1)
	require.NotNil(t, events[0].Tool)
	assert.Equal(t, taskexecutor.ToolKindMCP, events[0].Tool.Kind)
	assert.Equal(t, "Loaded the editor schema.", events[0].Tool.OutputText)

	completedParams := map[string]any{
		"turnId": turnID,
		"item": map[string]any{
			"type":       "mcpToolCall",
			"id":         "mcp-1",
			"server":     "pencil",
			"tool":       "get_editor_state",
			"arguments":  map[string]any{"include_schema": true},
			"status":     "completed",
			"durationMs": 920,
			"result": map[string]any{
				"content": []any{
					map[string]any{"type": "text", "text": "Loaded the editor schema."},
				},
				"structuredContent": map[string]any{"selection": "canvas-root"},
			},
		},
	}
	events, _, _, _ = parseNotification(
		mustRawJSON(t, map[string]any{"method": "item/completed", "params": completedParams}),
		"item/completed",
		completedParams,
		turnID,
		state,
	)
	require.Len(t, events, 1)
	require.NotNil(t, events[0].Tool)
	assert.Equal(t, taskexecutor.ToolKindMCP, events[0].Tool.Kind)
	assert.Equal(t, taskexecutor.ToolStatusCompleted, events[0].Tool.Status)
	assert.Equal(t, int64(920), events[0].Tool.DurationMS)
	assert.Equal(t, "Loaded the editor schema.", events[0].Tool.OutputText)
	if assert.NotNil(t, events[0].Tool.MCP) {
		assert.Equal(t, `{"include_schema":true}`, events[0].Tool.MCP.ArgumentsJSON)
		assert.Equal(t, `{"selection":"canvas-root"}`, events[0].Tool.MCP.StructuredContentJSON)
	}
}

func requestFixture(artifactDir string) taskexecutor.Request {
	allow := false
	return taskexecutor.Request{
		Task: taskdomain.Task{
			ID:          "task-1",
			Description: "Implement feature",
			WorkDir:     artifactDir,
		},
		NodeRun: taskdomain.NodeRun{
			ID:       "run-1",
			TaskID:   "task-1",
			NodeName: "implement",
		},
		NodeDefinition: taskconfig.NodeDefinition{
			SystemPrompt:           "./prompt.md",
			MaxClarificationRounds: 2,
			ResultSchema: taskconfig.JSONSchema{
				Type:                 "object",
				AdditionalProperties: &allow,
				Required:             []string{"file_paths"},
				Properties: map[string]*taskconfig.JSONSchema{
					"file_paths": {
						Type:  "array",
						Items: &taskconfig.JSONSchema{Type: "string"},
					},
				},
			},
		},
		ClarificationConfig: taskconfig.ClarificationConfig{
			MaxQuestions:          4,
			MaxOptionsPerQuestion: 4,
			MinOptionsPerQuestion: 2,
		},
		ConfigPath:  filepath.Join(artifactDir, "config.yaml"),
		SchemaPath:  filepath.Join(artifactDir, "schemas", "implement.json"),
		WorkDir:     artifactDir,
		ArtifactDir: artifactDir,
		Prompt:      "do it",
		ResultSchema: taskconfig.JSONSchema{
			Type:                 "object",
			AdditionalProperties: &allow,
			Required:             []string{"file_paths"},
			Properties: map[string]*taskconfig.JSONSchema{
				"file_paths": {
					Type:  "array",
					Items: &taskconfig.JSONSchema{Type: "string"},
				},
			},
		},
	}
}

func mustRawJSON(t *testing.T, payload map[string]any) json.RawMessage {
	t.Helper()
	data, err := json.Marshal(payload)
	require.NoError(t, err)
	return data
}

func writeFakeCodexAppServer(t *testing.T) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "fake-codex-app-server.py")
	script := `#!/usr/bin/env python3
import json
import os
import sys

mode = os.environ.get("FAKE_CODEX_MODE", "result")
requests_path = os.environ.get("FAKE_CODEX_APP_SERVER_REQUESTS_FILE", "")
requests_file = open(requests_path, "a", encoding="utf-8") if requests_path else None

def emit(payload):
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()

def record(payload):
    if requests_file is None:
        return
    requests_file.write(json.dumps(payload, separators=(",", ":")) + "\n")
    requests_file.flush()

def result_payload():
    return {"kind": "result", "result": {"file_paths": ["/tmp/artifact.md"]}, "clarification": None}

def clarification_payload():
    return {
        "kind": "clarification",
        "result": None,
        "clarification": {
            "questions": [
                {
                    "question": "What should we do?",
                    "why_it_matters": "Need direction",
                    "options": [
                        {"label": "A", "description": "Option A"},
                        {"label": "B", "description": "Option B"},
                    ],
                    "multi_select": False,
                }
            ]
        },
    }

if mode == "fail":
    sys.stderr.write("stderr boom\n")
    sys.stderr.flush()
    sys.exit(2)

for raw_line in sys.stdin:
    if mode == "badjson":
        sys.stdout.write("{bad json\n")
        sys.stdout.flush()
        break
    line = raw_line.strip()
    if not line:
        continue
    payload = json.loads(line)
    record(payload)
    method = payload.get("method")
    if method == "initialize":
        emit({"id": payload["id"], "result": {"userAgent": "fake", "codexHome": "/tmp/.codex", "platformFamily": "unix", "platformOs": "linux"}})
        continue
    if method == "initialized":
        continue
    if method == "thread/start":
        emit({"id": payload["id"], "result": {"thread": {"id": "thread-123", "status": {"type": "idle"}}}})
        continue
    if method == "thread/resume":
        thread_id = "thread-999" if mode == "resume-different-thread" else payload["params"]["threadId"]
        emit({"id": payload["id"], "result": {"thread": {"id": thread_id, "status": {"type": "idle"}, "cwd": "/tmp/project"}}})
        if mode == "resume-different-thread":
            break
        continue
    if method != "turn/start":
        continue

    turn_id = "turn-123"
    emit({"id": payload["id"], "result": {"turn": {"id": turn_id, "status": "inProgress", "items": [], "error": None}}})
    emit({"method": "turn/started", "params": {"threadId": "thread-123", "turn": {"id": turn_id, "status": "inProgress", "items": [], "error": None}}})
    emit({"method": "item/started", "params": {"threadId": "thread-123", "turnId": turn_id, "item": {"type": "userMessage", "id": "user-1", "content": [{"type": "text", "text": "do it"}]}}})
    emit({"method": "item/completed", "params": {"threadId": "thread-123", "turnId": turn_id, "item": {"type": "userMessage", "id": "user-1", "content": [{"type": "text", "text": "do it"}]}}})

    if mode == "result":
        emit({"method": "item/started", "params": {"threadId": "thread-123", "turnId": turn_id, "item": {"type": "commandExecution", "id": "cmd-1", "command": "/bin/zsh -lc 'pwd'", "status": "inProgress"}}})
        emit({"method": "item/completed", "params": {"threadId": "thread-123", "turnId": turn_id, "item": {"type": "commandExecution", "id": "cmd-1", "command": "/bin/zsh -lc 'pwd'", "status": "completed", "aggregatedOutput": "/tmp/project\n", "exitCode": 0}}})
        emit({"method": "item/started", "params": {"threadId": "thread-123", "turnId": turn_id, "item": {"type": "fileChange", "id": "file-1", "status": "inProgress", "changes": [{"path": "/tmp/artifact.md", "kind": {"type": "add"}, "diff": "hello\n"}]}}})
        emit({"method": "item/fileChange/outputDelta", "params": {"threadId": "thread-123", "turnId": turn_id, "itemId": "file-1", "delta": "applied"}})
        emit({"method": "item/completed", "params": {"threadId": "thread-123", "turnId": turn_id, "item": {"type": "fileChange", "id": "file-1", "status": "completed", "changes": [{"path": "/tmp/artifact.md", "kind": {"type": "add"}, "diff": "hello\n"}]}}})
        final = result_payload()
    elif mode == "clarification":
        final = clarification_payload()
    elif mode == "invalid-output":
        final = {"kind": "result", "result": {"wrong": True}, "clarification": None}
    else:
        final = result_payload()

    final_text = json.dumps(final, separators=(",", ":"))
    emit({"method": "item/started", "params": {"threadId": "thread-123", "turnId": turn_id, "item": {"type": "agentMessage", "id": "msg-1", "text": "", "phase": "final_answer"}}})
    emit({"method": "item/agentMessage/delta", "params": {"threadId": "thread-123", "turnId": turn_id, "itemId": "msg-1", "delta": final_text}})
    emit({"method": "item/completed", "params": {"threadId": "thread-123", "turnId": turn_id, "item": {"type": "agentMessage", "id": "msg-1", "text": final_text, "phase": "final_answer"}}})
    emit({"method": "thread/tokenUsage/updated", "params": {"threadId": "thread-123", "turnId": turn_id, "tokenUsage": {"total": {"totalTokens": 12, "inputTokens": 7, "cachedInputTokens": 1, "outputTokens": 5}}}})
    emit({"method": "turn/completed", "params": {"threadId": "thread-123", "turn": {"id": turn_id, "status": "completed", "items": [], "error": None}}})
    break

if requests_file is not None:
    requests_file.close()
`
	require.NoError(t, os.WriteFile(path, []byte(script), 0o755))
	return path
}

func TestCanonicalJSON(t *testing.T) {
	out, err := canonicalJSON([]byte("{\"b\":2,\"a\":1}"))
	require.NoError(t, err)
	var payload map[string]int
	require.NoError(t, json.Unmarshal(out, &payload))
	assert.Equal(t, map[string]int{"a": 1, "b": 2}, payload)
}
