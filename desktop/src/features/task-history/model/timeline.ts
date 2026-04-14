import type {
  SessionHistoryEvent,
  SessionHistoryMessageEvent,
  SessionHistoryPlanEvent,
  SessionHistoryRawEvent,
  SessionHistoryToolEvent,
  SessionHistoryUsageEvent,
} from "@/features/task-history/model/events";
import type {
  TranscriptMessage,
  TranscriptSnapshot,
  TranscriptToolCall,
} from "@/features/task-history/model/transcript";

export type TranscriptTimelineItem =
  | {
      id: string;
      kind: "message";
      role: string;
      partType: string;
      text: string;
      source?: string;
      provenance?: string;
    }
  | {
      id: string;
      kind: "tool";
      toolId: string;
      label: string;
      status?: string;
      durationMs?: number;
      subject?: string;
      title?: string;
      rawInputJson?: string;
      outputText?: string;
      errorText?: string;
      eventIds: string[];
      paths: string[];
      diffs: Array<{
        path?: string;
        oldText?: string;
        newText?: string;
      }>;
      rawOutputJson?: string;
      source?: string;
      provenance?: string;
    }
  | {
      id: string;
      kind: "plan";
      summary: string;
      steps: Array<{
        text: string;
        status?: string;
      }>;
      source?: string;
      provenance?: string;
    }
  | {
      id: string;
      kind: "usage";
      summary: string;
      usage: {
        inputTokens?: number;
        cachedInputTokens?: number;
        outputTokens?: number;
        totalTokens?: number;
        durationMs?: number;
      };
      source?: string;
      provenance?: string;
    }
  | {
      id: string;
      kind: "raw";
      text: string;
      raw: string;
      source?: string;
      provenance?: string;
    };

export type RunningActivityPreviewRow = {
  id: string;
  text: string;
  tone: "current" | "previous";
};

function collapseWhitespace(value: string | undefined): string {
  return value?.replace(/\s+/g, " ").trim() ?? "";
}

function compactPaths(paths: string[] | undefined): string[] {
  const results: string[] = [];
  for (const rawPath of paths ?? []) {
    const normalized = rawPath.trim();
    if (!normalized) {
      continue;
    }
    const parts = normalized.split(/[\\/]/).filter(Boolean);
    results.push(parts.at(-1) ?? normalized);
  }
  return results;
}

function prettifyToolName(name: string | undefined): string {
  const trimmed = name?.trim();
  if (!trimmed) {
    return "";
  }
  return trimmed
    .replace(/[_-]+/g, " ")
    .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
    .trim()
    .toLowerCase();
}

function toolLabel(event: SessionHistoryToolEvent): string {
  switch (event.toolKind?.trim()) {
    case "shell":
      return "shell";
    case "search":
      return "search";
    case "read":
      return "read";
    case "edit":
      return "edit";
    case "write":
      return "write";
    case "fetch":
      return "fetch";
    case "mcp":
      return "MCP";
    case "file_change":
      return "files";
    case "structured_output":
      return "structured output";
    default:
      return prettifyToolName(event.name) || "tool";
  }
}

function toolSubject(event: SessionHistoryToolEvent): string {
  const inputSummary = collapseWhitespace(event.inputSummary);
  if (inputSummary) {
    return inputSummary;
  }
  if (event.toolKind === "mcp") {
    const server = event.mcp?.server?.trim();
    const tool = event.mcp?.tool?.trim();
    if (server && tool) {
      return `${server}.${tool}`;
    }
    if (tool) {
      return tool;
    }
  }
  const paths = compactPaths(event.paths);
  if (paths.length > 0) {
    return paths.join(", ");
  }
  return collapseWhitespace(event.title);
}

function toolStatusText(status: string | undefined): string {
  switch (status?.trim()) {
    case "in_progress":
    case "pending":
      return "running";
    case "failed":
      return "failed";
    default:
      return "";
  }
}

function stripMarkdownFormatting(value: string | undefined): string {
  if (!value) {
    return "";
  }
  const lines = value
    .replace(/\r/g, "")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, "$1")
    .split("\n")
    .map((line) =>
      line
        .trim()
        .replace(/^#{1,6}\s+/, "")
        .replace(/^>\s+/, "")
        .replace(/^[-*+]\s+/, "")
        .replace(/^\d+\.\s+/, ""),
    )
    .filter(Boolean);
  return collapseWhitespace(
    lines
      .join(" · ")
      .replace(/`([^`]+)`/g, "$1")
      .replace(/```+/g, "")
      .replace(/\*\*([^*]+)\*\*/g, "$1")
      .replace(/__([^_]+)__/g, "$1")
      .replace(/~~([^~]+)~~/g, "$1"),
  );
}

