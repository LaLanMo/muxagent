package appwire

import (
	"bytes"
	"encoding/json"
	"fmt"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/acpprotocol"
)

type EventType string

const (
	EventMessageDelta      EventType = "message.delta"
	EventToolStarted       EventType = "tool.started"
	EventToolUpdated       EventType = "tool.updated"
	EventToolCompleted     EventType = "tool.completed"
	EventToolFailed        EventType = "tool.failed"
	EventReasoning         EventType = "reasoning"
	EventApprovalRequested EventType = "approval.requested"
	EventApprovalReplied   EventType = "approval.replied"
	EventSessionStatus     EventType = "session.status"
	EventRunFailed         EventType = "run.failed"
	EventRunFinished       EventType = "run.finished"
	EventPlanUpdated       EventType = "plan.updated"
	EventModeChanged       EventType = "mode.changed"
	EventModelChanged      EventType = "model.changed"
	EventUsageUpdate       EventType = "usage.update"
)

type MessagePartEventApp struct {
	PartID    string      `json:"partId"`
	MessageID string      `json:"messageId"`
	Role      MessageRole `json:"role,omitempty"`
	Delta     string      `json:"delta"`
	PartType  string      `json:"partType"`
	FullText  string      `json:"fullText"`
}

type MessagePartEvent struct {
	ACP *acpprotocol.ContentChunk `json:"acp,omitempty"`
	App MessagePartEventApp       `json:"app"`
}

type ToolDiff struct {
	Path    string  `json:"path"`
	OldText *string `json:"oldText,omitempty"`
	NewText string  `json:"newText"`
}

type ToolLocation struct {
	Path string `json:"path"`
	Line *int   `json:"line,omitempty"`
}

type ToolEventApp struct {
	PartID          string          `json:"partId"`
	MessageID       string          `json:"messageId"`
	CallID          string          `json:"callId"`
	Name            string          `json:"name"`
	Kind            string          `json:"kind,omitempty"`
	Title           string          `json:"title,omitempty"`
	Status          ToolStatus      `json:"status"`
	Input           *ToolInput      `json:"input,omitempty"`
	InputTruncated  bool            `json:"inputTruncated,omitempty"`
	Output          string          `json:"output,omitempty"`
	OutputTruncated bool            `json:"outputTruncated,omitempty"`
	Error           string          `json:"error,omitempty"`
	ErrorTruncated  bool            `json:"errorTruncated,omitempty"`
	Diffs           []ToolDiff      `json:"diffs,omitempty"`
	DiffsTruncated  bool            `json:"diffsTruncated,omitempty"`
	ClaudeCode      *ClaudeCodeTool `json:"claudeCode,omitempty"`
	Locations       []ToolLocation  `json:"locations,omitempty"`
}

type ToolEvent struct {
	ACP *acpprotocol.ToolCallUpdate `json:"acp,omitempty"`
	App ToolEventApp                `json:"app"`
}

type PlanEntryApp struct {
	Content  string `json:"content"`
	Status   string `json:"status"`
	Priority string `json:"priority"`
}

type PlanEventApp struct {
	Entries []PlanEntryApp `json:"entries"`
}

type PlanEvent struct {
	ACP *acpprotocol.PlanUpdate `json:"acp,omitempty"`
	App PlanEventApp            `json:"app"`
}

type UsageEventApp struct {
	ContextUsed  int64    `json:"contextUsed"`
	ContextSize  int64    `json:"contextSize"`
	CostAmount   *float64 `json:"costAmount,omitempty"`
	CostCurrency *string  `json:"costCurrency,omitempty"`
}

type UsageEvent struct {
	ACP *acpprotocol.UsageUpdate `json:"acp,omitempty"`
	App UsageEventApp            `json:"app"`
}

type RunFinishedEventApp struct {
	StopReason        string `json:"stopReason"`
	InputTokens       int64  `json:"inputTokens,omitempty"`
	OutputTokens      int64  `json:"outputTokens,omitempty"`
	CachedReadTokens  int64  `json:"cachedReadTokens,omitempty"`
	CachedWriteTokens int64  `json:"cachedWriteTokens,omitempty"`
	TotalTokens       int64  `json:"totalTokens,omitempty"`
}

type RunFinishedEvent struct {
	App RunFinishedEventApp `json:"app"`
}

