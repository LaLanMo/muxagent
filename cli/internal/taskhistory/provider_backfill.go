package taskhistory

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	appconfig "github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor"
	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor/claudeexec"
)

type jsonlLine struct {
	Number int
	Raw    string
}

func readProviderBackfill(task taskdomain.Task, runtime appconfig.RuntimeID, run taskdomain.NodeRun) (ReadResult, error) {
	switch runtime {
	case appconfig.RuntimeClaudeCode:
		return readClaudeBackfill(task, run)
	case appconfig.RuntimeCodex:
		return readCodexBackfill(task, run)
	default:
		return ReadResult{}, nil
	}
}

func readClaudeBackfill(task taskdomain.Task, run taskdomain.NodeRun) (ReadResult, error) {
	path, err := claudeTranscriptPath(task.ExecutionWorkDir(), run.SessionID)
	if err != nil {
		return ReadResult{}, err
	}
	lines, err := readJSONLLines(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return ReadResult{}, nil
		}
		return ReadResult{}, err
	}

	result := ReadResult{
		SessionID:    run.SessionID,
		Provenance:   string(taskexecutor.StreamEventProvenanceProviderBackfill),
		Completeness: runStatusCompleteness(run.Status),
	}
	var seq uint64
	for _, line := range lines {
		rawLine := line.Raw
		var payload map[string]any
		if err := json.Unmarshal([]byte(rawLine), &payload); err != nil {
			return ReadResult{}, fmt.Errorf("parse claude transcript %s line %d: %w", path, line.Number, err)
		}
		sessionID := firstNonEmpty(strings.TrimSpace(asString(payload["sessionId"])), strings.TrimSpace(asString(payload["session_id"])), run.SessionID)
		providerRecordID := firstNonEmpty(strings.TrimSpace(asString(payload["uuid"])), fmt.Sprintf("line-%06d", line.Number))
		emittedAt := parseProviderTimestamp(asString(payload["timestamp"]))
		events := claudeexec.TranscriptEvents(json.RawMessage([]byte(rawLine)), sessionID)
		for idx, event := range events {
			seq++
			result.Events = append(result.Events, providerEventRecord(event, sessionID, providerRecordID, idx, seq, emittedAt))
			result.LastSeq = seq
			if result.SessionID == "" && sessionID != "" {
				result.SessionID = sessionID
			}
		}
	}
	return result, nil
}

func readCodexBackfill(task taskdomain.Task, run taskdomain.NodeRun) (ReadResult, error) {
	path, err := codexTranscriptPath(run.SessionID)
	if err != nil {
		return ReadResult{}, err
	}
	if path == "" {
		return ReadResult{}, nil
	}
	lines, err := readJSONLLines(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return ReadResult{}, nil
		}
		return ReadResult{}, err
	}

	result := ReadResult{
		SessionID:    run.SessionID,
		Provenance:   string(taskexecutor.StreamEventProvenanceProviderBackfill),
		Completeness: runStatusCompleteness(run.Status),
	}
	var seq uint64
	callState := map[string]taskexecutor.ToolCall{}
	for _, line := range lines {
		rawLine := line.Raw
		var envelope map[string]any
		if err := json.Unmarshal([]byte(rawLine), &envelope); err != nil {
			return ReadResult{}, fmt.Errorf("parse codex transcript %s line %d: %w", path, line.Number, err)
		}
		recordType := strings.TrimSpace(asString(envelope["type"]))
		timestamp := parseProviderTimestamp(asString(envelope["timestamp"]))
		providerRecordID := fmt.Sprintf("%s:%06d", filepath.Base(path), line.Number)
		switch recordType {
		case "session_meta":
			if payload := asMap(envelope["payload"]); len(payload) > 0 {
				result.SessionID = firstNonEmpty(strings.TrimSpace(asString(payload["id"])), result.SessionID)
			}
		case "event_msg":
			payload := asMap(envelope["payload"])
			payloadType := strings.TrimSpace(asString(payload["type"]))
			if payloadType == "task_complete" {
				result.Completeness = "complete"
			}
			sessionID := firstNonEmpty(result.SessionID, run.SessionID)
			if events := codexMCPEventMsgEvents(sessionID, payload, callState); len(events) > 0 {
				for idx, event := range events {
					seq++
					result.Events = append(result.Events, providerEventRecord(event, sessionID, providerRecordID, idx, seq, timestamp))
					result.LastSeq = seq
				}
				continue
			}
			if usage := codexUsageFromEventMsg(rawLine, sessionID, payload); usage != nil {
				seq++
				result.Events = append(result.Events, providerEventRecord(*usage, sessionID, providerRecordID, 0, seq, timestamp))
				result.LastSeq = seq
			}
		case "response_item":
			payload := asMap(envelope["payload"])
			sessionID := firstNonEmpty(result.SessionID, run.SessionID)
			events := codexResponseItemEvents(rawLine, sessionID, payload, callState)
			for idx, event := range events {
				seq++
				result.Events = append(result.Events, providerEventRecord(event, sessionID, providerRecordID, idx, seq, timestamp))
				result.LastSeq = seq
			}
		}
	}
	for idx := range result.Events {
		if result.Events[idx].SessionID == "" {
			result.Events[idx].SessionID = result.SessionID
		}
	}
	return result, nil
}

