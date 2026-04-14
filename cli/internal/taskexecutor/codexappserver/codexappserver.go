package codexappserver

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"github.com/LaLanMo/muxagent/cli/internal/taskexecutor"
)

const (
	initializeRequestID = 1
	threadRequestID     = 2
	turnRequestID       = 3
)

type Executor struct {
	BinaryPath string
}

func New(binaryPath string) *Executor {
	if strings.TrimSpace(binaryPath) == "" {
		binaryPath = "codex"
	}
	return &Executor{BinaryPath: binaryPath}
}

func (e *Executor) Execute(ctx context.Context, req taskexecutor.Request, progress func(taskexecutor.Progress)) (taskexecutor.Result, error) {
	if err := os.MkdirAll(req.ArtifactDir, 0o755); err != nil {
		return taskexecutor.Result{}, err
	}
	if strings.TrimSpace(req.SchemaPath) == "" {
		return taskexecutor.Result{}, errors.New("schema path is required")
	}
	if err := os.MkdirAll(filepath.Dir(req.SchemaPath), 0o755); err != nil {
		return taskexecutor.Result{}, err
	}

	outputPath := filepath.Join(req.ArtifactDir, "output.json")
	outputSchema := taskexecutor.BuildOutputSchema(req)
	if err := taskexecutor.WriteSchema(req.SchemaPath, outputSchema); err != nil {
		return taskexecutor.Result{}, err
	}
	prompt := taskexecutor.AppendOutputContract(req)

	cmd := exec.CommandContext(ctx, e.BinaryPath, "app-server")
	cmd.Dir = req.WorkDir

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return taskexecutor.Result{}, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return taskexecutor.Result{}, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return taskexecutor.Result{}, err
	}

	if err := cmd.Start(); err != nil {
		return taskexecutor.Result{}, fmt.Errorf("start codex app-server: %w", err)
	}

	var (
		stderrBuf bytes.Buffer
		stderrWG  sync.WaitGroup
	)
	stderrWG.Add(1)
	go func() {
		defer stderrWG.Done()
		_, _ = io.Copy(&stderrBuf, stderr)
	}()

	encoder := json.NewEncoder(stdin)
	decoder := json.NewDecoder(stdout)
	state := newStreamState()
	resumeThreadID := taskexecutor.ResumeTargetSessionID(req)

	if err := writeMessage(encoder, map[string]interface{}{
		"id":     initializeRequestID,
		"method": "initialize",
		"params": map[string]interface{}{
			"clientInfo": map[string]interface{}{
				"name":    "muxagent",
				"title":   "MuxAgent CLI",
				"version": "dev",
			},
		},
	}); err != nil {
		stopCommand(cmd)
		stderrWG.Wait()
		return taskexecutor.Result{}, err
	}

	threadID := ""
	turnID := ""
	turnCompleted := false
	turnFailedMessage := ""
	finalText := ""
	stdinClosed := false

	threadRequest := buildThreadRequest(req, resumeThreadID)
	turnRequest := map[string]interface{}{
		"id":     turnRequestID,
		"method": "turn/start",
		"params": map[string]interface{}{
			"threadId":     nil,
			"input":        []map[string]interface{}{{"type": "text", "text": prompt}},
			"outputSchema": outputSchema,
		},
	}
	threadRequestSent := false
	turnRequestSent := false

	for {
		var raw json.RawMessage
		if err := decoder.Decode(&raw); err != nil {
			if errors.Is(err, io.EOF) {
				break
			}
			stopCommand(cmd)
			stderrWG.Wait()
			return taskexecutor.Result{}, fmt.Errorf("invalid codex app-server json: %w", err)
		}

		message, err := decodeMessage(raw)
		if err != nil {
			stopCommand(cmd)
			stderrWG.Wait()
			return taskexecutor.Result{}, err
		}

		if responseIDEquals(message.ID, initializeRequestID) {
			if message.Error != nil {
				stopCommand(cmd)
				stderrWG.Wait()
				return taskexecutor.Result{}, rpcError(message.Error)
			}
			if err := writeMessage(encoder, map[string]interface{}{
				"method": "initialized",
				"params": map[string]interface{}{},
			}); err != nil {
				stopCommand(cmd)
				stderrWG.Wait()
				return taskexecutor.Result{}, err
			}
			if err := writeMessage(encoder, threadRequest); err != nil {
				stopCommand(cmd)
				stderrWG.Wait()
				return taskexecutor.Result{}, err
			}
			threadRequestSent = true
			continue
		}

		if responseIDEquals(message.ID, threadRequestID) {
			if message.Error != nil {
				stopCommand(cmd)
				stderrWG.Wait()
				return taskexecutor.Result{}, rpcError(message.Error)
			}
			threadID = extractThreadID(message.Result)
			if threadID == "" {
				stopCommand(cmd)
				stderrWG.Wait()
				return taskexecutor.Result{}, errors.New("codex app-server thread response is missing thread.id")
			}
			if resumeThreadID != "" && threadID != resumeThreadID {
				stopCommand(cmd)
				stderrWG.Wait()
				return taskexecutor.Result{}, fmt.Errorf("codex app-server resume switched threads: expected %q, got %q", resumeThreadID, threadID)
			}
			if progress != nil {
				progress(taskexecutor.Progress{SessionID: threadID})
			}
			params := turnRequest["params"].(map[string]interface{})
			params["threadId"] = threadID
			if err := writeMessage(encoder, turnRequest); err != nil {
				stopCommand(cmd)
				stderrWG.Wait()
				return taskexecutor.Result{}, err
			}
			turnRequestSent = true
			continue
		}

		if responseIDEquals(message.ID, turnRequestID) {
			if message.Error != nil {
				stopCommand(cmd)
				stderrWG.Wait()
				return taskexecutor.Result{}, rpcError(message.Error)
			}
			if turnID == "" {
				turnID = extractTurnID(message.Result)
			}
			continue
		}

		if message.Method == "" {
			continue
		}
		if !threadRequestSent {
			continue
		}

		nextTurnID := discoverTurnID(message.Method, message.Params)
		if turnID == "" && turnRequestSent && nextTurnID != "" {
			turnID = nextTurnID
		}
		if turnID == "" {
			continue
		}

		events, completed, failedMessage, messageText := parseNotification(raw, message.Method, message.Params, turnID, state)
		if failedMessage != "" {
			turnFailedMessage = failedMessage
		}
		if messageText != "" {
			finalText = messageText
		}
		if progress != nil && len(events) > 0 {
			progress(taskexecutor.Progress{
				Message:   summarizeEvents(events),
				SessionID: coalesceSessionID(threadID, resumeThreadID),
				Events:    events,
			})
		}
		if completed && !stdinClosed {
			turnCompleted = true
			stdinClosed = true
			_ = stdin.Close()
		}
	}

	waitErr := cmd.Wait()
	stderrWG.Wait()
	stderrText := strings.TrimSpace(stderrBuf.String())
	if waitErr != nil {
		if stderrText != "" {
			return taskexecutor.Result{}, fmt.Errorf("%w: %s", waitErr, stderrText)
		}
		return taskexecutor.Result{}, waitErr
	}
	if !turnCompleted {
		if turnFailedMessage != "" {
			return taskexecutor.Result{}, errors.New(turnFailedMessage)
		}
		if stderrText != "" {
			return taskexecutor.Result{}, fmt.Errorf("codex app-server ended before turn completed: %s", stderrText)
		}
		return taskexecutor.Result{}, errors.New("codex app-server ended before turn completed")
	}
	if turnFailedMessage != "" {
		if stderrText != "" {
			return taskexecutor.Result{}, fmt.Errorf("%s: %s", turnFailedMessage, stderrText)
		}
		return taskexecutor.Result{}, errors.New(turnFailedMessage)
	}
	if strings.TrimSpace(finalText) == "" {
		if stderrText != "" {
			return taskexecutor.Result{}, fmt.Errorf("codex app-server completed without final assistant output: %s", stderrText)
		}
		return taskexecutor.Result{}, errors.New("codex app-server completed without final assistant output")
	}

	outputBytes, err := canonicalJSON([]byte(finalText))
	if err != nil {
		return taskexecutor.Result{}, fmt.Errorf("invalid codex app-server structured output: %w", err)
	}
	if err := os.WriteFile(outputPath, outputBytes, 0o644); err != nil {
		return taskexecutor.Result{}, err
	}

	result, err := taskexecutor.ParseOutputEnvelope(req, outputBytes)
	if err != nil {
		return taskexecutor.Result{}, err
	}
	result.SessionID = coalesceSessionID(threadID, resumeThreadID)
	return result, nil
}

