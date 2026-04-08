import type {
  SessionHistoryEventDto,
  SessionHistoryPlanStepDto,
  SessionHistoryToolDiffDto,
} from "@/rpc/types";

export type SessionHistorySource = "replay" | "live" | "hydrated_live";

type SessionHistoryEventBase = {
  id: string;
  kind: SessionHistoryEventDto["kind"];
  source: SessionHistorySource;
  nodeRunId?: string;
  sessionId?: string;
  seq?: number;
  at?: string;
  recordedAt?: string;
  providerRecordId?: string;
  providerSubindex?: number;
  provenance?: string;
};

export type SessionHistoryMessageEvent = SessionHistoryEventBase & {
  kind: "message";
  messageId?: string;
  partId?: string;
  role: string;
  partType: string;
  text: string;
};

export type SessionHistoryToolEvent = SessionHistoryEventBase & {
  kind: "tool";
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
};

export type SessionHistoryPlanEvent = SessionHistoryEventBase & {
  kind: "plan";
  planId?: string;
  steps: Array<{
    text: string;
    status?: string;
  }>;
};

export type SessionHistoryUsageEvent = SessionHistoryEventBase & {
  kind: "usage";
  usage: {
    inputTokens?: number;
    cachedInputTokens?: number;
    outputTokens?: number;
    totalTokens?: number;
    durationMs?: number;
  };
};

export type SessionHistoryRawEvent = SessionHistoryEventBase & {
  kind: "raw";
  raw: string;
  text: string;
};

export type SessionHistoryEvent =
  | SessionHistoryMessageEvent
  | SessionHistoryToolEvent
  | SessionHistoryPlanEvent
  | SessionHistoryUsageEvent
  | SessionHistoryRawEvent;

function compactText(value: string | undefined) {
  return value?.replace(/\s+/g, " ").trim() ?? "";
}

function normalizeDiffs(diffs: SessionHistoryToolDiffDto[] | undefined) {
  return (diffs ?? []).map((diff) => ({
    path: diff.path,
    oldText: diff.old_text,
    newText: diff.new_text,
  }));
}

function normalizePlanSteps(steps: SessionHistoryPlanStepDto[] | undefined) {
  return (steps ?? [])
    .filter((step) => Boolean(step?.text?.trim()))
    .map((step) => ({
      text: step.text,
      status: step.status,
    }));
}

function synthesizeEventId(
  dto: SessionHistoryEventDto,
  source: SessionHistorySource,
  nodeRunId: string | undefined,
  fallback: string,
) {
  if (dto.event_id?.trim()) {
    return dto.event_id;
  }
  const parts = [
    source,
    nodeRunId ?? "",
    dto.kind,
    dto.seq != null ? String(dto.seq) : "",
    dto.provider_record_id ?? "",
    dto.provider_subindex != null ? String(dto.provider_subindex) : "",
    dto.session_id ?? "",
    fallback,
  ].filter(Boolean);
  return parts.join("|");
}

function baseEvent(
  dto: SessionHistoryEventDto,
  source: SessionHistorySource,
  nodeRunId?: string,
) {
  return {
    source,
    nodeRunId,
    sessionId: dto.session_id,
    seq: dto.seq,
    at: dto.emitted_at,
    recordedAt: dto.recorded_at,
    providerRecordId: dto.provider_record_id,
    providerSubindex: dto.provider_subindex,
    provenance: dto.provenance,
  };
}

export function normalizeStreamEvent(
  dto: SessionHistoryEventDto,
  source: SessionHistorySource,
  nodeRunId?: string,
  fallbackIndex?: number,
): SessionHistoryEvent {
  const eventBase = baseEvent(dto, source, nodeRunId);

  if (dto.kind === "message") {
    const text = dto.text ?? "";
    const role = dto.role ?? "assistant";
    const partType = dto.part_type ?? "text";
    return {
      ...eventBase,
      id: synthesizeEventId(
        dto,
        source,
        nodeRunId,
        [
          dto.message_id ?? "",
          dto.part_id ?? "",
          role,
          partType,
          text,
          fallbackIndex != null ? String(fallbackIndex) : "",
        ]
          .filter(Boolean)
          .join("|"),
      ),
      kind: "message",
      messageId: dto.message_id,
      partId: dto.part_id,
      role,
      partType,
      text,
    };
  }

  if (dto.kind === "tool") {
    return {
      ...eventBase,
      id: synthesizeEventId(
        dto,
        source,
        nodeRunId,
        [
          dto.call_id ?? "",
          dto.status ?? "",
          dto.name ?? "",
          dto.input_summary ?? "",
          fallbackIndex != null ? String(fallbackIndex) : "",
        ]
          .filter(Boolean)
          .join("|"),
      ),
      kind: "tool",
      callId: dto.call_id,
      parentCallId: dto.parent_call_id,
      name: dto.name,
      toolKind: dto.tool_kind,
      title: dto.title,
      status: dto.status,
      inputSummary: dto.input_summary,
      outputText: dto.output_text,
      errorText: dto.error_text,
      paths: dto.paths ?? [],
      diffs: normalizeDiffs(dto.diffs),
      rawInputJson: dto.raw_input_json,
      rawOutputJson: dto.raw_output_json,
    };
  }

  if (dto.kind === "plan") {
    const steps = normalizePlanSteps(dto.steps);
    return {
      ...eventBase,
      id: synthesizeEventId(
        dto,
        source,
        nodeRunId,
        [
          dto.plan_id ?? "",
          fallbackIndex != null ? String(fallbackIndex) : "",
          ...steps.map((step) => `${step.status ?? ""}:${step.text}`),
        ]
          .filter(Boolean)
          .join("|"),
      ),
      kind: "plan",
      planId: dto.plan_id,
      steps,
    };
  }

  if (dto.kind === "usage") {
    return {
      ...eventBase,
      id: synthesizeEventId(
        dto,
        source,
        nodeRunId,
        [
          dto.input_tokens != null ? String(dto.input_tokens) : "",
          dto.output_tokens != null ? String(dto.output_tokens) : "",
          dto.total_tokens != null ? String(dto.total_tokens) : "",
          dto.duration_ms != null ? String(dto.duration_ms) : "",
          fallbackIndex != null ? String(fallbackIndex) : "",
        ]
          .filter(Boolean)
          .join("|"),
      ),
      kind: "usage",
      usage: {
        inputTokens: dto.input_tokens,
        cachedInputTokens: dto.cached_input_tokens,
        outputTokens: dto.output_tokens,
        totalTokens: dto.total_tokens,
        durationMs: dto.duration_ms,
      },
    };
  }

  const raw = dto.raw ?? "";
  return {
    ...eventBase,
    id: synthesizeEventId(
      dto,
      source,
      nodeRunId,
      [fallbackIndex != null ? String(fallbackIndex) : "", compactText(raw).slice(0, 160)]
        .filter(Boolean)
        .join("|"),
    ),
    kind: "raw",
    raw,
    text: compactText(raw),
  };
}

export function normalizeLiveOutputLine(
  line: string,
  source: SessionHistorySource,
  nodeRunId: string | undefined,
  runId: string | undefined,
  index: number,
): SessionHistoryRawEvent {
  const text = compactText(line) || line;
  return {
    id: [source, nodeRunId ?? "", runId ?? "", "line", String(index), text].join("|"),
    kind: "raw",
    source,
    nodeRunId,
    raw: line,
    text,
  };
}