function truncatePreviewText(value: string, maxLength = 104): string {
  if (value.length <= maxLength) {
    return value;
  }
  const slice = value.slice(0, maxLength);
  const lastSpace = slice.lastIndexOf(" ");
  const cutoff = lastSpace >= Math.floor(maxLength * 0.6) ? lastSpace : maxLength;
  return `${slice.slice(0, cutoff).trim()}...`;
}

function compactPreviewText(value: string | undefined): string {
  const compacted = stripMarkdownFormatting(value);
  return compacted ? truncatePreviewText(compacted) : "";
}

function capitalizePreviewText(value: string): string {
  if (!value) {
    return "";
  }
  return `${value.charAt(0).toUpperCase()}${value.slice(1)}`;
}

function looksLikeJsonBlob(value: string): boolean {
  const trimmed = value.trim();
  if (!trimmed) {
    return false;
  }
  return (
    ((trimmed.startsWith("{") && trimmed.endsWith("}")) ||
      (trimmed.startsWith("[") && trimmed.endsWith("]"))) &&
    /"\w+"\s*:/.test(trimmed)
  );
}

function toolPreviewText(item: Extract<TranscriptTimelineItem, { kind: "tool" }>): string {
  const subject = compactPreviewText(item.subject || item.title);
  const isRunning = item.status === "running";
  switch (item.label.trim().toLowerCase()) {
    case "edit":
      return subject
        ? `${isRunning ? "Editing" : "Edited"} ${subject}`
        : `${isRunning ? "Editing" : "Edited"} files`;
    case "read":
      return subject ? `Read ${subject}` : "Read file";
    case "search":
      return subject
        ? `${isRunning ? "Searching" : "Searched"} ${subject}`
        : isRunning
          ? "Searching"
          : "Searched";
    case "write":
      return subject
        ? `${isRunning ? "Writing" : "Wrote"} ${subject}`
        : isRunning
          ? "Writing file"
          : "Wrote file";
    case "fetch":
      return subject
        ? `${isRunning ? "Fetching" : "Fetched"} ${subject}`
        : isRunning
          ? "Fetching"
          : "Fetched";
    case "shell":
      return subject
        ? `${isRunning ? "Running" : "Ran"} ${subject}`
        : isRunning
          ? "Running shell"
          : "Ran shell";
    case "mcp":
      return subject
        ? `${isRunning ? "Calling" : "Called"} ${subject}`
        : isRunning
          ? "Calling MCP"
          : "Called MCP";
    case "files":
      return subject
        ? `${isRunning ? "Updating" : "Updated"} ${subject}`
        : `${isRunning ? "Updating" : "Updated"} files`;
    case "structured output":
      return subject ? `Structured output ${subject}` : "Structured output";
    default: {
      const label = capitalizePreviewText(compactPreviewText(item.label));
      if (label && subject) {
        return `${label} ${subject}`;
      }
      return label || subject;
    }
  }
}

function previewTextForItem(args: {
  item: TranscriptTimelineItem;
  allowRaw: boolean;
}): string | undefined {
  const { item, allowRaw } = args;
  if (item.kind === "tool") {
    return compactPreviewText(toolPreviewText(item)) || undefined;
  }
  if (item.kind === "plan") {
    return compactPreviewText(item.summary) || undefined;
  }
  if (item.kind === "message") {
    if (item.role !== "assistant" || item.partType === "reasoning") {
      return undefined;
    }
    return compactPreviewText(item.text) || undefined;
  }
  if (item.kind === "raw" && allowRaw) {
    const text = compactPreviewText(item.text);
    if (!text || looksLikeJsonBlob(text)) {
      return undefined;
    }
    return text;
  }
  return undefined;
}

function appendPreviewRows(args: {
  items: TranscriptTimelineItem[];
  rows: Array<Omit<RunningActivityPreviewRow, "tone"> & { itemIndex: number }>;
  seenTexts: Set<string>;
  allowRaw: boolean;
  limit: number;
}) {
  const { items, rows, seenTexts, allowRaw, limit } = args;
  for (let index = items.length - 1; index >= 0 && rows.length < limit; index -= 1) {
    const item = items[index];
    if (item.kind === "raw" && !allowRaw) {
      continue;
    }
    if (item.kind !== "raw" && allowRaw) {
      continue;
    }
    const text = previewTextForItem({ item, allowRaw });
    if (!text || seenTexts.has(text)) {
      continue;
    }
    rows.push({
      id: item.id,
      text,
      itemIndex: index,
    });
    seenTexts.add(text);
  }
}