type rpcMessage struct {
	ID     interface{}      `json:"id"`
	Method string           `json:"method"`
	Params map[string]any   `json:"params"`
	Result map[string]any   `json:"result"`
	Error  *rpcErrorPayload `json:"error"`
}

type rpcErrorPayload struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type streamState struct {
	messageText      map[string]string
	messagePhase     map[string]string
	mcpCalls         map[string]mcpToolState
	reasoningSummary map[string][]string
}

type mcpToolState struct {
	Server    string
	Tool      string
	Arguments any
}

func newStreamState() *streamState {
	return &streamState{
		messageText:      map[string]string{},
		messagePhase:     map[string]string{},
		mcpCalls:         map[string]mcpToolState{},
		reasoningSummary: map[string][]string{},
	}
}

func buildThreadRequest(req taskexecutor.Request, resumeThreadID string) map[string]interface{} {
	if resumeThreadID != "" {
		return map[string]interface{}{
			"id":     threadRequestID,
			"method": "thread/resume",
			"params": map[string]interface{}{
				"threadId": resumeThreadID,
			},
		}
	}
	return map[string]interface{}{
		"id":     threadRequestID,
		"method": "thread/start",
		"params": map[string]interface{}{
			"cwd":            req.WorkDir,
			"approvalPolicy": "never",
			"sandbox":        "danger-full-access",
		},
	}
}