func providerEventRecord(event taskexecutor.StreamEvent, sessionID, providerRecordID string, providerSubindex int, seq uint64, emittedAt time.Time) EventRecord {
	if event.SessionID == "" {
		event.SessionID = sessionID
	}
	if event.EventID == "" {
		event.EventID = fmt.Sprintf("pbevt_%s_%d", sanitizeProviderID(providerRecordID), providerSubindex)
	}
	event.Seq = seq
	if event.EmittedAt.IsZero() {
		event.EmittedAt = emittedAt
	}
	event.ProviderRecordID = providerRecordID
	event.ProviderSubindex = providerSubindex
	event.Provenance = taskexecutor.StreamEventProvenanceProviderBackfill
	recordedAt := emittedAt
	if recordedAt.IsZero() {
		recordedAt = time.Now().UTC()
	}
	return eventRecordFromExecutor(event, recordedAt.UTC())
}

func claudeTranscriptPath(workDir, sessionID string) (string, error) {
	base, err := claudeBaseDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "projects", escapeClaudeProjectDir(workDir), sessionID+".jsonl"), nil
}

func claudeBaseDir() (string, error) {
	if root := strings.TrimSpace(os.Getenv("CLAUDE_CONFIG_DIR")); root != "" {
		return root, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".claude"), nil
}

func escapeClaudeProjectDir(workDir string) string {
	cleaned := filepath.Clean(strings.TrimSpace(workDir))
	return strings.ReplaceAll(cleaned, string(filepath.Separator), "-")
}

func codexTranscriptPath(sessionID string) (string, error) {
	base, err := codexBaseDir()
	if err != nil {
		return "", err
	}
	patterns := []string{
		filepath.Join(base, "sessions", "*", "*", "*", "*"+sessionID+".jsonl"),
		filepath.Join(base, "archived_sessions", "*"+sessionID+".jsonl"),
	}
	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err != nil {
			return "", err
		}
		if len(matches) > 0 {
			return matches[0], nil
		}
	}
	return "", nil
}

func codexBaseDir() (string, error) {
	if root := strings.TrimSpace(os.Getenv("CODEX_HOME")); root != "" {
		return root, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".codex"), nil
}