type SessionError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type RunFailedEventApp struct {
	Error SessionError `json:"error"`
}

type RunFailedEvent struct {
	App RunFailedEventApp `json:"app"`
}

type SessionStatusEventApp struct {
	ID        string        `json:"id"`
	Title     string        `json:"title"`
	Status    SessionStatus `json:"status"`
	Model     string        `json:"model,omitempty"`
	Cost      *CostInfo     `json:"cost,omitempty"`
	MachineID string        `json:"machineId,omitempty"`
	Runtime   string        `json:"runtime,omitempty"`
	CWD       string        `json:"cwd,omitempty"`
	Mode      string        `json:"mode,omitempty"`
	CreatedAt time.Time     `json:"createdAt"`
	UpdatedAt time.Time     `json:"updatedAt"`
}

type SessionStatusEvent struct {
	App SessionStatusEventApp `json:"app"`
}

type ModeChangedEventApp struct {
	CurrentModeID string `json:"currentModeId"`
}

type ModeChangedEvent struct {
	ACPCurrentMode  *acpprotocol.CurrentModeUpdate  `json:"-"`
	ACPConfigOption *acpprotocol.ConfigOptionUpdate `json:"-"`
	App             ModeChangedEventApp             `json:"app"`
}

type modeChangedEventWire struct {
	App ModeChangedEventApp `json:"app"`
	ACP json.RawMessage     `json:"acp,omitempty"`
}

func (e ModeChangedEvent) MarshalJSON() ([]byte, error) {
	wire := modeChangedEventWire{App: e.App}

	switch {
	case e.ACPCurrentMode != nil:
		payload, err := json.Marshal(e.ACPCurrentMode)
		if err != nil {
			return nil, err
		}
		wire.ACP = payload
	case e.ACPConfigOption != nil:
		payload, err := json.Marshal(e.ACPConfigOption)
		if err != nil {
			return nil, err
		}
		wire.ACP = payload
	}

	return json.Marshal(wire)
}

func (e *ModeChangedEvent) UnmarshalJSON(data []byte) error {
	var wire modeChangedEventWire
	if err := json.Unmarshal(data, &wire); err != nil {
		return err
	}

	*e = ModeChangedEvent{App: wire.App}
	if len(bytes.TrimSpace(wire.ACP)) == 0 || bytes.Equal(bytes.TrimSpace(wire.ACP), []byte("null")) {
		return nil
	}

	switch {
	case rawObjectHasField(wire.ACP, "currentModeId"):
		var update acpprotocol.CurrentModeUpdate
		if err := json.Unmarshal(wire.ACP, &update); err != nil {
			return err
		}
		e.ACPCurrentMode = &update
	case rawObjectHasField(wire.ACP, "configOptions"):
		var update acpprotocol.ConfigOptionUpdate
		if err := json.Unmarshal(wire.ACP, &update); err != nil {
			return err
		}
		e.ACPConfigOption = &update
	}

	return nil
}

type SessionConfigValue struct {
	Value       string  `json:"value"`
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
}

type ConfigChangedEventApp struct {
	ConfigID     string               `json:"configId"`
	CurrentValue string               `json:"currentValue"`
	Category     string               `json:"category,omitempty"`
	Values       []SessionConfigValue `json:"values,omitempty"`
}

type ConfigChangedEvent struct {
	ACP *acpprotocol.ConfigOptionUpdate `json:"-"`
	App ConfigChangedEventApp           `json:"app"`
}

type configChangedEventWire struct {
	App ConfigChangedEventApp `json:"app"`
	ACP json.RawMessage       `json:"acp,omitempty"`
}

func (e ConfigChangedEvent) MarshalJSON() ([]byte, error) {
	wire := configChangedEventWire{App: e.App}
	if e.ACP != nil {
		payload, err := json.Marshal(e.ACP)
		if err != nil {
			return nil, err
		}
		wire.ACP = payload
	}
	return json.Marshal(wire)
}

func (e *ConfigChangedEvent) UnmarshalJSON(data []byte) error {
	var wire configChangedEventWire
	if err := json.Unmarshal(data, &wire); err != nil {
		return err
	}

	*e = ConfigChangedEvent{App: wire.App}
	if len(bytes.TrimSpace(wire.ACP)) == 0 || bytes.Equal(bytes.TrimSpace(wire.ACP), []byte("null")) {
		return nil
	}

	if rawObjectHasField(wire.ACP, "configOptions") {
		var update acpprotocol.ConfigOptionUpdate
		if err := json.Unmarshal(wire.ACP, &update); err != nil {
			return err
		}
		e.ACP = &update
	}

	return nil
}