func parseNotification(raw json.RawMessage, method string, params map[string]any, turnID string, state *streamState) ([]taskexecutor.StreamEvent, bool, string, string) {
	if !matchesTurn(method, params, turnID) {
		return nil, false, "", ""
	}

	switch method {
	case "turn/plan/updated":
		plan := parsePlanSnapshot(params, turnID)
		if plan == nil {
			return nil, false, "", ""
		}
		return []taskexecutor.StreamEvent{{
			Kind: taskexecutor.StreamEventKindPlan,
			Raw:  strings.TrimSpace(string(raw)),
			Plan: plan,
		}}, false, "", ""
	case "thread/tokenUsage/updated":
		usage := parseUsageSnapshot(params)
		if usage == nil {
			return nil, false, "", ""
		}
		return []taskexecutor.StreamEvent{{
			Kind:  taskexecutor.StreamEventKindUsage,
			Raw:   strings.TrimSpace(string(raw)),
			Usage: usage,
		}}, false, "", ""
	case "turn/completed":
		status := strings.TrimSpace(asString(asMap(params["turn"])["status"]))
		if status == "failed" {
			return nil, true, extractTurnError(params), ""
		}
		if status == "interrupted" {
			return nil, true, "codex app-server turn interrupted", ""
		}
		return nil, true, "", ""
	case "item/agentMessage/delta":
		itemID := strings.TrimSpace(asString(params["itemId"]))
		if itemID == "" {
			return nil, false, "", ""
		}
		state.messageText[itemID] += asString(params["delta"])
		if strings.EqualFold(strings.TrimSpace(state.messagePhase[itemID]), "final_answer") {
			return nil, false, "", ""
		}
		event := buildAgentMessageEvent(strings.TrimSpace(string(raw)), itemID, state.messagePhase[itemID], state.messageText[itemID])
		if event == nil {
			return nil, false, "", ""
		}
		return []taskexecutor.StreamEvent{*event}, false, "", ""
	case "item/mcpToolCall/progress":
		event := parseMCPToolProgressEvent(raw, params, state)
		if event == nil {
			return nil, false, "", ""
		}
		return []taskexecutor.StreamEvent{*event}, false, "", ""
	case "item/reasoning/summaryTextDelta":
		event := parseReasoningSummaryDeltaEvent(raw, params, state)
		if event == nil {
			return nil, false, "", ""
		}
		return []taskexecutor.StreamEvent{*event}, false, "", ""
	case "item/completed", "item/started":
		events, messageText := parseItemEvents(raw, method, params, state)
		if len(events) == 0 {
			return nil, false, "", messageText
		}
		return events, false, "", messageText
	default:
		return nil, false, "", ""
	}
}

