import type { SessionHistoryEventDto, TaskRunHistoryResult } from "@/rpc/types";
import {
  normalizeLiveOutputLine,
  normalizeStreamEvent,
  type SessionHistoryEvent,
  type SessionHistoryMessageEvent,
  type SessionHistoryPlanEvent,
  type SessionHistoryToolEvent,
  type SessionHistoryUsageEvent,
} from "@/features/task-history/model/events";

export type TranscriptMessagePart = {
  id: string;
  type: string;
  text: string;
  eventIds: string[];
};

export type TranscriptMessage = {
  id: string;
  role: string;
  parts: TranscriptMessagePart[];
  eventIds: string[];
  at?: string;
  sessionId?: string;
};

export type TranscriptToolCall = {
  id: string;
  callId?: string;
  parentCallId?: string;
  name?: string;
  toolKind?: string;
  title?: string;
  status?: string;
  inputSummary?: string;
  outputText?: string;
  errorText?: string;
  paths: string[];
  diffs: Array<{
    path?: string;
    oldText?: string;
    newText?: string;
  }>;
  rawInputJson?: string;
  rawOutputJson?: string;
  eventIds: string[];
  firstAt?: string;
  lastAt?: string;
};

export type TranscriptUsageSummary = {
  inputTokens?: number;
  cachedInputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
  durationMs?: number;
};

export type TranscriptSnapshot = {
  nodeRunId?: string;
  sessionId?: string;
  events: SessionHistoryEvent[];
  messages: Record<string, TranscriptMessage>;
  messageOrder: string[];
  tools: Record<string, TranscriptToolCall>;
  toolOrder: string[];
  latestPlan?: SessionHistoryPlanEvent;
  latestUsage?: SessionHistoryUsageEvent;
  usageSummary?: TranscriptUsageSummary;
  lastSeq?: number;
  completeness: string;
  hasStructuredEvents: boolean;
};

export type TranscriptState = TranscriptSnapshot;

export type NormalizedTranscriptReplay = {
  nodeRunId?: string;
  sessionId?: string;
  completeness?: string;
  lastSeq?: number;
  events?: SessionHistoryEvent[];
};

type BuildTranscriptArgs = {
  nodeRunId?: string;
  sessionId?: string;
  replay?: TaskRunHistoryResult;
  liveEvents?: SessionHistoryEventDto[];
  liveLegacyLines?: string[];
  liveLegacyRunId?: string;
};

type BuildTranscriptSnapshotArgs = {
  nodeRunId?: string;
  sessionId?: string;
  history?: NormalizedTranscriptReplay;
  replay?: NormalizedTranscriptReplay;
  liveEvents?: SessionHistoryEvent[];
  liveLegacyLines?: string[];
  liveLegacyRunId?: string;
};

type IndexedEvent = {
  index: number;
  event: SessionHistoryEvent;
};

function compareIndexedEvents(left: IndexedEvent, right: IndexedEvent) {
  const leftSeq = left.event.seq;
  const rightSeq = right.event.seq;
  if (leftSeq != null && rightSeq != null && leftSeq !== rightSeq) {
    return leftSeq - rightSeq;
  }
  if (leftSeq != null && rightSeq == null) {
    return -1;
  }
  if (leftSeq == null && rightSeq != null) {
    return 1;
  }
  const leftAt = left.event.at ?? left.event.recordedAt;
  const rightAt = right.event.at ?? right.event.recordedAt;
  if (leftAt && rightAt && leftAt !== rightAt) {
    return leftAt.localeCompare(rightAt);
  }
  if (leftAt && !rightAt) {
    return -1;
  }
  if (!leftAt && rightAt) {
    return 1;
  }
  return left.index - right.index;
}

function joinDistinctText(existing: string, next: string): string {
  if (!existing) {
    return next;
  }
  if (!next) {
    return existing;
  }
  if (existing === next || existing.includes(next)) {
    return existing;
  }
  if (next.includes(existing)) {
    return next;
  }
  return `${existing}\n${next}`;
}

