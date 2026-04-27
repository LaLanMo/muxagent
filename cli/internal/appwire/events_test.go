package appwire

import (
	"bytes"
	"encoding/json"
	"reflect"
	"testing"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/acpprotocol"
)

func TestEventJSONRoundTripsCanonicalEnvelope(t *testing.T) {
	at := time.Date(2026, 4, 27, 12, 0, 0, 0, time.UTC)
	categoryMode := "mode"
	categoryModel := "model"

	configOption := acpprotocol.SessionConfigOption{
		ID:           "model",
		Name:         "Model",
		Category:     &categoryModel,
		Type:         "select",
		CurrentValue: "gpt-5.4",
		Options: acpprotocol.SessionConfigSelectOptions{
			Ungrouped: []acpprotocol.SessionConfigSelectOption{{
				Value: "gpt-5.4",
				Name:  "GPT-5.4",
			}},
		},
	}
	modeOption := acpprotocol.SessionConfigOption{
		ID:           "mode",
		Name:         "Mode",
		Category:     &categoryMode,
		Type:         "select",
		CurrentValue: "plan",
		Options: acpprotocol.SessionConfigSelectOptions{
			Ungrouped: []acpprotocol.SessionConfigSelectOption{{
				Value: "plan",
				Name:  "Plan",
			}},
		},
	}

	messageID := "msg-1"
	costCurrency := "USD"
	costAmount := 0.42

	tests := []struct {
		name  string
		event Event
	}{
		{
			name: "message delta",
			event: Event{
				Type:      EventMessageDelta,
				SessionID: "sid",
				Seq:       1,
				At:        at,
				MessagePart: &MessagePartEvent{
					ACP: &acpprotocol.ContentChunk{
						MessageID: &messageID,
						Content:   json.RawMessage(`{"type":"text","text":"hello"}`),
					},
					App: MessagePartEventApp{
						PartID:    "part-1",
						MessageID: messageID,
						Role:      MessageRoleAgent,
						Delta:     "hello",
						PartType:  "text",
						FullText:  "hello",
					},
				},
			},
		},
		{
			name: "tool completed",
			event: Event{
				Type:      EventToolCompleted,
				SessionID: "sid",
				Seq:       2,
				At:        at,
				Tool: &ToolEvent{
					ACP: &acpprotocol.ToolCallUpdate{ToolCallID: "tool-1"},
					App: ToolEventApp{
						PartID:    "part-tool",
						MessageID: "msg-tool",
						CallID:    "tool-1",
						Name:      "read",
						Status:    ToolStatusCompleted,
						Output:    "done",
					},
				},
			},
		},
		{
			name: "session status",
			event: Event{
				Type:      EventSessionStatus,
				SessionID: "sid",
				Seq:       3,
				At:        at,
				SessionInfo: &SessionStatusEvent{App: SessionStatusEventApp{
					ID:        "sid",
					Title:     "Chat",
					Status:    SessionStatusRunning,
					Runtime:   "codex",
					CWD:       "/tmp/project",
					CreatedAt: at,
					UpdatedAt: at,
				}},
			},
		},
		{
			name: "mode changed current mode update",
			event: Event{
				Type:      EventModeChanged,
				SessionID: "sid",
				Seq:       4,
				At:        at,
				ModeChanged: &ModeChangedEvent{
					ACPCurrentMode: &acpprotocol.CurrentModeUpdate{CurrentModeID: "plan"},
					App:            ModeChangedEventApp{CurrentModeID: "plan"},
				},
			},
		},
		{
			name: "mode changed config option update",
			event: Event{
				Type:      EventModeChanged,
				SessionID: "sid",
				Seq:       5,
				At:        at,
				ModeChanged: &ModeChangedEvent{
					ACPConfigOption: &acpprotocol.ConfigOptionUpdate{
						ConfigOptions: []acpprotocol.SessionConfigOption{modeOption},
					},
					App: ModeChangedEventApp{CurrentModeID: "plan"},
				},
			},
		},
		{
			name: "config changed",
			event: Event{
				Type:      EventModelChanged,
				SessionID: "sid",
				Seq:       6,
				At:        at,
				ConfigChanged: &ConfigChangedEvent{
					ACP: &acpprotocol.ConfigOptionUpdate{
						ConfigOptions: []acpprotocol.SessionConfigOption{configOption},
					},
					App: ConfigChangedEventApp{
						ConfigID:     "model",
						CurrentValue: "gpt-5.4",
						Category:     "model",
						Values: []SessionConfigValue{{
							Value: "gpt-5.4",
							Name:  "GPT-5.4",
						}},
					},
				},
			},
		},
		{
			name: "run finished",
			event: Event{
				Type:      EventRunFinished,
				SessionID: "sid",
				Seq:       7,
				At:        at,
				RunFinished: &RunFinishedEvent{App: RunFinishedEventApp{
					StopReason:  "end_turn",
					InputTokens: 1,
				}},
			},
		},
		{
			name: "run failed",
			event: Event{
				Type:      EventRunFailed,
				SessionID: "sid",
				Seq:       8,
				At:        at,
				RunFailed: &RunFailedEvent{App: RunFailedEventApp{
					Error: SessionError{Code: "runtime_error", Message: "failed"},
				}},
			},
		},
		{
			name: "usage",
			event: Event{
				Type:      EventUsageUpdate,
				SessionID: "sid",
				Seq:       9,
				At:        at,
				Usage: &UsageEvent{
					ACP: &acpprotocol.UsageUpdate{
						Used: 12,
						Size: 100,
						Cost: &acpprotocol.UsageCost{Amount: costAmount, Currency: costCurrency},
					},
					App: UsageEventApp{
						ContextUsed:  12,
						ContextSize:  100,
						CostAmount:   &costAmount,
						CostCurrency: &costCurrency,
					},
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			payload, err := json.Marshal(tt.event)
			if err != nil {
				t.Fatalf("Marshal: %v", err)
			}

			var decoded Event
			if err := json.Unmarshal(payload, &decoded); err != nil {
				t.Fatalf("Unmarshal: %v", err)
			}
			if !reflect.DeepEqual(decoded, tt.event) {
				t.Fatalf("decoded = %#v, want %#v\njson: %s", decoded, tt.event, payload)
			}
		})
	}
}

func TestEventStreamItemJSONPreservesEmptyReplayEvents(t *testing.T) {
	tests := []struct {
		name string
		item EventStreamItem
	}{
		{
			name: "event",
			item: EventStreamItem{
				Kind:        EventStreamItemEvent,
				StreamEpoch: 11,
				Event: &Event{
					Type:      EventMessageDelta,
					SessionID: "sid",
					Seq:       7,
					At:        time.Date(2026, 4, 27, 12, 0, 0, 0, time.UTC),
				},
			},
		},
		{
			name: "ok replay",
			item: EventStreamItem{
				Kind:               EventStreamItemReplay,
				Status:             ResyncStatusOK,
				StreamEpoch:        11,
				ReplayedThroughSeq: 7,
				Events: []Event{{
					Type:      EventReasoning,
					SessionID: "sid",
					Seq:       7,
					At:        time.Date(2026, 4, 27, 12, 0, 0, 0, time.UTC),
				}},
			},
		},
		{
			name: "empty gap replay",
			item: EventStreamItem{
				Kind:               EventStreamItemReplay,
				Status:             ResyncStatusGap,
				StreamEpoch:        12,
				ReplayedThroughSeq: 0,
			},
		},
		{
			name: "empty reset replay",
			item: EventStreamItem{
				Kind:               EventStreamItemReplay,
				Status:             ResyncStatusReset,
				StreamEpoch:        13,
				ReplayedThroughSeq: 0,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			payload, err := json.Marshal(tt.item)
			if err != nil {
				t.Fatalf("Marshal: %v", err)
			}
			if tt.item.Kind == EventStreamItemReplay && len(tt.item.Events) == 0 && !bytes.Contains(payload, []byte(`"events":[]`)) {
				t.Fatalf("replay json missing empty events array: %s", payload)
			}
			var decoded EventStreamItem
			if err := json.Unmarshal(payload, &decoded); err != nil {
				t.Fatalf("Unmarshal: %v", err)
			}
			if tt.item.Kind == EventStreamItemReplay && decoded.Events == nil {
				t.Fatalf("decoded replay events nil, want empty slice")
			}
		})
	}
}

func TestEventStreamItemJSONRejectsInvalidContract(t *testing.T) {
	tests := []struct {
		name string
		item EventStreamItem
	}{
		{
			name: "unknown kind",
			item: EventStreamItem{Kind: EventStreamItemKind("legacy")},
		},
		{
			name: "event missing stream epoch",
			item: EventStreamItem{
				Kind:  EventStreamItemEvent,
				Event: &Event{Type: EventMessageDelta},
			},
		},
		{
			name: "event missing event",
			item: EventStreamItem{
				Kind:        EventStreamItemEvent,
				StreamEpoch: 11,
			},
		},
		{
			name: "replay missing stream epoch",
			item: EventStreamItem{
				Kind:   EventStreamItemReplay,
				Status: ResyncStatusOK,
			},
		},
		{
			name: "replay invalid status",
			item: EventStreamItem{
				Kind:        EventStreamItemReplay,
				Status:      ResyncStatus("partial"),
				StreamEpoch: 11,
			},
		},
	}

	for _, tt := range tests {
		t.Run("marshal "+tt.name, func(t *testing.T) {
			if _, err := json.Marshal(tt.item); err == nil {
				t.Fatal("Marshal error = nil, want contract error")
			}
		})
	}

	payloads := []struct {
		name string
		json string
	}{
		{name: "unknown kind", json: `{"kind":"legacy"}`},
		{name: "event missing stream epoch", json: `{"kind":"event","event":{"type":"message.delta","seq":1}}`},
		{name: "event zero stream epoch", json: `{"kind":"event","streamEpoch":0,"event":{"type":"message.delta","seq":1}}`},
		{name: "event missing event", json: `{"kind":"event","streamEpoch":11}`},
		{name: "replay missing status", json: `{"kind":"replay","streamEpoch":11,"replayedThroughSeq":1,"events":[]}`},
		{name: "replay invalid status", json: `{"kind":"replay","status":"partial","streamEpoch":11,"replayedThroughSeq":1,"events":[]}`},
		{name: "replay missing stream epoch", json: `{"kind":"replay","status":"ok","replayedThroughSeq":1,"events":[]}`},
		{name: "replay missing events", json: `{"kind":"replay","status":"ok","streamEpoch":11,"replayedThroughSeq":1}`},
	}

	for _, tt := range payloads {
		t.Run("unmarshal "+tt.name, func(t *testing.T) {
			var item EventStreamItem
			if err := json.Unmarshal([]byte(tt.json), &item); err == nil {
				t.Fatal("Unmarshal error = nil, want contract error")
			}
		})
	}
}