func parseItemEvents(raw json.RawMessage, method string, params map[string]any, state *streamState) ([]taskexecutor.StreamEvent, string) {
	item := asMap(params["item"])
	itemType := strings.TrimSpace(asString(item["type"]))
	if itemType == "" {
		return nil, ""
	}
	rememberItemState(item, state)

	switch itemType {
	case "agentMessage":
		event, messageText := parseAgentMessageItemEvent(raw, method, item, state)
		if event == nil {
			return nil, messageText
		}
		return []taskexecutor.StreamEvent{*event}, messageText
	case "reasoning":
		event := parseReasoningItemEvent(raw, item, state)
		if event == nil {
			return nil, ""
		}
		return []taskexecutor.StreamEvent{*event}, ""
	case "mcpToolCall":
		event := parseMCPToolItemEvent(raw, method, item, state)
		if event == nil {
			return nil, ""
		}
		return []taskexecutor.StreamEvent{*event}, ""
	case "commandExecution":
		tool := &taskexecutor.ToolCall{
			CallID:       asString(item["id"]),
			Name:         "command_execution",
			Kind:         taskexecutor.ToolKindShell,
			Title:        "Run command",
			Status:       normalizeToolStatus(asString(item["status"]), method),
			InputSummary: asString(item["command"]),
			OutputText:   asString(item["aggregatedOutput"]),
		}
		if exitCode, ok := asInt64(item["exitCode"]); ok && exitCode != 0 {
			tool.Status = taskexecutor.ToolStatusFailed
			tool.ErrorText = fmt.Sprintf("exit code %d", exitCode)
		}
		return []taskexecutor.StreamEvent{{
			Kind: taskexecutor.StreamEventKindTool,
			Raw:  strings.TrimSpace(string(raw)),
			Tool: tool,
		}}, ""
	case "fileChange":
		paths := make([]string, 0, len(asSlice(item["changes"])))
		summaries := make([]string, 0, len(asSlice(item["changes"])))
		for _, rawChange := range asSlice(item["changes"]) {
			change := asMap(rawChange)
			path := asString(change["path"])
			if path == "" {
				continue
			}
			paths = append(paths, path)
			summaries = append(summaries, summarizeChangedPath(change))
		}
		if len(paths) == 0 {
			return nil, ""
		}
		return []taskexecutor.StreamEvent{{
			Kind: taskexecutor.StreamEventKindTool,
			Raw:  strings.TrimSpace(string(raw)),
			Tool: &taskexecutor.ToolCall{
				CallID:       asString(item["id"]),
				Name:         "file_change",
				Kind:         taskexecutor.ToolKindFileChange,
				Title:        "Changed files",
				Status:       normalizeToolStatus(asString(item["status"]), method),
				InputSummary: strings.Join(summaries, ", "),
				Paths:        paths,
			},
		}}, ""
	case "webSearch":
		return []taskexecutor.StreamEvent{{
			Kind: taskexecutor.StreamEventKindTool,
			Raw:  strings.TrimSpace(string(raw)),
			Tool: &taskexecutor.ToolCall{
				CallID:       asString(item["id"]),
				Name:         "web_search",
				Kind:         taskexecutor.ToolKindFetch,
				Title:        "web search",
				Status:       normalizeToolStatus(asString(item["status"]), method),
				InputSummary: codexWebSearchSummary(item),
			},
		}}, ""
	default:
		return nil, ""
	}
}