type Event struct {
	Type      EventType
	SessionID string
	Seq       uint64
	At        time.Time

	MessagePart   *MessagePartEvent
	Tool          *ToolEvent
	Approval      *ApprovalRequest
	Plan          *PlanEvent
	Usage         *UsageEvent
	RunFinished   *RunFinishedEvent
	RunFailed     *RunFailedEvent
	SessionInfo   *SessionStatusEvent
	ModeChanged   *ModeChangedEvent
	ConfigChanged *ConfigChangedEvent
}

type EventStreamItemKind string

const (
	EventStreamItemReplay EventStreamItemKind = "replay"
	EventStreamItemEvent  EventStreamItemKind = "event"
)

type EventStreamItem struct {
	Kind               EventStreamItemKind `json:"kind"`
	Status             ResyncStatus        `json:"status"`
	StreamEpoch        uint64              `json:"streamEpoch"`
	ReplayedThroughSeq uint64              `json:"replayedThroughSeq"`
	Events             []Event             `json:"events"`
	Event              *Event              `json:"event"`
}

type eventStreamReplayWire struct {
	Kind               EventStreamItemKind `json:"kind"`
	Status             ResyncStatus        `json:"status"`
	StreamEpoch        uint64              `json:"streamEpoch"`
	ReplayedThroughSeq uint64              `json:"replayedThroughSeq"`
	Events             []Event             `json:"events"`
}

type eventStreamEventWire struct {
	Kind        EventStreamItemKind `json:"kind"`
	StreamEpoch uint64              `json:"streamEpoch"`
	Event       *Event              `json:"event"`
}

func (i EventStreamItem) MarshalJSON() ([]byte, error) {
	switch i.Kind {
	case EventStreamItemReplay:
		if !isValidResyncStatus(i.Status) {
			return nil, fmt.Errorf("agentchat stream replay has invalid status %q", i.Status)
		}
		if i.StreamEpoch == 0 {
			return nil, fmt.Errorf("agentchat stream replay missing streamEpoch")
		}
		events := i.Events
		if events == nil {
			events = make([]Event, 0)
		}
		return json.Marshal(eventStreamReplayWire{
			Kind:               i.Kind,
			Status:             i.Status,
			StreamEpoch:        i.StreamEpoch,
			ReplayedThroughSeq: i.ReplayedThroughSeq,
			Events:             events,
		})
	case EventStreamItemEvent:
		if i.StreamEpoch == 0 {
			return nil, fmt.Errorf("agentchat stream event missing streamEpoch")
		}
		if i.Event == nil {
			return nil, fmt.Errorf("agentchat stream event missing event")
		}
		return json.Marshal(eventStreamEventWire{
			Kind:        i.Kind,
			StreamEpoch: i.StreamEpoch,
			Event:       i.Event,
		})
	default:
		return nil, fmt.Errorf("unknown agentchat stream item kind %q", i.Kind)
	}
}

