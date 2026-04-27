import type { AgentChatEventDto } from "@/rpc/types";

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

export function eventSessionId(event: AgentChatEventDto): string | undefined {
  const sessionStatusId = isRecord(event.sessionStatus?.app)
    ? event.sessionStatus.app.id
    : undefined;
  return event.sessionId || sessionStatusId;
}

export function eventSeq(event: AgentChatEventDto): number | undefined {
  return typeof event.seq === "number" && Number.isFinite(event.seq)
    ? event.seq
    : undefined;
}

export function isCommittedAgentChatEvent(event: AgentChatEventDto): boolean {
  const seq = eventSeq(event);
  return seq != null && seq > 0;
}

export function isScopedReplayAgentChatEvent(event: AgentChatEventDto): boolean {
  return !isCommittedAgentChatEvent(event);
}