func parseAgentMessageItemEvent(raw json.RawMessage, method string, item map[string]any, state *streamState) (*taskexecutor.StreamEvent, string) {
	itemID := strings.TrimSpace(asString(item["id"]))
	if itemID == "" {
		return nil, ""
	}
	text := strings.TrimSpace(asString(item["text"]))
	if text == "" {
		text = strings.TrimSpace(state.messageText[itemID])
	}
	if text != "" {
		state.messageText[itemID] = text
	}
	phase := strings.TrimSpace(asString(item["phase"]))
	if phase == "" {
		phase = state.messagePhase[itemID]
	} else {
		state.messagePhase[itemID] = phase
	}
	event := buildAgentMessageEvent(strings.TrimSpace(string(raw)), itemID, phase, text)
	if event == nil {
		return nil, state.messageText[itemID]
	}
	return event, state.messageText[itemID]
}

func parseReasoningItemEvent(raw json.RawMessage, item map[string]any, state *streamState) *taskexecutor.StreamEvent {
	itemID := strings.TrimSpace(asString(item["id"]))
	if itemID == "" {
		return nil
	}
	summaries := state.reasoningSummary[itemID]
	if len(summaries) == 0 {
		summaries = normalizeStringSlice(asSlice(item["summary"]))
		if len(summaries) > 0 {
			state.reasoningSummary[itemID] = summaries
		}
	}
	return buildReasoningSummaryEvent(strings.TrimSpace(string(raw)), itemID, summaries)
}

func parseMCPToolItemEvent(raw json.RawMessage, method string, item map[string]any, state *streamState) *taskexecutor.StreamEvent {
	itemID := strings.TrimSpace(asString(item["id"]))
	if itemID == "" {
		return nil
	}
	meta := state.mcpCalls[itemID]
	server := firstNonEmptyString(strings.TrimSpace(asString(item["server"])), meta.Server)
	toolName := firstNonEmptyString(strings.TrimSpace(asString(item["tool"])), meta.Tool)
	arguments := item["arguments"]
	if arguments == nil {
		arguments = meta.Arguments
	}
	durationMS, _ := asInt64(item["durationMs"])
	result := asMap(item["result"])
	tool := taskexecutor.NewMCPToolCall(taskexecutor.MCPToolCallParams{
		CallID:            itemID,
		Server:            server,
		Tool:              toolName,
		Status:            normalizeToolStatus(asString(item["status"]), method),
		DurationMS:        durationMS,
		Arguments:         arguments,
		Content:           toAnySlice(asSlice(result["content"])),
		StructuredContent: firstNonNil(result["structuredContent"], result["structured_content"]),
		ErrorText:         codexMCPErrorText(item),
	})
	return &taskexecutor.StreamEvent{
		Kind: taskexecutor.StreamEventKindTool,
		Raw:  tool.MCP.DebugJSON,
		Tool: &tool,
	}
}

func parseMCPToolProgressEvent(raw json.RawMessage, params map[string]any, state *streamState) *taskexecutor.StreamEvent {
	itemID := strings.TrimSpace(asString(params["itemId"]))
	message := strings.TrimSpace(asString(params["message"]))
	if itemID == "" || message == "" {
		return nil
	}
	meta := state.mcpCalls[itemID]
	tool := taskexecutor.NewMCPToolCall(taskexecutor.MCPToolCallParams{
		CallID:    itemID,
		Server:    meta.Server,
		Tool:      meta.Tool,
		Status:    taskexecutor.ToolStatusInProgress,
		Arguments: meta.Arguments,
		Content: []any{
			map[string]any{"type": "text", "text": message},
		},
	})
	return &taskexecutor.StreamEvent{
		Kind: taskexecutor.StreamEventKindTool,
		Raw:  tool.MCP.DebugJSON,
		Tool: &tool,
	}
}