func (i *EventStreamItem) UnmarshalJSON(data []byte) error {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return err
	}
	var head struct {
		Kind EventStreamItemKind `json:"kind"`
	}
	if err := json.Unmarshal(data, &head); err != nil {
		return err
	}

	switch head.Kind {
	case EventStreamItemReplay:
		if _, ok := fields["status"]; !ok {
			return fmt.Errorf("agentchat stream replay missing status")
		}
		if _, ok := fields["streamEpoch"]; !ok {
			return fmt.Errorf("agentchat stream replay missing streamEpoch")
		}
		if _, ok := fields["replayedThroughSeq"]; !ok {
			return fmt.Errorf("agentchat stream replay missing replayedThroughSeq")
		}
		if _, ok := fields["events"]; !ok {
			return fmt.Errorf("agentchat stream replay missing events")
		}
		var wire eventStreamReplayWire
		if err := json.Unmarshal(data, &wire); err != nil {
			return err
		}
		if !isValidResyncStatus(wire.Status) {
			return fmt.Errorf("agentchat stream replay has invalid status %q", wire.Status)
		}
		if wire.StreamEpoch == 0 {
			return fmt.Errorf("agentchat stream replay missing streamEpoch")
		}
		events := wire.Events
		if events == nil {
			events = make([]Event, 0)
		}
		*i = EventStreamItem{
			Kind:               wire.Kind,
			Status:             wire.Status,
			StreamEpoch:        wire.StreamEpoch,
			ReplayedThroughSeq: wire.ReplayedThroughSeq,
			Events:             events,
		}
		return nil
	case EventStreamItemEvent:
		if _, ok := fields["streamEpoch"]; !ok {
			return fmt.Errorf("agentchat stream event missing streamEpoch")
		}
		if _, ok := fields["event"]; !ok {
			return fmt.Errorf("agentchat stream event missing event")
		}
		var wire eventStreamEventWire
		if err := json.Unmarshal(data, &wire); err != nil {
			return err
		}
		if wire.StreamEpoch == 0 {
			return fmt.Errorf("agentchat stream event missing streamEpoch")
		}
		if wire.Event == nil {
			return fmt.Errorf("agentchat stream event missing event")
		}
		*i = EventStreamItem{
			Kind:        wire.Kind,
			StreamEpoch: wire.StreamEpoch,
			Event:       wire.Event,
		}
		return nil
	default:
		return fmt.Errorf("unknown agentchat stream item kind %q", head.Kind)
	}
}

func isValidResyncStatus(status ResyncStatus) bool {
	switch status {
	case ResyncStatusOK, ResyncStatusGap, ResyncStatusReset:
		return true
	default:
		return false
	}
}

type eventEnvelopeWire struct {
	Type          EventType           `json:"type"`
	SessionID     string              `json:"sessionId,omitempty"`
	Seq           uint64              `json:"seq"`
	At            time.Time           `json:"at"`
	MessagePart   *MessagePartEvent   `json:"messagePart,omitempty"`
	Tool          *ToolEvent          `json:"tool,omitempty"`
	Approval      *ApprovalRequest    `json:"approval,omitempty"`
	Plan          *PlanEvent          `json:"plan,omitempty"`
	Usage         *UsageEvent         `json:"usage,omitempty"`
	RunFinished   *RunFinishedEvent   `json:"runFinished,omitempty"`
	RunFailed     *RunFailedEvent     `json:"runFailed,omitempty"`
	SessionInfo   *SessionStatusEvent `json:"sessionStatus,omitempty"`
	ModeChanged   *ModeChangedEvent   `json:"modeChanged,omitempty"`
	ConfigChanged *ConfigChangedEvent `json:"configChanged,omitempty"`
}

func (e Event) MarshalJSON() ([]byte, error) {
	return json.Marshal(eventEnvelopeWire{
		Type:          e.Type,
		SessionID:     e.SessionID,
		Seq:           e.Seq,
		At:            e.At,
		MessagePart:   e.MessagePart,
		Tool:          e.Tool,
		Approval:      e.Approval,
		Plan:          e.Plan,
		Usage:         e.Usage,
		RunFinished:   e.RunFinished,
		RunFailed:     e.RunFailed,
		SessionInfo:   e.SessionInfo,
		ModeChanged:   e.ModeChanged,
		ConfigChanged: e.ConfigChanged,
	})
}

func (e *Event) UnmarshalJSON(data []byte) error {
	var wire eventEnvelopeWire
	if err := json.Unmarshal(data, &wire); err != nil {
		return err
	}

	*e = Event{
		Type:          wire.Type,
		SessionID:     wire.SessionID,
		Seq:           wire.Seq,
		At:            wire.At,
		MessagePart:   wire.MessagePart,
		Tool:          wire.Tool,
		Approval:      wire.Approval,
		Plan:          wire.Plan,
		Usage:         wire.Usage,
		RunFinished:   wire.RunFinished,
		RunFailed:     wire.RunFailed,
		SessionInfo:   wire.SessionInfo,
		ModeChanged:   wire.ModeChanged,
		ConfigChanged: wire.ConfigChanged,
	}
	return nil
}

func rawObjectHasField(raw json.RawMessage, field string) bool {
	if len(bytes.TrimSpace(raw)) == 0 {
		return false
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil {
		return false
	}
	_, ok := fields[field]
	return ok
}
