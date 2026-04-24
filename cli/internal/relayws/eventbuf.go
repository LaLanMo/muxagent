package relayws

import "github.com/LaLanMo/muxagent/cli/internal/agentchat"

type EventBuffer = agentchat.EventBuffer
type ReplaySnapshot = agentchat.ReplaySnapshot
type ReplayPageSnapshot = agentchat.ReplayPageSnapshot

const defaultEventBufferByteBudget = agentchat.DefaultEventBufferByteBudget

func NewEventBuffer(size int) *EventBuffer {
	return agentchat.NewEventBuffer(size)
}

func NewEventBufferWithByteBudget(size, byteBudget int) *EventBuffer {
	return agentchat.NewEventBufferWithByteBudget(size, byteBudget)
}