func parseReasoningSummaryDeltaEvent(raw json.RawMessage, params map[string]any, state *streamState) *taskexecutor.StreamEvent {
	itemID := strings.TrimSpace(asString(params["itemId"]))
	summaryIndex, ok := asInt64(params["summaryIndex"])
	if itemID == "" || !ok || summaryIndex < 0 {
		return nil
	}
	summaries := ensureStringSliceLen(state.reasoningSummary[itemID], int(summaryIndex)+1)
	summaries[summaryIndex] += asString(params["delta"])
	state.reasoningSummary[itemID] = summaries
	return buildReasoningSummaryEvent(strings.TrimSpace(string(raw)), itemID, summaries)
}

func rememberItemState(item map[string]any, state *streamState) {
	itemID := strings.TrimSpace(asString(item["id"]))
	if itemID == "" {
		return
	}
	switch strings.TrimSpace(asString(item["type"])) {
	case "agentMessage":
		if phase := strings.TrimSpace(asString(item["phase"])); phase != "" {
			state.messagePhase[itemID] = phase
		}
		if text := strings.TrimSpace(asString(item["text"])); text != "" {
			state.messageText[itemID] = text
		}
	case "mcpToolCall":
		state.mcpCalls[itemID] = mcpToolState{
			Server:    strings.TrimSpace(asString(item["server"])),
			Tool:      strings.TrimSpace(asString(item["tool"])),
			Arguments: item["arguments"],
		}
	case "reasoning":
		if summaries := normalizeStringSlice(asSlice(item["summary"])); len(summaries) > 0 {
			state.reasoningSummary[itemID] = summaries
		}
	}
}

func buildAgentMessageEvent(raw, itemID, phase, text string) *taskexecutor.StreamEvent {
	if summary, ok := codexAgentEnvelopeSummary(text); ok {
		if summary == "" {
			return nil
		}
		text = summary
	}
	text = strings.TrimSpace(text)
	if text == "" {
		return nil
	}
	partID := "text"
	if strings.TrimSpace(phase) != "" {
		partID = "phase:" + strings.TrimSpace(phase)
	}
	return &taskexecutor.StreamEvent{
		Kind: taskexecutor.StreamEventKindMessage,
		Raw:  raw,
		Message: &taskexecutor.MessagePart{
			MessageID: itemID,
			PartID:    partID,
			Role:      taskexecutor.MessageRoleAssistant,
			Type:      taskexecutor.MessagePartTypeText,
			Text:      text,
		},
	}
}

func buildReasoningSummaryEvent(raw, itemID string, summaries []string) *taskexecutor.StreamEvent {
	text := strings.TrimSpace(strings.Join(nonEmptyStrings(summaries), "\n\n"))
	if text == "" {
		return nil
	}
	return &taskexecutor.StreamEvent{
		Kind: taskexecutor.StreamEventKindMessage,
		Raw:  raw,
		Message: &taskexecutor.MessagePart{
			MessageID: itemID,
			PartID:    "summary",
			Role:      taskexecutor.MessageRoleAssistant,
			Type:      taskexecutor.MessagePartTypeReasoning,
			Text:      text,
		},
	}
}

func writeMessage(encoder *json.Encoder, payload interface{}) error {
	return encoder.Encode(payload)
}

func decodeMessage(raw json.RawMessage) (rpcMessage, error) {
	var message rpcMessage
	if err := json.Unmarshal(raw, &message); err != nil {
		return rpcMessage{}, fmt.Errorf("invalid codex app-server json: %w", err)
	}
	return message, nil
}

func responseIDEquals(value interface{}, want int) bool {
	switch item := value.(type) {
	case float64:
		return int(item) == want
	case int:
		return item == want
	default:
		return false
	}
}

func extractThreadID(result map[string]any) string {
	return asString(asMap(result["thread"])["id"])
}