func codexResponseItemEvents(rawLine, sessionID string, payload map[string]any, callState map[string]taskexecutor.ToolCall) []taskexecutor.StreamEvent {
	switch strings.TrimSpace(asString(payload["type"])) {
	case "message":
		return codexMessageEvents(rawLine, sessionID, payload)
	case "reasoning":
		if text := strings.TrimSpace(codexReasoningText(payload)); text != "" {
			return []taskexecutor.StreamEvent{{
				Kind:      taskexecutor.StreamEventKindMessage,
				SessionID: sessionID,
				Raw:       rawLine,
				Message: &taskexecutor.MessagePart{
					Role: taskexecutor.MessageRoleAssistant,
					Type: taskexecutor.MessagePartTypeReasoning,
					Text: text,
				},
			}}
		}
	case "function_call", "custom_tool_call":
		call := taskexecutor.ToolCall{
			CallID:       strings.TrimSpace(asString(payload["call_id"])),
			Name:         strings.TrimSpace(asString(payload["name"])),
			Kind:         codexToolKind(strings.TrimSpace(asString(payload["name"]))),
			Title:        codexToolTitle(strings.TrimSpace(asString(payload["name"]))),
			Status:       codexToolStatus(strings.TrimSpace(asString(payload["status"])), taskexecutor.ToolStatusInProgress),
			InputSummary: codexToolInputSummary(payload),
			RawInputJSON: strings.TrimSpace(firstNonEmpty(asString(payload["arguments"]), asString(payload["input"]))),
		}
		if call.CallID != "" {
			callState[call.CallID] = call
		}
		return []taskexecutor.StreamEvent{{
			Kind:      taskexecutor.StreamEventKindTool,
			SessionID: sessionID,
			Raw:       rawLine,
			Tool:      &call,
		}}
	case "function_call_output", "custom_tool_call_output":
		callID := strings.TrimSpace(asString(payload["call_id"]))
		call := callState[callID]
		if call.Kind == taskexecutor.ToolKindMCP {
			call = codexMCPToolOutputSupplement(call, payload)
			if call.CallID != "" {
				callState[call.CallID] = call
			}
			return []taskexecutor.StreamEvent{{
				Kind:      taskexecutor.StreamEventKindTool,
				SessionID: sessionID,
				Raw:       call.MCP.DebugJSON,
				Tool:      &call,
			}}
		}
		if call.CallID == "" {
			call.CallID = callID
			call.Name = "tool_output"
			call.Kind = taskexecutor.ToolKindOther
			call.Title = "Tool result"
		}
		call.Status = taskexecutor.ToolStatusCompleted
		call.OutputText = ""
		call.ErrorText = ""
		call.RawOutputJSON = strings.TrimSpace(asString(payload["output"]))
		call = codexToolOutputDetails(call, payload)
		if call.CallID != "" {
			callState[call.CallID] = call
		}
		return []taskexecutor.StreamEvent{{
			Kind:      taskexecutor.StreamEventKindTool,
			SessionID: sessionID,
			Raw:       rawLine,
			Tool:      &call,
		}}
	}
	return nil
}

func codexMCPEventMsgEvents(sessionID string, payload map[string]any, callState map[string]taskexecutor.ToolCall) []taskexecutor.StreamEvent {
	switch strings.TrimSpace(asString(payload["type"])) {
	case "mcp_tool_call_begin":
		invocation := asMap(payload["invocation"])
		call := taskexecutor.NewMCPToolCall(taskexecutor.MCPToolCallParams{
			CallID:    strings.TrimSpace(asString(payload["call_id"])),
			Server:    strings.TrimSpace(asString(invocation["server"])),
			Tool:      strings.TrimSpace(asString(invocation["tool"])),
			Status:    taskexecutor.ToolStatusInProgress,
			Arguments: invocation["arguments"],
		})
		if call.CallID != "" {
			callState[call.CallID] = call
		}
		return []taskexecutor.StreamEvent{{
			Kind:      taskexecutor.StreamEventKindTool,
			SessionID: sessionID,
			Raw:       call.MCP.DebugJSON,
			Tool:      &call,
		}}
	case "mcp_tool_call_end":
		invocation := asMap(payload["invocation"])
		callID := strings.TrimSpace(asString(payload["call_id"]))
		content, structuredContent, resultIsError, errorText := codexMCPResultParts(payload["result"])
		status := taskexecutor.ToolStatusCompleted
		if resultIsError || strings.TrimSpace(errorText) != "" {
			status = taskexecutor.ToolStatusFailed
		}
		call := taskexecutor.NewMCPToolCall(taskexecutor.MCPToolCallParams{
			CallID:            callID,
			Server:            strings.TrimSpace(asString(invocation["server"])),
			Tool:              strings.TrimSpace(asString(invocation["tool"])),
			Status:            status,
			DurationMS:        parseDurationMS(payload["duration"]),
			Arguments:         invocation["arguments"],
			Content:           content,
			StructuredContent: structuredContent,
			ErrorText:         errorText,
		})
		if existing := callState[callID]; existing.CallID != "" {
			merged := taskexecutor.MergeStreamEvent(
				taskexecutor.StreamEvent{Kind: taskexecutor.StreamEventKindTool, Tool: &existing},
				taskexecutor.StreamEvent{Kind: taskexecutor.StreamEventKindTool, Tool: &call},
			)
			if merged.Tool != nil {
				call = *merged.Tool
			}
		}
		if call.CallID != "" {
			callState[call.CallID] = call
		}
		return []taskexecutor.StreamEvent{{
			Kind:      taskexecutor.StreamEventKindTool,
			SessionID: sessionID,
			Raw:       call.MCP.DebugJSON,
			Tool:      &call,
		}}
	default:
		return nil
	}
}