function messageItem(
  message: TranscriptMessage,
  partId: string | undefined,
): TranscriptTimelineItem | undefined {
  const part =
    message.parts.find((entry) => entry.id === partId) ??
    message.parts.at(-1);
  if (!part) {
    return undefined;
  }
  const text = part.text?.trim();
  if (!text) {
    return undefined;
  }
  return {
    id: `${message.id}:${part.id}`,
    kind: "message",
    role: message.role || "assistant",
    partType: part.type || "text",
    text,
    source: "replay",
  };
}

function summarizeMessage(
  event: SessionHistoryMessageEvent,
): TranscriptTimelineItem | undefined {
  const text = event.text?.trim();
  if (!text) {
    return undefined;
  }
  return {
    id: event.id,
    kind: "message",
    role: event.role || "assistant",
    partType: event.partType || "text",
    text,
    source: event.source,
    provenance: event.provenance,
  };
}

function normalizeToolLike(
  tool: TranscriptToolCall | SessionHistoryToolEvent,
): SessionHistoryToolEvent {
  if ("eventIds" in tool) {
    return {
      id: tool.id,
      kind: "tool",
      source: "replay",
      callId: tool.callId,
      parentCallId: tool.parentCallId,
      name: tool.name,
      toolKind: tool.toolKind,
      title: tool.title,
      status: tool.status,
      durationMs: tool.durationMs,
      inputSummary: tool.inputSummary,
      outputText: tool.outputText,
      errorText: tool.errorText,
      paths: tool.paths,
      diffs: tool.diffs,
      rawInputJson: tool.rawInputJson,
      rawOutputJson: tool.rawOutputJson,
      mcp: tool.mcp,
    };
  }
  return tool;
}

function toolDurationMs(tool: TranscriptToolCall | SessionHistoryToolEvent): number | undefined {
  if ("eventIds" in tool) {
    if (tool.durationMs != null) {
      return tool.durationMs;
    }
    const first = Date.parse(tool.firstAt ?? "");
    const last = Date.parse(tool.lastAt ?? "");
    if (Number.isFinite(first) && Number.isFinite(last) && last > first) {
      return last - first;
    }
    return undefined;
  }
  return tool.durationMs;
}

function summarizeTool(
  tool: TranscriptToolCall | SessionHistoryToolEvent,
): TranscriptTimelineItem {
  const normalizedTool = normalizeToolLike(tool);
  return {
    id: normalizedTool.id,
    kind: "tool",
    toolId: normalizedTool.callId || normalizedTool.id,
    label: toolLabel(normalizedTool),
    status: toolStatusText(normalizedTool.status),
    durationMs: toolDurationMs(tool),
    subject: toolSubject(normalizedTool),
    title: normalizedTool.title,
    rawInputJson: normalizedTool.rawInputJson,
    outputText: normalizedTool.outputText,
    errorText: normalizedTool.errorText,
    eventIds: "eventIds" in tool ? [...tool.eventIds] : [normalizedTool.id],
    paths: normalizedTool.paths,
    diffs: normalizedTool.diffs,
    rawOutputJson: normalizedTool.rawOutputJson,
    source: normalizedTool.source,
    provenance: normalizedTool.provenance,
  };
}

function summarizePlan(event: SessionHistoryPlanEvent): TranscriptTimelineItem {
  const total = event.steps.length;
  const completed = event.steps.filter((step) => step.status === "completed").length;
  const next = event.steps.find((step) => step.status !== "completed")?.text;
  return {
    id: event.id,
    kind: "plan",
    summary: next
      ? `plan: ${completed}/${total} complete, next ${collapseWhitespace(next)}`
      : `plan: ${completed}/${total} complete`,
    steps: event.steps,
    source: event.source,
    provenance: event.provenance,
  };
}

function summarizeUsage(event: SessionHistoryUsageEvent): TranscriptTimelineItem {
  if (event.usage.inputTokens || event.usage.outputTokens) {
    return {
      id: event.id,
      kind: "usage",
      summary: `usage: ${event.usage.inputTokens ?? 0} in, ${event.usage.outputTokens ?? 0} out`,
      usage: event.usage,
      source: event.source,
      provenance: event.provenance,
    };
  }
  return {
    id: event.id,
    kind: "usage",
    summary: `usage: ${event.usage.totalTokens ?? 0} tokens`,
    usage: event.usage,
    source: event.source,
    provenance: event.provenance,
  };
}

function summarizeRaw(event: SessionHistoryRawEvent): TranscriptTimelineItem {
  return {
    id: event.id,
    kind: "raw",
    text: event.raw,
    raw: event.raw,
    source: event.source,
    provenance: event.provenance,
  };
}

