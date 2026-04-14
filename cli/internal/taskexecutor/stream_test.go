package taskexecutor

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMergeStreamEventAppendsIncrementalMessageText(t *testing.T) {
	existing := StreamEvent{
		Kind: StreamEventKindMessage,
		Message: &MessagePart{
			MessageID: "msg-1",
			PartID:    "part-1",
			Role:      MessageRoleAssistant,
			Type:      MessagePartTypeReasoning,
			Text:      "Inspect",
		},
	}
	next := StreamEvent{
		Kind: StreamEventKindMessage,
		Message: &MessagePart{
			MessageID: "msg-1",
			PartID:    "part-1",
			Role:      MessageRoleAssistant,
			Type:      MessagePartTypeReasoning,
			Text:      " repo",
			Append:    true,
		},
	}

	merged := MergeStreamEvent(existing, next)

	assert.Equal(t, "Inspect repo", merged.Message.Text)
	assert.True(t, merged.Message.Append)
}

func TestMergeStreamEventPreservesSpecificToolKindAndMeaningfulName(t *testing.T) {
	existing := StreamEvent{
		Kind: StreamEventKindTool,
		Tool: &ToolCall{
			CallID:       "tool-1",
			Name:         "Grep",
			Kind:         ToolKindSearch,
			Status:       ToolStatusInProgress,
			InputSummary: "theme /tmp/project",
		},
	}
	next := StreamEvent{
		Kind: StreamEventKindTool,
		Tool: &ToolCall{
			CallID:        "tool-1",
			Name:          "tool_result",
			Kind:          ToolKindOther,
			Status:        ToolStatusCompleted,
			OutputText:    "matched lines",
			ErrorText:     "",
			RawOutputJSON: `{"content":"matched lines"}`,
		},
	}

	merged := MergeStreamEvent(existing, next)

	assert.Equal(t, ToolKindSearch, merged.Tool.Kind)
	assert.Equal(t, "Grep", merged.Tool.Name)
	assert.Equal(t, ToolStatusCompleted, merged.Tool.Status)
	assert.Equal(t, "theme /tmp/project", merged.Tool.InputSummary)
	assert.Equal(t, "matched lines", merged.Tool.OutputText)
}

func TestMergeStreamEventUpgradesUnknownToolKindWhenResultIsSpecific(t *testing.T) {
	existing := StreamEvent{
		Kind: StreamEventKindTool,
		Tool: &ToolCall{
			CallID:       "tool-1",
			Name:         "UnknownTool",
			Kind:         ToolKindOther,
			Status:       ToolStatusInProgress,
			InputSummary: `{"filePath":"/tmp/project/sample.txt"}`,
		},
	}
	next := StreamEvent{
		Kind: StreamEventKindTool,
		Tool: &ToolCall{
			CallID:       "tool-1",
			Name:         "Read",
			Kind:         ToolKindRead,
			Status:       ToolStatusCompleted,
			InputSummary: "/tmp/project/sample.txt",
		},
	}

	merged := MergeStreamEvent(existing, next)

	assert.Equal(t, ToolKindRead, merged.Tool.Kind)
	assert.Equal(t, "UnknownTool", merged.Tool.Name)
	assert.Equal(t, ToolStatusCompleted, merged.Tool.Status)
	assert.Equal(t, "/tmp/project/sample.txt", merged.Tool.InputSummary)
}

func TestMergeStreamEventPreservesFailureStatusWhileKeepingSpecificKind(t *testing.T) {
	existing := StreamEvent{
		Kind: StreamEventKindTool,
		Tool: &ToolCall{
			CallID:       "tool-1",
			Name:         "Bash",
			Kind:         ToolKindShell,
			Status:       ToolStatusInProgress,
			InputSummary: "pwd",
		},
	}
	next := StreamEvent{
		Kind: StreamEventKindTool,
		Tool: &ToolCall{
			CallID:    "tool-1",
			Name:      "tool_result",
			Kind:      ToolKindOther,
			Status:    ToolStatusFailed,
			ErrorText: "permission denied",
		},
	}

	merged := MergeStreamEvent(existing, next)

	assert.Equal(t, ToolKindShell, merged.Tool.Kind)
	assert.Equal(t, "Bash", merged.Tool.Name)
	assert.Equal(t, ToolStatusFailed, merged.Tool.Status)
	assert.Equal(t, "permission denied", merged.Tool.ErrorText)
}