func codexMCPToolOutputSupplement(call taskexecutor.ToolCall, payload map[string]any) taskexecutor.ToolCall {
	if call.MCP == nil {
		return call
	}
	output := payload["output"]
	supplement := codexMCPResponseItemPreview(output)
	if call.OutputText == "" && supplement != "" {
		call.OutputText = supplement
	}
	if call.ErrorText == "" && call.Status == taskexecutor.ToolStatusFailed && supplement != "" {
		call.ErrorText = supplement
	}
	call.RawOutputJSON = call.MCP.DebugJSON
	return call
}

func codexMCPResultParts(value any) ([]any, any, bool, string) {
	resultMap, isError, errorText := codexMCPResultMap(value)
	if len(resultMap) == 0 {
		return nil, nil, isError, errorText
	}
	content := toAnySlice(asSlice(resultMap["content"]))
	structuredContent := firstNonNil(resultMap["structuredContent"], resultMap["structured_content"])
	isError = isError || asBoolValue(resultMap["isError"]) || asBoolValue(resultMap["is_error"])
	return content, structuredContent, isError, errorText
}

func codexMCPResultMap(value any) (map[string]any, bool, string) {
	switch item := value.(type) {
	case map[string]any:
		if errText := strings.TrimSpace(firstNonEmpty(asString(item["Err"]), asString(item["err"]))); errText != "" {
			return nil, true, errText
		}
		if okValue, exists := item["Ok"]; exists {
			return asMap(okValue), false, ""
		}
		if okValue, exists := item["ok"]; exists {
			return asMap(okValue), false, ""
		}
		return item, false, ""
	case string:
		text := strings.TrimSpace(item)
		if text == "" {
			return nil, false, ""
		}
		var decoded any
		if err := json.Unmarshal([]byte(text), &decoded); err != nil {
			return nil, true, text
		}
		return codexMCPResultMap(decoded)
	default:
		return nil, false, ""
	}
}

func codexMCPResponseItemPreview(value any) string {
	switch item := value.(type) {
	case string:
		text := strings.TrimSpace(item)
		if text == "" {
			return ""
		}
		var decoded any
		if err := json.Unmarshal([]byte(text), &decoded); err != nil {
			return compactText(text)
		}
		return codexMCPResponseItemPreview(decoded)
	case []any:
		parts := make([]string, 0, len(item))
		for _, entry := range item {
			entryMap := asMap(entry)
			switch strings.TrimSpace(asString(entryMap["type"])) {
			case "input_text", "text":
				if text := compactText(asString(entryMap["text"])); text != "" {
					parts = append(parts, text)
				}
			case "input_image", "image":
				parts = append(parts, "image output")
			default:
				if jsonText := compactText(canonicalJSON(entry)); jsonText != "" {
					parts = append(parts, jsonText)
				}
			}
		}
		return strings.Join(parts, "\n\n")
	case map[string]any:
		if text := compactText(firstNonEmpty(asString(item["text"]), asString(item["output"]))); text != "" {
			return text
		}
		return compactText(canonicalJSON(item))
	default:
		return ""
	}
}

func parseDurationMS(value any) int64 {
	switch item := value.(type) {
	case string:
		duration, err := time.ParseDuration(strings.TrimSpace(item))
		if err != nil {
			return 0
		}
		return int64(duration / time.Millisecond)
	case float64:
		return int64(item)
	case int64:
		return item
	case int:
		return int64(item)
	default:
		return 0
	}
}

func codexUsageFromEventMsg(rawLine, sessionID string, payload map[string]any) *taskexecutor.StreamEvent {
	if strings.TrimSpace(asString(payload["type"])) != "token_count" {
		return nil
	}
	info := asMap(payload["info"])
	usage := asMap(info["total_token_usage"])
	if len(usage) == 0 {
		return nil
	}
	event := taskexecutor.StreamEvent{
		Kind:      taskexecutor.StreamEventKindUsage,
		SessionID: sessionID,
		Raw:       rawLine,
		Usage: &taskexecutor.UsageSnapshot{
			InputTokens:       asInt64Value(usage["input_tokens"]),
			CachedInputTokens: asInt64Value(usage["cached_input_tokens"]),
			OutputTokens:      asInt64Value(usage["output_tokens"]),
			TotalTokens:       asInt64Value(usage["total_tokens"]),
		},
	}
	return &event
}