function mergeMessagePart(existing: TranscriptMessagePart | undefined, event: SessionHistoryMessageEvent) {
  if (!existing) {
    return {
      id: event.partId || event.id,
      type: event.partType,
      text: event.text,
      eventIds: [event.id],
    };
  }
  const next = {
    ...existing,
    type: event.partType || existing.type,
    text: joinDistinctText(existing.text, event.text),
  };
  if (!next.eventIds.includes(event.id)) {
    next.eventIds = [...next.eventIds, event.id];
  }
  return next;
}

function mergeToolItem(existing: TranscriptToolCall | undefined, event: SessionHistoryToolEvent): TranscriptToolCall {
  if (!existing) {
    return {
      id: event.callId || event.id,
      callId: event.callId,
      parentCallId: event.parentCallId,
      name: event.name,
      toolKind: event.toolKind,
      title: event.title,
      status: event.status,
      inputSummary: event.inputSummary,
      outputText: event.outputText,
      errorText: event.errorText,
      paths: [...event.paths],
      diffs: [...event.diffs],
      rawInputJson: event.rawInputJson,
      rawOutputJson: event.rawOutputJson,
      eventIds: [event.id],
      firstAt: event.at,
      lastAt: event.at,
    };
  }
  const next: TranscriptToolCall = {
    ...existing,
    callId: event.callId || existing.callId,
    parentCallId: event.parentCallId || existing.parentCallId,
    name: event.name || existing.name,
    toolKind: event.toolKind || existing.toolKind,
    title: event.title || existing.title,
    status: event.status || existing.status,
    inputSummary: event.inputSummary || existing.inputSummary,
    outputText: event.outputText || existing.outputText,
    errorText: event.errorText || existing.errorText,
    paths: event.paths.length > 0 ? [...event.paths] : existing.paths,
    diffs: event.diffs.length > 0 ? [...event.diffs] : existing.diffs,
    rawInputJson: event.rawInputJson || existing.rawInputJson,
    rawOutputJson: event.rawOutputJson || existing.rawOutputJson,
    firstAt: existing.firstAt || event.at,
    lastAt: event.at || existing.lastAt,
    eventIds: existing.eventIds.includes(event.id)
      ? existing.eventIds
      : [...existing.eventIds, event.id],
  };
  return next;
}

function mergeUsage(
  existing: TranscriptUsageSummary | undefined,
  event: SessionHistoryUsageEvent,
): TranscriptUsageSummary {
  return {
    inputTokens: event.usage.inputTokens ?? existing?.inputTokens,
    cachedInputTokens: event.usage.cachedInputTokens ?? existing?.cachedInputTokens,
    outputTokens: event.usage.outputTokens ?? existing?.outputTokens,
    totalTokens: event.usage.totalTokens ?? existing?.totalTokens,
    durationMs: event.usage.durationMs ?? existing?.durationMs,
  };
}

function dedupeAndOrderEvents(events: SessionHistoryEvent[]) {
  const indexed = new Map<string, IndexedEvent>();
  let order = 0;
  for (const event of events) {
    indexed.set(event.id, { index: order, event });
    order += 1;
  }
  return [...indexed.values()].sort(compareIndexedEvents).map((entry) => entry.event);
}