func TestMergeStreamEventMergesMCPPayloadAndKeepsDebugFieldsSanitized(t *testing.T) {
	existingTool := NewMCPToolCall(MCPToolCallParams{
		CallID:    "item_22",
		Server:    "pencil",
		Tool:      "get_editor_state",
		Status:    ToolStatusInProgress,
		Arguments: map[string]any{"include_schema": true},
	})
	nextTool := NewMCPToolCall(MCPToolCallParams{
		CallID:     "item_22",
		Server:     "pencil",
		Tool:       "get_editor_state",
		Status:     ToolStatusCompleted,
		DurationMS: 920,
		Arguments:  map[string]any{"include_schema": true},
		Content: []any{
			map[string]any{"type": "text", "text": "Loaded the editor schema."},
			map[string]any{"type": "image", "data": "AAA", "mimeType": "image/png"},
		},
		StructuredContent: map[string]any{"selection": "canvas-root"},
	})

	merged := MergeStreamEvent(
		StreamEvent{Kind: StreamEventKindTool, Raw: existingTool.MCP.DebugJSON, Tool: &existingTool},
		StreamEvent{Kind: StreamEventKindTool, Raw: nextTool.MCP.DebugJSON, Tool: &nextTool},
	)

	assert.Equal(t, ToolKindMCP, merged.Tool.Kind)
	assert.Equal(t, ToolStatusCompleted, merged.Tool.Status)
	assert.Equal(t, int64(920), merged.Tool.DurationMS)
	assert.Equal(t, "pencil.get_editor_state", merged.Tool.InputSummary)
	assert.Equal(t, "Loaded the editor schema.", merged.Tool.OutputText)
	if assert.NotNil(t, merged.Tool.MCP) {
		assert.Equal(t, `{"include_schema":true}`, merged.Tool.MCP.ArgumentsJSON)
		assert.Equal(t, `{"selection":"canvas-root"}`, merged.Tool.MCP.StructuredContentJSON)
		if assert.Len(t, merged.Tool.MCP.OutputBlocks, 2) {
			assert.Equal(t, MCPOutputBlockTypeText, merged.Tool.MCP.OutputBlocks[0].Type)
			assert.Equal(t, MCPOutputBlockTypeImage, merged.Tool.MCP.OutputBlocks[1].Type)
			assert.Equal(t, "data:image/png;base64,AAA", merged.Tool.MCP.OutputBlocks[1].DataURL)
		}
	}
	assert.NotContains(t, merged.Raw, "data:image")
	assert.NotContains(t, merged.Tool.RawOutputJSON, "data:image")
}

func TestToolDisplayLabelUsesSharedKindsAndPrettifiedNames(t *testing.T) {
	tests := []struct {
		name string
		tool ToolCall
		want string
	}{
		{
			name: "search kind",
			tool: ToolCall{Kind: ToolKindSearch, Name: "Grep"},
			want: "search",
		},
		{
			name: "fetch kind",
			tool: ToolCall{Kind: ToolKindFetch, Name: "WebFetch"},
			want: "fetch",
		},
		{
			name: "mcp kind",
			tool: ToolCall{Kind: ToolKindMCP, Name: "get_editor_state"},
			want: "mcp",
		},
		{
			name: "web fetch fallback",
			tool: ToolCall{Kind: ToolKindOther, Name: "WebFetch"},
			want: "web fetch",
		},
		{
			name: "todo write fallback",
			tool: ToolCall{Kind: ToolKindOther, Name: "TodoWrite"},
			want: "todo write",
		},
		{
			name: "tool result fallback",
			tool: ToolCall{Kind: ToolKindOther, Name: "tool_result"},
			want: "tool result",
		},
		{
			name: "empty fallback",
			tool: ToolCall{Kind: ToolKindOther},
			want: "tool",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, tt.tool.DisplayLabel())
		})
	}
}

func TestStreamEventStableKeyUsesCallIDWhenPresent(t *testing.T) {
	event := StreamEvent{
		Kind: StreamEventKindTool,
		Tool: &ToolCall{
			CallID:       "tool-123",
			Name:         "tool_result",
			Kind:         ToolKindOther,
			InputSummary: "/tmp/project/sample.txt",
		},
	}

	assert.Equal(t, "tool:tool-123", event.StableKey())
}

func TestStreamEventStableKeyFallsBackToKindNameAndSummaryWithoutCallID(t *testing.T) {
	event := StreamEvent{
		Kind: StreamEventKindTool,
		Tool: &ToolCall{
			Name:         "Grep",
			Kind:         ToolKindSearch,
			InputSummary: "theme /tmp/project",
		},
	}

	assert.Equal(t, "tool:search:Grep:theme /tmp/project", event.StableKey())
}

func TestMCPToolDisplaySubjectFallsBackToServerAndTool(t *testing.T) {
	tool := ToolCall{
		Kind: ToolKindMCP,
		MCP: &MCPToolPayload{
			Server: "pencil",
			Tool:   "get_editor_state",
		},
	}

	assert.Equal(t, "pencil.get_editor_state", tool.DisplaySubject())
}
