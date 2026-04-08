import type { TaskRunHistoryResult } from "@/rpc/types";
import {
  normalizeLiveOutputLine,
  normalizeStreamEvent,
  type SessionHistoryEvent,
  type SessionHistoryMessageEvent,
  type SessionHistoryPlanEvent,
  type SessionHistoryRawEvent,
  type SessionHistorySource,
  type SessionHistoryToolEvent,
  type SessionHistoryUsageEvent,
} from "@/features/task-history/model/events";
import {
  buildTranscriptSnapshot,
  type NormalizedTranscriptReplay,
  type TranscriptMessage,
  type TranscriptMessagePart,
  type TranscriptSnapshot,
  type TranscriptState,
  type TranscriptToolCall,
  type TranscriptUsageSummary,
} from "@/features/task-history/model/transcript";
import {
  deriveTranscriptTimelineItems,
  timelineItemsToLines,
} from "@/features/task-history/model/timeline";

export type {
  SessionHistoryEvent,
  SessionHistoryMessageEvent,
  SessionHistoryPlanEvent,
  SessionHistoryRawEvent,
  SessionHistorySource,
  SessionHistoryToolEvent,
  SessionHistoryUsageEvent,
  TranscriptMessage,
  TranscriptMessagePart,
  TranscriptSnapshot,
  TranscriptState,
  TranscriptToolCall,
  TranscriptUsageSummary,
};

export {
  buildTranscriptSnapshot,
  normalizeLiveOutputLine,
  normalizeStreamEvent,
};

export type NormalizedTaskRunHistoryResult = NormalizedTranscriptReplay & {
  taskId: string;
  nodeRunId: string;
  provenance: string;
};

type IndexedSessionHistoryEvent = {
  index: number;
  event: SessionHistoryEvent;
};

function compareSessionHistoryEvents(
  left: IndexedSessionHistoryEvent,
  right: IndexedSessionHistoryEvent,
) {
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

export function mergeSessionHistoryEvents(
  existingEvents: SessionHistoryEvent[],
  incomingEvents: SessionHistoryEvent[],
): SessionHistoryEvent[] {
  const indexed = new Map<string, IndexedSessionHistoryEvent>();
  let index = 0;
  for (const event of [...existingEvents, ...incomingEvents]) {
    indexed.set(event.id, { index, event });
    index += 1;
  }
  return [...indexed.values()]
    .sort(compareSessionHistoryEvents)
    .map((entry) => entry.event);
}

export function normalizeTaskRunHistoryResult(
  result: TaskRunHistoryResult,
): NormalizedTaskRunHistoryResult {
  return {
    taskId: result.task_id,
    nodeRunId: result.node_run_id,
    sessionId: result.session_id,
    provenance: result.provenance,
    completeness: result.completeness,
    lastSeq: result.last_seq,
    events: (result.events ?? []).map((event, index) =>
      normalizeStreamEvent(event, "replay", result.node_run_id, index),
    ),
  };
}

export function summarizeTranscript(snapshot: TranscriptSnapshot): string[] {
  return timelineItemsToLines(deriveTranscriptTimelineItems(snapshot));
}