export function timelineItemForEvent(
  event: SessionHistoryEvent,
): TranscriptTimelineItem | undefined {
  switch (event.kind) {
    case "message":
      return summarizeMessage(event);
    case "tool":
      return summarizeTool(event);
    case "plan":
      return summarizePlan(event);
    case "usage":
      return summarizeUsage(event);
    case "raw":
      return summarizeRaw(event);
    default:
      return undefined;
  }
}

export function deriveTranscriptTimelineItems(
  transcript: TranscriptSnapshot,
): TranscriptTimelineItem[] {
  const lastMessagePartEventId = new Set<string>();
  for (const messageId of transcript.messageOrder) {
    const message = transcript.messages[messageId];
    if (!message) {
      continue;
    }
    for (const part of message.parts) {
      const lastEventId = part.eventIds.at(-1);
      if (lastEventId) {
        lastMessagePartEventId.add(lastEventId);
      }
    }
  }

  const lastToolEventId = new Map<string, string>();
  for (const toolId of transcript.toolOrder) {
    const tool = transcript.tools[toolId];
    const lastEventId = tool?.eventIds.at(-1);
    if (tool && lastEventId) {
      lastToolEventId.set(lastEventId, toolId);
    }
  }

  const timelineItems: TranscriptTimelineItem[] = [];
  let latestPlanInserted = false;
  let latestUsageInserted = false;

  for (const event of transcript.events) {
    if (event.kind === "message") {
      if (!lastMessagePartEventId.has(event.id)) {
        continue;
      }
      const messageId = event.messageId || `message:${event.id}`;
      const message = transcript.messages[messageId];
      if (!message) {
        const fallback = timelineItemForEvent(event);
        if (fallback) {
          timelineItems.push(fallback);
        }
        continue;
      }
      const item = messageItem(message, event.partId || `part:${event.id}`);
      if (item) {
        timelineItems.push(item);
      }
      continue;
    }

    if (event.kind === "tool") {
      const toolId = lastToolEventId.get(event.id);
      if (!toolId) {
        continue;
      }
      const tool = transcript.tools[toolId];
      if (!tool) {
        const fallback = timelineItemForEvent(event);
        if (fallback) {
          timelineItems.push(fallback);
        }
        continue;
      }
      timelineItems.push(summarizeTool(tool));
      continue;
    }

    if (event.kind === "plan") {
      if (!latestPlanInserted && transcript.latestPlan && transcript.latestPlan.id === event.id) {
        timelineItems.push(summarizePlan(transcript.latestPlan));
        latestPlanInserted = true;
      }
      continue;
    }

    if (event.kind === "usage") {
      if (!latestUsageInserted && transcript.latestUsage && transcript.latestUsage.id === event.id) {
        timelineItems.push(summarizeUsage(transcript.latestUsage));
        latestUsageInserted = true;
      }
      continue;
    }

    if (event.kind === "raw") {
      timelineItems.push(summarizeRaw(event));
    }
  }

  return timelineItems;
}

export function deriveRunningActivityPreview(
  items: TranscriptTimelineItem[],
  limit = 2,
): RunningActivityPreviewRow[] {
  const rows: Array<Omit<RunningActivityPreviewRow, "tone"> & { itemIndex: number }> = [];
  const seenTexts = new Set<string>();
  appendPreviewRows({
    items,
    rows,
    seenTexts,
    allowRaw: false,
    limit,
  });
  if (rows.length < limit) {
    appendPreviewRows({
      items,
      rows,
      seenTexts,
      allowRaw: true,
      limit,
    });
  }
  return rows
    .sort((left, right) => right.itemIndex - left.itemIndex)
    .map(({ itemIndex: _itemIndex, ...row }, index) => ({
      ...row,
      tone: index === 0 ? "current" : "previous",
    }));
}

export function timelineItemsToLines(
  items: TranscriptTimelineItem[],
): string[] {
  const lines: string[] = [];
  for (const item of items) {
    if (item.kind === "message") {
      const prefix = item.partType === "reasoning" ? "thinking" : item.role;
      const text = collapseWhitespace(item.text);
      if (text) {
        lines.push(`${prefix}: ${text}`);
      }
      continue;
    }
    if (item.kind === "tool") {
      if (item.label && item.status && item.subject) {
        lines.push(`${item.label} ${item.status}: ${item.subject}`);
      } else if (item.label && item.subject) {
        lines.push(`${item.label}: ${item.subject}`);
      } else if (item.label && item.status) {
        lines.push(`${item.label} ${item.status}`);
      } else if (item.label) {
        lines.push(item.label);
      }
      if (item.errorText) {
        lines.push(item.errorText);
      }
      continue;
    }
    if (item.kind === "plan") {
      lines.push(item.summary);
      continue;
    }
    if (item.kind === "raw") {
      if (item.text.trim()) {
        lines.push(item.text);
      }
      continue;
    }
  }
  return lines;
}