func extractTurnID(result map[string]any) string {
	return asString(asMap(result["turn"])["id"])
}

func discoverTurnID(method string, params map[string]any) string {
	switch method {
	case "turn/started", "turn/completed":
		return asString(asMap(params["turn"])["id"])
	default:
		return asString(params["turnId"])
	}
}

func matchesTurn(method string, params map[string]any, turnID string) bool {
	switch method {
	case "turn/started", "turn/completed":
		return asString(asMap(params["turn"])["id"]) == turnID
	default:
		return asString(params["turnId"]) == turnID
	}
}

func parsePlanSnapshot(params map[string]any, turnID string) *taskexecutor.PlanSnapshot {
	rawPlan := asSlice(params["plan"])
	if len(rawPlan) == 0 {
		return nil
	}
	steps := make([]taskexecutor.PlanStep, 0, len(rawPlan))
	for _, rawStep := range rawPlan {
		step := asMap(rawStep)
		text := strings.TrimSpace(asString(step["step"]))
		if text == "" {
			continue
		}
		steps = append(steps, taskexecutor.PlanStep{
			Text:   text,
			Status: normalizePlanStatus(asString(step["status"])),
		})
	}
	if len(steps) == 0 {
		return nil
	}
	return &taskexecutor.PlanSnapshot{
		PlanID: turnID,
		Steps:  steps,
	}
}

func parseUsageSnapshot(params map[string]any) *taskexecutor.UsageSnapshot {
	usage := asMap(params["tokenUsage"])
	if len(usage) == 0 {
		return nil
	}
	total := asMap(usage["total"])
	if len(total) == 0 {
		total = asMap(usage["last"])
	}
	if len(total) == 0 {
		return nil
	}
	inputTokens, _ := asInt64(total["inputTokens"])
	cachedInputTokens, _ := asInt64(total["cachedInputTokens"])
	outputTokens, _ := asInt64(total["outputTokens"])
	totalTokens, _ := asInt64(total["totalTokens"])
	if totalTokens == 0 {
		totalTokens = inputTokens + outputTokens
	}
	return &taskexecutor.UsageSnapshot{
		InputTokens:       inputTokens,
		CachedInputTokens: cachedInputTokens,
		OutputTokens:      outputTokens,
		TotalTokens:       totalTokens,
	}
}

func extractTurnError(params map[string]any) string {
	turn := asMap(params["turn"])
	errPayload := asMap(turn["error"])
	message := strings.TrimSpace(asString(errPayload["message"]))
	if message != "" {
		return message
	}
	return "codex app-server turn failed"
}

func normalizeToolStatus(status, method string) taskexecutor.ToolStatus {
	switch strings.TrimSpace(status) {
	case "inProgress":
		return taskexecutor.ToolStatusInProgress
	case "completed":
		return taskexecutor.ToolStatusCompleted
	case "failed", "declined":
		return taskexecutor.ToolStatusFailed
	}
	switch method {
	case "item/started":
		return taskexecutor.ToolStatusInProgress
	case "item/completed":
		return taskexecutor.ToolStatusCompleted
	default:
		return taskexecutor.ToolStatusPending
	}
}

func normalizePlanStatus(status string) string {
	switch strings.TrimSpace(status) {
	case "inProgress":
		return "in_progress"
	case "completed":
		return "completed"
	default:
		return "pending"
	}
}

func rpcError(payload *rpcErrorPayload) error {
	if payload == nil {
		return errors.New("codex app-server request failed")
	}
	return fmt.Errorf("codex app-server error %d: %s", payload.Code, payload.Message)
}

func canonicalJSON(input []byte) ([]byte, error) {
	var payload interface{}
	if err := json.Unmarshal(input, &payload); err != nil {
		return nil, err
	}
	return json.Marshal(payload)
}

func summarizeEvents(events []taskexecutor.StreamEvent) string {
	summaries := make([]string, 0, len(events))
	for _, event := range events {
		if summary := event.Summary(); summary != "" {
			summaries = append(summaries, summary)
		}
	}
	return strings.Join(summaries, "\n")
}