export function buildTranscriptSnapshot({
  nodeRunId,
  sessionId,
  history,
  replay,
  liveEvents,
  liveLegacyLines,
  liveLegacyRunId,
}: BuildTranscriptSnapshotArgs): TranscriptSnapshot {
  const replayData = replay ?? history;
  const normalizedEvents: SessionHistoryEvent[] = [];
  for (const event of replayData?.events ?? []) {
    normalizedEvents.push(event);
  }
  for (const event of liveEvents ?? []) {
    normalizedEvents.push(event);
  }
  for (const [index, line] of (liveLegacyLines ?? []).entries()) {
    normalizedEvents.push(
      normalizeLiveOutputLine(line, "hydrated_live", nodeRunId, liveLegacyRunId, index),
    );
  }

  const eventLedger = dedupeAndOrderEvents(normalizedEvents);
  const messages: Record<string, TranscriptMessage> = {};
  const messageOrder: string[] = [];
  const tools: Record<string, TranscriptToolCall> = {};
  const toolOrder: string[] = [];

  let latestPlan: SessionHistoryPlanEvent | undefined;
  let latestUsage: SessionHistoryUsageEvent | undefined;
  let usageSummary: TranscriptUsageSummary | undefined;
  let latestSessionId = sessionId ?? replayData?.sessionId;
  let lastSeq = replayData?.lastSeq;

  for (const event of eventLedger) {
    if (event.sessionId) {
      latestSessionId = event.sessionId;
    }
    if (event.seq != null) {
      lastSeq = Math.max(lastSeq ?? 0, event.seq);
    }

    if (event.kind === "message") {
      const messageId = event.messageId || `message:${event.id}`;
      const partId = event.partId || `part:${event.id}`;
      let message = messages[messageId];
      if (!message) {
        message = {
          id: messageId,
          role: event.role,
          parts: [],
          eventIds: [],
          at: event.at,
          sessionId: event.sessionId,
        };
        messages[messageId] = message;
        messageOrder.push(messageId);
      }
      if (!message.eventIds.includes(event.id)) {
        message.eventIds.push(event.id);
      }
      if (!message.at) {
        message.at = event.at;
      }
      if (!message.sessionId) {
        message.sessionId = event.sessionId;
      }
      const partIndex = message.parts.findIndex((part) => part.id === partId);
      if (partIndex >= 0) {
        message.parts[partIndex] = mergeMessagePart(message.parts[partIndex], event);
      } else {
        message.parts.push(mergeMessagePart(undefined, event));
      }
      continue;
    }

    if (event.kind === "tool") {
      const toolId = event.callId || `tool:${event.id}`;
      const existing = tools[toolId];
      tools[toolId] = mergeToolItem(existing, event);
      if (!toolOrder.includes(toolId)) {
        toolOrder.push(toolId);
      }
      continue;
    }

    if (event.kind === "plan") {
      latestPlan = event;
      continue;
    }

    if (event.kind === "usage") {
      latestUsage = event;
      usageSummary = mergeUsage(usageSummary, event);
    }
  }

  return {
    nodeRunId: nodeRunId ?? replayData?.nodeRunId,
    sessionId: latestSessionId,
    events: eventLedger,
    messages,
    messageOrder,
    tools,
    toolOrder,
    latestPlan,
    latestUsage,
    usageSummary,
    lastSeq,
    completeness: replayData?.completeness ?? "none",
    hasStructuredEvents: eventLedger.some((event) => event.kind !== "raw"),
  };
}

export function buildTranscriptState({
  nodeRunId,
  sessionId,
  replay,
  liveEvents,
  liveLegacyLines,
  liveLegacyRunId,
}: BuildTranscriptArgs): TranscriptState {
  const normalizedReplay: NormalizedTranscriptReplay | undefined = replay
    ? {
        nodeRunId: replay.node_run_id,
        sessionId: replay.session_id,
        completeness: replay.completeness,
        lastSeq: replay.last_seq,
        events: (replay.events ?? []).map((event, index) =>
          normalizeStreamEvent(event, "replay", replay.node_run_id, index),
        ),
      }
    : undefined;
  const normalizedLiveEvents = (liveEvents ?? []).map((event, index) =>
    normalizeStreamEvent(event, "live", nodeRunId, index),
  );
  return buildTranscriptSnapshot({
    nodeRunId,
    sessionId,
    replay: normalizedReplay,
    liveEvents: normalizedLiveEvents,
    liveLegacyLines,
    liveLegacyRunId,
  });
}