func codexMessageEvents(rawLine, sessionID string, payload map[string]any) []taskexecutor.StreamEvent {
	role := strings.TrimSpace(asString(payload["role"]))
	if role != "assistant" && role != "user" {
		return nil
	}
	content := asSlice(payload["content"])
	events := make([]taskexecutor.StreamEvent, 0, len(content))
	for idx, rawPart := range content {
		part := asMap(rawPart)
		text := strings.TrimSpace(asString(part["text"]))
		if text == "" {
			continue
		}
		partType := taskexecutor.MessagePartTypeText
		switch strings.TrimSpace(asString(part["type"])) {
		case "output_text":
			partType = taskexecutor.MessagePartTypeText
		case "reasoning", "summary_text":
			partType = taskexecutor.MessagePartTypeReasoning
		default:
			partType = taskexecutor.MessagePartTypeText
		}
		events = append(events, taskexecutor.StreamEvent{
			Kind:      taskexecutor.StreamEventKindMessage,
			SessionID: sessionID,
			Raw:       rawLine,
			Message: &taskexecutor.MessagePart{
				MessageID: firstNonEmpty(strings.TrimSpace(asString(payload["id"])), ""),
				PartID:    fmt.Sprintf("part-%d", idx),
				Role:      taskexecutor.MessageRole(role),
				Type:      partType,
				Text:      text,
			},
		})
	}
	return events
}

func codexReasoningText(payload map[string]any) string {
	summary := asSlice(payload["summary"])
	parts := make([]string, 0, len(summary))
	for _, rawEntry := range summary {
		entry := asMap(rawEntry)
		if text := strings.TrimSpace(asString(entry["text"])); text != "" {
			parts = append(parts, text)
		}
	}
	return strings.Join(parts, "\n")
}

func codexToolKind(name string) taskexecutor.ToolKind {
	switch strings.TrimSpace(name) {
	case "exec_command", "shell", "shell_command":
		return taskexecutor.ToolKindShell
	case "apply_patch":
		return taskexecutor.ToolKindEdit
	case "read_thread_terminal", "view_image":
		return taskexecutor.ToolKindRead
	default:
		return taskexecutor.ToolKindOther
	}
}

func codexToolTitle(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "Tool"
	}
	switch name {
	case "exec_command", "shell", "shell_command":
		return "Run command"
	}
	return strings.ReplaceAll(name, "_", " ")
}

func codexToolStatus(raw string, fallback taskexecutor.ToolStatus) taskexecutor.ToolStatus {
	switch strings.TrimSpace(raw) {
	case string(taskexecutor.ToolStatusPending):
		return taskexecutor.ToolStatusPending
	case string(taskexecutor.ToolStatusCompleted):
		return taskexecutor.ToolStatusCompleted
	case string(taskexecutor.ToolStatusFailed):
		return taskexecutor.ToolStatusFailed
	case string(taskexecutor.ToolStatusInProgress):
		return taskexecutor.ToolStatusInProgress
	default:
		return fallback
	}
}

func codexToolInputSummary(payload map[string]any) string {
	input := strings.TrimSpace(firstNonEmpty(asString(payload["arguments"]), asString(payload["input"])))
	if input == "" {
		return ""
	}
	var decoded map[string]any
	if err := json.Unmarshal([]byte(input), &decoded); err != nil {
		return compactText(input)
	}
	for _, key := range []string{"cmd", "command", "message", "path", "query"} {
		if text := strings.TrimSpace(asString(decoded[key])); text != "" {
			return compactText(text)
		}
	}
	if command := asSlice(decoded["command"]); len(command) > 0 {
		parts := make([]string, 0, len(command))
		for _, part := range command {
			if text := strings.TrimSpace(asString(part)); text != "" {
				parts = append(parts, text)
			}
		}
		if len(parts) > 0 {
			if len(parts) >= 3 && (parts[0] == "bash" || parts[0] == "sh" || parts[0] == "zsh") {
				return compactText(parts[len(parts)-1])
			}
			return compactText(strings.Join(parts, " "))
		}
	}
	return compactText(input)
}

func codexToolOutputDetails(base taskexecutor.ToolCall, payload map[string]any) taskexecutor.ToolCall {
	output := strings.TrimSpace(asString(payload["output"]))
	if output == "" {
		return base
	}
	decoded, ok := decodeEmbeddedJSON(output)
	if ok {
		if text := strings.TrimSpace(asString(decoded["output"])); text != "" {
			base.OutputText = text
		}
		if stderr := strings.TrimSpace(asString(decoded["stderr"])); stderr != "" {
			base.ErrorText = stderr
		}
		if exitCode, ok := asOptionalInt64(decoded["exit_code"]); ok && exitCode != 0 {
			base.Status = taskexecutor.ToolStatusFailed
			if base.ErrorText == "" {
				base.ErrorText = fmt.Sprintf("exit code %d", exitCode)
			}
		}
		if success, ok := decoded["success"].(bool); ok && !success {
			base.Status = taskexecutor.ToolStatusFailed
		}
		if base.OutputText == "" && base.ErrorText == "" {
			base.OutputText = compactText(output)
		}
		return base
	}
	if exitCode, ok := parseExitCodePrefix(output); ok && exitCode != 0 {
		base.Status = taskexecutor.ToolStatusFailed
		base.ErrorText = compactText(output)
		return base
	}
	base.OutputText = output
	return base
}