func summarizeChangedPath(change map[string]any) string {
	path := asString(change["path"])
	if path == "" {
		return ""
	}
	label := filepath.Base(path)
	kind := strings.ToLower(strings.TrimSpace(asString(change["kind"])))
	if kind == "" {
		kind = strings.ToLower(strings.TrimSpace(asString(asMap(change["kind"])["type"])))
	}
	switch kind {
	case "add", "create":
		return "A " + label
	case "delete", "remove":
		return "D " + label
	case "rename", "move":
		return "R " + label
	default:
		return "M " + label
	}
}

func codexWebSearchSummary(item map[string]any) string {
	if query := strings.TrimSpace(asString(item["query"])); query != "" {
		return query
	}
	action := asMap(item["action"])
	if query := strings.TrimSpace(asString(action["query"])); query != "" {
		return query
	}
	for _, rawQuery := range asSlice(action["queries"]) {
		if query := strings.TrimSpace(asString(rawQuery)); query != "" {
			return query
		}
	}
	return ""
}

func codexAgentEnvelopeSummary(text string) (string, bool) {
	text = strings.TrimSpace(text)
	if text == "" || !strings.HasPrefix(text, "{") {
		return "", false
	}
	var payload map[string]interface{}
	if err := json.Unmarshal([]byte(text), &payload); err != nil {
		return "", false
	}
	kind := asString(payload["kind"])
	if kind == "" {
		return "", false
	}
	if result := asMap(payload["result"]); len(result) > 0 {
		if summary := asString(result["summary"]); summary != "" {
			return summary, true
		}
	}
	if clarification := asMap(payload["clarification"]); len(clarification) > 0 {
		if questions := asSlice(clarification["questions"]); len(questions) > 0 {
			first := asMap(questions[0])
			if question := asString(first["question"]); question != "" {
				return question, true
			}
		}
	}
	return "", true
}

func toAnySlice(values []interface{}) []any {
	if len(values) == 0 {
		return nil
	}
	items := make([]any, 0, len(values))
	for _, value := range values {
		items = append(items, value)
	}
	return items
}

func codexMCPErrorText(item map[string]any) string {
	errorMap := asMap(item["error"])
	if len(errorMap) == 0 {
		return ""
	}
	return strings.TrimSpace(asString(errorMap["message"]))
}

func ensureStringSliceLen(values []string, size int) []string {
	if len(values) >= size {
		return values
	}
	next := append([]string(nil), values...)
	for len(next) < size {
		next = append(next, "")
	}
	return next
}

func normalizeStringSlice(values []interface{}) []string {
	items := make([]string, 0, len(values))
	for _, value := range values {
		text := strings.TrimSpace(asString(value))
		if text == "" {
			continue
		}
		items = append(items, text)
	}
	return items
}

func nonEmptyStrings(values []string) []string {
	items := make([]string, 0, len(values))
	for _, value := range values {
		text := strings.TrimSpace(value)
		if text == "" {
			continue
		}
		items = append(items, text)
	}
	return items
}

func firstNonNil(values ...interface{}) interface{} {
	for _, value := range values {
		if value != nil {
			return value
		}
	}
	return nil
}

func firstNonEmptyString(values ...string) string {
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			return value
		}
	}
	return ""
}

func asString(value interface{}) string {
	text, _ := value.(string)
	return text
}

func asMap(value interface{}) map[string]any {
	item, _ := value.(map[string]any)
	return item
}

func asSlice(value interface{}) []interface{} {
	items, _ := value.([]interface{})
	return items
}

func asInt64(value interface{}) (int64, bool) {
	switch item := value.(type) {
	case float64:
		return int64(item), true
	case int:
		return int64(item), true
	case int64:
		return item, true
	default:
		return 0, false
	}
}

func coalesceSessionID(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}

func stopCommand(cmd *exec.Cmd) {
	if cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
	_ = cmd.Wait()
}
