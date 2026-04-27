package appwire

import (
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