func decodeEmbeddedJSON(raw string) (map[string]any, bool) {
	var decoded map[string]any
	if err := json.Unmarshal([]byte(raw), &decoded); err != nil {
		return nil, false
	}
	return decoded, true
}

func parseExitCodePrefix(raw string) (int64, bool) {
	raw = strings.TrimSpace(raw)
	const prefix = "Exit code:"
	if !strings.HasPrefix(raw, prefix) {
		return 0, false
	}
	fields := strings.Fields(strings.TrimSpace(strings.TrimPrefix(raw, prefix)))
	if len(fields) == 0 {
		return 0, false
	}
	value, err := strconv.ParseInt(fields[0], 10, 64)
	if err != nil {
		return 0, false
	}
	return value, true
}

func asOptionalInt64(value any) (int64, bool) {
	switch item := value.(type) {
	case int64:
		return item, true
	case int:
		return int64(item), true
	case float64:
		return int64(item), true
	default:
		return 0, false
	}
}

func parseProviderTimestamp(raw string) time.Time {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return time.Time{}
	}
	ts, err := time.Parse(time.RFC3339Nano, raw)
	if err != nil {
		return time.Time{}
	}
	return ts.UTC()
}

func sanitizeProviderID(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "unknown"
	}
	replacer := strings.NewReplacer(":", "_", "/", "_", "\\", "_", ".", "_", "-", "_")
	return replacer.Replace(raw)
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func compactText(raw string) string {
	return strings.Join(strings.Fields(strings.TrimSpace(raw)), " ")
}

func runStatusCompleteness(status taskdomain.NodeRunStatus) string {
	if status == taskdomain.NodeRunDone || status == taskdomain.NodeRunFailed || status == taskdomain.NodeRunAwaitingUser {
		return "complete"
	}
	return "open"
}

func readJSONLLines(path string) ([]jsonlLine, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	lines := bytes.Split(data, []byte{'\n'})
	trailingNewline := len(data) == 0 || data[len(data)-1] == '\n'
	result := make([]jsonlLine, 0, len(lines))
	for idx, line := range lines {
		trimmed := bytes.TrimSpace(line)
		if len(trimmed) == 0 {
			continue
		}
		if !json.Valid(trimmed) {
			if idx == len(lines)-1 && !trailingNewline {
				return result, nil
			}
			return nil, fmt.Errorf("invalid jsonl at line %d", idx+1)
		}
		result = append(result, jsonlLine{
			Number: idx + 1,
			Raw:    string(trimmed),
		})
	}
	return result, nil
}

func asMap(value any) map[string]any {
	item, _ := value.(map[string]any)
	return item
}

func asSlice(value any) []any {
	items, _ := value.([]any)
	return items
}

func asString(value any) string {
	text, _ := value.(string)
	return text
}

func asInt64Value(value any) int64 {
	switch item := value.(type) {
	case int64:
		return item
	case int:
		return int64(item)
	case float64:
		return int64(item)
	default:
		return 0
	}
}

func claudeToolResultContent(value any) string {
	switch item := value.(type) {
	case string:
		return item
	case []any:
		parts := make([]string, 0, len(item))
		for _, entry := range item {
			if text := strings.TrimSpace(asString(entry)); text != "" {
				parts = append(parts, text)
			}
		}
		return strings.Join(parts, "\n")
	default:
		return asString(value)
	}
}

func toAnySlice(values []any) []any {
	if len(values) == 0 {
		return nil
	}
	items := make([]any, 0, len(values))
	for _, value := range values {
		items = append(items, value)
	}
	return items
}

func firstNonNil(values ...any) any {
	for _, value := range values {
		if value != nil {
			return value
		}
	}
	return nil
}

func asBoolValue(value any) bool {
	flag, _ := value.(bool)
	return flag
}

func canonicalJSON(value any) string {
	if value == nil {
		return ""
	}
	encoded, err := json.Marshal(value)
	if err != nil {
		return ""
	}
	return string(encoded)
}
