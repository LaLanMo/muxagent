import { useEffect, useState, type ReactNode } from "react";
import type { TranscriptSnapshot } from "@/domain/session-history";
import { detailStatusLabel } from "@/domain/task-shell";
import { DocumentContent } from "@/features/shared/ui/DocumentContent";
import type { TranscriptTimelineItem } from "@/features/task-history/model/timeline";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  ConfigCatalogEntryDto,
  InputQuestionDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";
import type { RunHistoryCacheEntry } from "@/state/task-snapshot-store";

type OverviewPaneProps = {
  task?: TaskViewDto;
  runCount: number;
  artifactCount: number;
};

type RunPaneProps = {
  run?: NodeRunViewDto;
  streamLines: string[];
  transcript: TranscriptSnapshot;
  transcriptItems: TranscriptTimelineItem[];
  historyEntry?: RunHistoryCacheEntry;
  streamSource: "live" | "replay" | "loading" | "none";
  isCurrentRun: boolean;
  artifactCount: number;
  showEmptyOutput: boolean;
};

type ArtifactPaneProps = {
  artifact?: ArtifactRefDto;
  content?: string;
  error?: string;
};

type ApprovalDockProps = {
  feedback: string;
  setFeedback: (value: string) => void;
  submittingDecision: boolean;
  submitApprove: () => Promise<void>;
  submitReject: () => Promise<void>;
  nodeName?: string;
};

type ClarificationDockProps = {
  nodeName?: string;
  requestKey?: string;
  questions: InputQuestionDto[];
  answers: Array<string | string[]>;
  setAnswer: (index: number, value: string | string[]) => void;
  submittingClarification: boolean;
  submitClarification: () => Promise<void>;
};

type RetryDockProps = {
  run?: NodeRunViewDto;
  failureReason?: string;
  submittingRetry: boolean;
  onRetry: (force?: boolean) => Promise<void>;
};

type FollowUpDockProps = {
  configEntries: ConfigCatalogEntryDto[];
  followUpConfigAlias: string;
  followUpDescription: string;
  setFollowUpDescription: (value: string) => void;
  onConfigChange: (alias: string) => void;
  submittingFollowUp: boolean;
  onStartFollowUp: () => Promise<void>;
};

type BlockedDockProps = {
  blockedStep?: BlockedStepDto;
  submittingContinue: boolean;
  onContinue: () => Promise<void>;
};

function PanelHeader({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  return (
    <div className="detail-pane__header">
      <div className="detail-pane__titles">
        <h3>{title}</h3>
        <p>{subtitle}</p>
      </div>
    </div>
  );
}

function DetailInfoCard({
  label,
  value,
  detail,
  testId,
}: {
  label: string;
  value: string | number;
  detail?: string;
  testId?: string;
}) {
  return (
    <div className="detail-info-card" data-testid={testId}>
      <span className="detail-info-card__label">{label}</span>
      <strong className="detail-info-card__value">{value}</strong>
      {detail ? <p className="detail-info-card__detail">{detail}</p> : null}
    </div>
  );
}

function DetailSection({
  label,
  children,
  className = "",
}: {
  label: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`detail-section${className ? ` ${className}` : ""}`}>
      <span className="detail-section__label">{label}</span>
      {children}
    </section>
  );
}

function DetailSurface({
  label,
  children,
  className = "",
  bodyClassName = "",
  testId,
}: {
  label: string;
  children: ReactNode;
  className?: string;
  bodyClassName?: string;
  testId?: string;
}) {
  return (
    <section
      className={`detail-surface-card${className ? ` ${className}` : ""}`}
      data-testid={testId}
    >
      <div className="detail-surface-card__header">
        <span className="detail-surface-card__label">{label}</span>
      </div>
      <div
        className={`detail-surface-card__body${
          bodyClassName ? ` ${bodyClassName}` : ""
        }`}
      >
        {children}
      </div>
    </section>
  );
}

function formatRunSubtitle(run: NodeRunViewDto) {
  const started = run.started_at ? run.started_at.slice(11, 16) : undefined;
  const completed = run.completed_at ? run.completed_at.slice(11, 16) : undefined;
  const status = detailStatusLabel(run.status);
  const pieces: string[] = [status];
  if (started) {
    pieces.push(`started ${started}`);
  }
  if (completed) {
    pieces.push(`${status.includes("await") ? "paused" : "ended"} ${completed}`);
  }
  return pieces.join(" · ");
}

function prettyResult(result: Record<string, unknown> | undefined) {
  if (!result || Object.keys(result).length === 0) {
    return undefined;
  }
  return JSON.stringify(result, null, 2);
}

function formatClarificationAnswer(selected: unknown): string {
  if (Array.isArray(selected)) {
    return selected.join(", ");
  }
  return typeof selected === "string" ? selected : "";
}

function formatHistoryProvenance(value: string | undefined): string {
  const normalized = value?.trim();
  switch (normalized) {
    case "executor_persisted":
      return "persisted replay";
    case "provider_backfilled":
      return "provider transcript";
    case "mixed_recovered":
      return "recovered merge";
    case "none":
    case "":
    case undefined:
      return "not available";
    default:
      return normalized.replace(/[_-]+/g, " ");
  }
}

function formatHistoryCompleteness(value: string | undefined): string {
  const normalized = value?.trim();
  switch (normalized) {
    case "complete":
      return "complete";
    case "open":
      return "open";
    case "partial":
      return "partial";
    case "none":
    case "":
    case undefined:
      return "not started";
    default:
      return normalized.replace(/[_-]+/g, " ");
  }
}

function shortenSessionId(value: string | undefined): string {
  const trimmed = value?.trim();
  if (!trimmed) {
    return "pending";
  }
  if (trimmed.length <= 18) {
    return trimmed;
  }
  return `${trimmed.slice(0, 8)}…${trimmed.slice(-6)}`;
}

function describeHistoryStatus(
  streamSource: RunPaneProps["streamSource"],
  transcript: TranscriptSnapshot,
) {
  const parts: string[] = [];
  if (transcript.replayEventCount > 0) {
    parts.push(
      `${transcript.replayEventCount} replay event${transcript.replayEventCount === 1 ? "" : "s"}`,
    );
  }
  if (transcript.liveEventCount > 0) {
    parts.push(
      `${transcript.liveEventCount} live event${transcript.liveEventCount === 1 ? "" : "s"}`,
    );
  }
  if (parts.length > 0) {
    return parts.join(" · ");
  }
  if (streamSource === "loading") {
    return "loading persisted events";
  }
  if (streamSource === "live") {
    return "live stream attached";
  }
  return "no structured transcript yet";
}

function describeTranscriptAvailability(
  streamSource: RunPaneProps["streamSource"],
  transcript: TranscriptSnapshot,
  run: NodeRunViewDto,
  isCurrentRun: boolean,
) {
  if (streamSource === "loading") {
    return {
      title: "Loading run history…",
      detail: "Fetching persisted session events for this node run.",
    };
  }
  if (isCurrentRun) {
    return {
      title: "Waiting for live output…",
      detail: run.session_id
        ? `Live stream events for session ${run.session_id} will appear here when the executor emits them.`
        : "This run is active. Stream events will appear here when the executor emits them.",
    };
  }
  if (transcript.completeness === "open") {
    return {
      title: "Partial transcript available",
      detail:
        "This run still has open history. Re-open it shortly to refresh newly recovered transcript events.",
    };
  }
  return {
    title: "No persisted stream for this run",
    detail:
      "Use the navigator artifacts or current action surface to inspect what happened in this step.",
  };
}

function RecoveryCard({
  tone,
  title,
  description,
  actions,
  testId,
}: {
  tone: "failed" | "blocked";
  title: string;
  description: string;
  actions: ReactNode;
  testId: string;
}) {
  return (
    <section
      className={`detail-recovery-card detail-recovery-card--${tone}`}
      data-testid={testId}
    >
      <div className="detail-recovery-card__copy">
        <strong className="detail-recovery-card__title">{title}</strong>
        <p className="detail-recovery-card__description">{description}</p>
      </div>
      <div className="detail-recovery-card__actions">{actions}</div>
    </section>
  );
}

/* ── Transcript grouping ─────────────────────────────────── */

type ToolItem = Extract<TranscriptTimelineItem, { kind: "tool" }>;
type GroupedTranscriptItem =
  | Exclude<TranscriptTimelineItem, { kind: "tool" }>
  | { kind: "tool-group"; id: string; tools: ToolItem[] };

function groupTranscriptItems(
  items: TranscriptTimelineItem[],
): GroupedTranscriptItem[] {
  const result: GroupedTranscriptItem[] = [];
  let pending: ToolItem[] = [];

  for (const item of items) {
    if (item.kind === "tool") {
      pending.push(item);
    } else {
      if (pending.length > 0) {
        result.push({
          kind: "tool-group",
          id: `tg-${pending[0].id}`,
          tools: [...pending],
        });
        pending = [];
      }
      result.push(item);
    }
  }
  if (pending.length > 0) {
    result.push({
      kind: "tool-group",
      id: `tg-${pending[0].id}`,
      tools: [...pending],
    });
  }
  return result;
}

function summarizeToolKinds(tools: ToolItem[]): string {
  const counts: Record<string, number> = {};
  for (const tool of tools) {
    counts[tool.label || "tool"] = (counts[tool.label || "tool"] || 0) + 1;
  }
  return Object.entries(counts)
    .map(([k, v]) => `${v} ${k}`)
    .join(", ");
}

function ExpandChevron({ open }: { open: boolean }) {
  return (
    <svg
      aria-hidden="true"
      className={`transcript-chevron${open ? " transcript-chevron--open" : ""}`}
      fill="none"
      height="12"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="2"
      viewBox="0 0 24 24"
      width="12"
    >
      <path d="m9 18 6-6-6-6" />
    </svg>
  );
}

function DoneCheck() {
  return (
    <svg
      aria-hidden="true"
      className="transcript-status-icon transcript-status-icon--done"
      fill="none"
      height="14"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="2"
      viewBox="0 0 24 24"
      width="14"
    >
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}

function TranscriptToolGroup({ tools }: { tools: ToolItem[] }) {
  const [open, setOpen] = useState(false);
  const kindSummary = summarizeToolKinds(tools);
  const allDone = tools.every((t) => !t.status);

  return (
    <div className="transcript-tool-group">
      <button
        className="transcript-tool-group__summary"
        onClick={() => setOpen(!open)}
        type="button"
      >
        <ExpandChevron open={open} />
        <span className="transcript-tool-group__count">
          {tools.length} tool call{tools.length > 1 ? "s" : ""}
        </span>
        <span className="transcript-tool-group__kinds">{kindSummary}</span>
        {allDone ? <DoneCheck /> : null}
      </button>
      {open ? (
        <div className="transcript-tool-group__list">
          {tools.map((tool) => (
            <TranscriptToolRow key={tool.id} tool={tool} />
          ))}
        </div>
      ) : null}
    </div>
  );
}

function TranscriptToolRow({ tool }: { tool: ToolItem }) {
  const [open, setOpen] = useState(false);
  const hasOutput = Boolean(tool.outputText || tool.errorText);

  return (
    <div className="transcript-tool-row">
      <button
        className="transcript-tool-row__header"
        disabled={!hasOutput}
        onClick={() => hasOutput && setOpen(!open)}
        type="button"
      >
        {hasOutput ? (
          <ExpandChevron open={open} />
        ) : (
          <span className="transcript-tool-row__spacer" />
        )}
        <span className="transcript-tool-row__kind">{tool.label}</span>
        <span className="transcript-tool-row__subject">{tool.subject}</span>
        {tool.status ? (
          <span
            className={`transcript-tool-row__badge transcript-tool-row__badge--${tool.status}`}
          >
            {tool.status}
          </span>
        ) : (
          <DoneCheck />
        )}
      </button>
      {open ? (
        <div className="transcript-tool-row__output">
          {tool.errorText ? (
            <pre className="transcript-tool-row__code transcript-tool-row__code--error">
              {tool.errorText}
            </pre>
          ) : null}
          {tool.outputText ? (
            <CodeBlock text={tool.outputText} />
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

function TranscriptThinkingBlock({
  item,
}: {
  item: Extract<TranscriptTimelineItem, { kind: "message" }>;
}) {
  const [open, setOpen] = useState(false);

  return (
    <div className="transcript-thinking">
      <button
        className="transcript-thinking__summary"
        onClick={() => setOpen(!open)}
        type="button"
      >
        <ExpandChevron open={open} />
        <span className="transcript-thinking__label">Thinking</span>
      </button>
      {open ? (
        <div className="transcript-thinking__content">
          <p className="transcript-thinking__text">{item.text}</p>
        </div>
      ) : null}
    </div>
  );
}

function TranscriptMessageBlock({
  item,
}: {
  item: Extract<TranscriptTimelineItem, { kind: "message" }>;
}) {
  const isUser = item.role === "user";
  const jsonContent =
    item.partType === "text" && isJsonLike(item.text)
      ? tryPrettyJson(item.text)
      : null;

  const content = jsonContent ? (
    <pre className="transcript-tool-row__code">
      {highlightJson(jsonContent)}
    </pre>
  ) : item.partType === "text" ? (
    <DocumentContent
      className="transcript-message__markdown"
      content={item.text}
      format="markdown"
      variant="compact"
    />
  ) : (
    <p className="transcript-message__text">{item.text}</p>
  );

  return (
    <div className={`transcript-message${isUser ? " transcript-message--user" : ""}`}>
      {isUser ? (
        <div className="transcript-message__bubble">{content}</div>
      ) : (
        content
      )}
    </div>
  );
}

/* ── JSON syntax highlighting ────────────────────────────── */

function isJsonLike(text: string): boolean {
  const trimmed = text.trimStart();
  return trimmed.startsWith("{") || trimmed.startsWith("[");
}

function tryPrettyJson(text: string): string | null {
  try {
    const parsed = JSON.parse(text);
    return JSON.stringify(parsed, null, 2);
  } catch {
    return null;
  }
}

function highlightJson(json: string): ReactNode[] {
  const parts: ReactNode[] = [];
  const regex =
    /("(?:[^"\\]|\\.)*")(\s*:)?|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(\btrue\b|\bfalse\b|\bnull\b)/g;
  let lastIndex = 0;
  let match: RegExpExecArray | null;
  let key = 0;

  while ((match = regex.exec(json)) !== null) {
    if (match.index > lastIndex) {
      parts.push(json.slice(lastIndex, match.index));
    }
    if (match[1] && match[2]) {
      parts.push(
        <span className="json-key" key={key++}>
          {match[1]}
        </span>,
      );
      parts.push(match[2]);
    } else if (match[1]) {
      parts.push(
        <span className="json-string" key={key++}>
          {match[1]}
        </span>,
      );
    } else if (match[3]) {
      parts.push(
        <span className="json-number" key={key++}>
          {match[3]}
        </span>,
      );
    } else if (match[4]) {
      parts.push(
        <span className="json-bool" key={key++}>
          {match[4]}
        </span>,
      );
    }
    lastIndex = match.index + match[0].length;
  }
  if (lastIndex < json.length) {
    parts.push(json.slice(lastIndex));
  }
  return parts;
}

function CodeBlock({ text }: { text: string }) {
  if (isJsonLike(text)) {
    const pretty = tryPrettyJson(text);
    if (pretty) {
      return (
        <pre className="transcript-tool-row__code">
          {highlightJson(pretty)}
        </pre>
      );
    }
  }
  return <pre className="transcript-tool-row__code">{text}</pre>;
}

function legacyTranscriptText(items: TranscriptTimelineItem[]): string {
  return items
    .flatMap((item) => {
      if (item.kind === "message") {
        return item.text;
      }
      if (item.kind === "tool") {
        const title = item.status && item.subject
          ? `${item.label} ${item.status}: ${item.subject}`
          : item.subject
            ? `${item.label}: ${item.subject}`
            : item.status
              ? `${item.label} ${item.status}`
              : item.label;
        return [
          title,
          item.outputText,
          item.errorText,
          item.paths.length > 0 ? item.paths.join(" · ") : undefined,
          ...item.diffs.map((diff) => diff.path || "file change"),
        ].filter(Boolean);
      }
      if (item.kind === "plan") {
        return [item.summary, ...item.steps.map((step) => `${step.status === "completed" ? "✓" : "•"} ${step.text}`)];
      }
      if (item.kind === "usage") {
        return item.summary;
      }
      return item.raw;
    })
    .join("\n");
}

/* ── Panes ───────────────────────────────────────────────── */

export function TaskOverviewPane({
  task,
  runCount,
  artifactCount,
}: OverviewPaneProps) {
  return (
    <div className="detail-pane" data-testid="overview-pane">
      <PanelHeader
        subtitle="Task summary and task-level actions"
        title={task?.task.description || "Task"}
      />

      <div className="detail-info-cards">
        <DetailInfoCard
          detail={task?.current_node_name || "No active node"}
          label="Status"
          value={task ? detailStatusLabel(task.status) : "Unknown"}
        />
        <DetailInfoCard
          detail="Across task history"
          label="Runs"
          value={runCount}
        />
        <DetailInfoCard
          detail="Files and previews attached to the task"
          label="Artifacts"
          value={artifactCount}
        />
      </div>

      {task?.current_issue ? (
        <section className="detail-note-card detail-note-card--warning">
          <span className="detail-section__label">Current issue</span>
          <strong>{task.current_issue.reason}</strong>
          <p>
            {task.current_issue.node_name} · iteration {task.current_issue.iteration}
          </p>
        </section>
      ) : null}
    </div>
  );
}

export function TaskRunPane({
  run,
  streamLines,
  transcript,
  transcriptItems,
  streamSource,
  isCurrentRun,
  artifactCount,
  showEmptyOutput,
}: RunPaneProps) {
  if (!run) {
    return (
      <div className="detail-pane" data-testid="run-pane">
        <PanelHeader
          subtitle="Select a run from the navigator to inspect its detail."
          title="Run detail"
        />
        <div className="detail-empty-card">
          <strong>No run selected</strong>
          <p>Choose a run from the navigator to inspect its history, outputs, and artifacts.</p>
        </div>
      </div>
    );
  }

  const liveTitle = `Run · ${run.node_name}`;
  const resultContent = prettyResult(run.result);
  const clarificationHistory = run.clarifications ?? [];
  const hasStreamOutput = streamLines.length > 0;
  const historyProvenance = formatHistoryProvenance(transcript.provenance);
  const historyCompleteness = formatHistoryCompleteness(transcript.completeness);
  const historyStatusDetail = describeHistoryStatus(streamSource, transcript);
  const sessionValue = shortenSessionId(transcript.sessionId || run.session_id);
  const sessionDetail = transcript.sessionId || run.session_id || "Awaiting session id";
  const transcriptAvailability = describeTranscriptAvailability(
    streamSource,
    transcript,
    run,
    isCurrentRun,
  );

  function renderTranscriptItem(item: TranscriptTimelineItem) {
    if (item.kind === "message") {
      return (
        <div className="detail-transcript-row detail-transcript-row--message" key={item.id}>
          <span className="detail-transcript-row__eyebrow">
            {item.partType === "reasoning" ? "thinking" : item.role}
          </span>
          <p className="detail-transcript-row__text">{item.text}</p>
        </div>
      );
    }
    if (item.kind === "tool") {
      return (
        <div className="detail-transcript-row" key={item.id}>
          <strong className="detail-transcript-row__title">
            {item.status && item.subject
              ? `${item.label} ${item.status}: ${item.subject}`
              : item.subject
                ? `${item.label}: ${item.subject}`
                : item.status
                  ? `${item.label} ${item.status}`
                  : item.label}
          </strong>
          {item.outputText ? (
            <pre className="detail-code-block detail-code-block--inline">
              {item.outputText}
            </pre>
          ) : null}
          {item.errorText ? (
            <p className="detail-transcript-row__text">{item.errorText}</p>
          ) : null}
          {item.paths.length > 0 ? (
            <p className="detail-transcript-row__meta">
              {item.paths.join(" · ")}
            </p>
          ) : null}
          {item.diffs.length > 0 ? (
            <div className="detail-transcript-row__list">
              {item.diffs.map((diff, index) => (
                <span key={`${item.id}-diff-${index}`}>{diff.path || "file change"}</span>
              ))}
            </div>
          ) : null}
        </div>
      );
    }
    if (item.kind === "plan") {
      return (
        <div className="detail-transcript-row detail-transcript-row--plan" key={item.id}>
          <strong className="detail-transcript-row__title">{item.summary}</strong>
          {item.steps.length > 0 ? (
            <div className="detail-transcript-row__list">
              {item.steps.map((step, index) => (
                <span key={`${item.id}-step-${index}`}>
                  {step.status === "completed" ? "✓" : "•"} {step.text}
                </span>
              ))}
            </div>
          ) : null}
        </div>
      );
    }
    if (item.kind === "usage") {
      return (
        <div className="detail-transcript-row detail-transcript-row--usage" key={item.id}>
          <strong className="detail-transcript-row__title">{item.summary}</strong>
          <p className="detail-transcript-row__meta">
            total {item.usage.totalTokens ?? 0}
            {item.usage.durationMs ? ` · ${item.usage.durationMs} ms` : ""}
          </p>
        </div>
      );
    }
    return (
      <div className="detail-transcript-row detail-transcript-row--raw" key={item.id}>
        <span className="detail-transcript-row__eyebrow">raw</span>
        <pre className="detail-code-block detail-code-block--inline">{item.raw}</pre>
      </div>
    );
  }

  return (
    <div
      className="detail-pane detail-pane--run"
      data-testid={streamSource === "live" ? "live-pane" : "run-pane"}
    >
      <PanelHeader subtitle={formatRunSubtitle(run)} title={liveTitle} />

      <div className="detail-meta-row">
        <span className="detail-meta-chip">
          <span className="detail-meta-chip__label">Artifacts</span>
          <span className="detail-meta-chip__value">{artifactCount}</span>
        </span>
        {run.triggered_by ? (
          <span className="detail-meta-chip">
            <span className="detail-meta-chip__label">Triggered by</span>
            <span className="detail-meta-chip__value">
              {run.triggered_by.reason}
            </span>
          </span>
        ) : null}
      </div>

      <div hidden>
        <span data-testid="detail-run-session">
          {sessionValue} {sessionDetail}
        </span>
        <span data-testid="detail-run-history-source">
          {historyProvenance} {historyStatusDetail}
        </span>
        <span data-testid="detail-run-history-completeness">
          {historyCompleteness}{" "}
          {transcript.lastSeq != null
            ? `last event seq ${transcript.lastSeq}`
            : transcript.events.length > 0
              ? `${transcript.events.length} event${transcript.events.length === 1 ? "" : "s"} loaded`
              : "No persisted event sequence yet"}
        </span>
      </div>

      {clarificationHistory.length > 0 ? (
        <DetailSection label="Clarifications">
          <div className="detail-list-card">
            {clarificationHistory.map((exchange, index) => {
              const request = (exchange.request ?? {}) as {
                questions?: Array<{ question?: string }>;
              };
              const response = (exchange.response ?? {}) as {
                answers?: Array<{ selected?: unknown }>;
              };
              return (
                <div className="detail-list-card__row" key={`${run.id}-clarification-${index}`}>
                  <strong>
                    {request.questions?.[0]?.question ?? `Clarification ${index + 1}`}
                  </strong>
                  <p>
                    {response.answers?.length
                      ? response.answers
                          .map((answer) => formatClarificationAnswer(answer.selected))
                          .filter(Boolean)
                          .join(" · ")
                      : "Awaiting response"}
                  </p>
                </div>
              );
            })}
          </div>
        </DetailSection>
      ) : null}

      {(() => {
        const grouped = groupTranscriptItems(transcriptItems);
        if (grouped.length > 0) {
          return (
            <div data-testid="detail-output-surface">
              <pre hidden>{legacyTranscriptText(transcriptItems)}</pre>
              <div className="transcript-timeline" data-testid="transcript-timeline">
                {grouped.map((item) => {
                  if (item.kind === "tool-group") {
                    return (
                      <TranscriptToolGroup key={item.id} tools={item.tools} />
                    );
                  }
                  if (item.kind === "message" && item.partType === "reasoning") {
                    return <TranscriptThinkingBlock key={item.id} item={item} />;
                  }
                  if (item.kind === "message") {
                    return <TranscriptMessageBlock key={item.id} item={item} />;
                  }
                  return renderTranscriptItem(item);
                })}
              </div>
            </div>
          );
        }
        if (hasStreamOutput) {
          return (
            <div data-testid="detail-output-surface">
              <pre className="detail-code-block">{streamLines.join("\n")}</pre>
            </div>
          );
        }
        if (resultContent) {
          return (
            <div data-testid="detail-output-surface">
              <pre className="detail-code-block">{resultContent}</pre>
            </div>
          );
        }
        if (showEmptyOutput) {
          return (
            <div data-testid="detail-output-surface">
              <div className="detail-empty-card detail-empty-card--embedded">
                <strong>{transcriptAvailability.title}</strong>
                <p>{transcriptAvailability.detail}</p>
              </div>
            </div>
          );
        }
        return null;
      })()}
    </div>
  );
}

export function TaskArtifactPane({
  artifact,
  content,
  error,
}: ArtifactPaneProps) {
  return (
    <div className="detail-pane" data-testid="artifact-pane">
      <PanelHeader
        subtitle={artifact?.node_name ?? "Artifact preview"}
        title={artifact?.preview_name ? `Preview · ${artifact.preview_name}` : "Preview"}
      />

      {error ? <p className="screen-error">{error}</p> : null}

      <DetailSurface
        bodyClassName="detail-output-card detail-output-card--artifact"
        label="Preview"
        testId="detail-preview-surface"
      >
        <DocumentContent
          content={content ?? "Loading artifact..."}
          format={artifact?.markdown ? "markdown" : "text"}
          variant="detail"
        />
      </DetailSurface>
    </div>
  );
}

export function TaskApprovalDock({
  feedback,
  setFeedback,
  submittingDecision,
  submitApprove,
  submitReject,
  nodeName,
}: ApprovalDockProps) {
  return (
    <section className="detail-surface-panel" data-testid="approval-pane">
      <div className="detail-surface-panel__header">
        <span className="detail-surface-panel__title">
          {nodeName ? `${nodeName} needs approval` : "Approval required"}
        </span>
      </div>
      <div className="detail-surface-panel__body">
        <label className="field-block">
          <span className="field-block__hint">Feedback (optional)</span>
          <textarea
            className="approval-feedback approval-feedback--compact"
            onChange={(event) => setFeedback(event.target.value)}
            placeholder="Add feedback…"
            rows={2}
            value={feedback}
          />
        </label>

        <div className="detail-surface-panel__footer">
          <button
            className="secondary-action secondary-action--danger"
            data-testid="approval-reject"
            disabled={submittingDecision}
            onClick={() => void submitReject()}
            type="button"
          >
            Reject
          </button>
          <button
            className="primary-action"
            data-testid="approval-approve"
            disabled={submittingDecision}
            onClick={() => void submitApprove()}
            type="button"
          >
            Approve
          </button>
        </div>
      </div>
    </section>
  );
}

function ClarificationQuestionField({
  question,
  index,
  answer,
  setAnswer,
  labelId,
  descriptionId,
}: {
  question: InputQuestionDto;
  index: number;
  answer: string | string[];
  setAnswer: (index: number, value: string | string[]) => void;
  labelId: string;
  descriptionId?: string;
}) {
  const options = question.options ?? [];
  const isMultiSelect = question.multi_select;

  if (options.length === 0) {
    return (
      <textarea
        aria-describedby={descriptionId}
        aria-labelledby={labelId}
        className="approval-feedback approval-feedback--compact"
        onChange={(event) => setAnswer(index, event.target.value)}
        placeholder="Answer this clarification…"
        rows={3}
        value={typeof answer === "string" ? answer : answer.join(", ")}
      />
    );
  }

  const isOther = !isMultiSelect
    ? typeof answer === "string" && !options.some((o) => o.label === answer) && answer !== ""
    : false;
  const [otherText, setOtherText] = useState(isOther ? (answer as string) : "");
  const otherSelected = isOther || (!isMultiSelect && answer === `__other__:${otherText}`);

  return (
    <div className={`detail-choice-list${isMultiSelect ? " detail-choice-list--multi" : ""}`}>
      {options.map((option) => {
        const checked = Array.isArray(answer)
          ? answer.includes(option.label)
          : answer === option.label;
        return (
          <label className={`detail-choice${checked ? " is-selected" : ""}`} key={option.label}>
            <input
              checked={checked}
              className="detail-choice__input"
              name={`clarification-${index}`}
              onChange={(event) => {
                if (isMultiSelect) {
                  const current = Array.isArray(answer) ? answer : [];
                  const next = event.target.checked
                    ? [...new Set([...current, option.label])]
                    : current.filter((entry) => entry !== option.label);
                  setAnswer(index, next);
                } else {
                  setAnswer(index, option.label);
                }
              }}
              type={isMultiSelect ? "checkbox" : "radio"}
            />
            <span className="detail-choice__control" aria-hidden="true" />
            <span className="detail-choice__copy">
              <strong>{option.label}</strong>
              {option.description ? <small>{option.description}</small> : null}
            </span>
          </label>
        );
      })}
      <label className={`detail-choice detail-choice--other${otherSelected ? " is-selected" : ""}`}>
        <input
          checked={otherSelected}
          className="detail-choice__input"
          name={`clarification-${index}`}
          onChange={() => {
            if (isMultiSelect) {
              const current = Array.isArray(answer) ? answer : [];
              if (!otherText) return;
              if (!current.includes(otherText)) {
                setAnswer(index, [...current, otherText]);
              }
            } else {
              setAnswer(index, otherText || "");
            }
          }}
          type={isMultiSelect ? "checkbox" : "radio"}
        />
        <span className="detail-choice__control" aria-hidden="true" />
        <span className="detail-choice__copy detail-choice__copy--other">
          <strong>Other:</strong>
          <input
            className="detail-choice__other-input"
            onChange={(event) => {
              setOtherText(event.target.value);
              if (isMultiSelect) {
                const current = Array.isArray(answer) ? answer : [];
                const withoutOld = current.filter((v) => v !== otherText);
                if (event.target.value) {
                  setAnswer(index, [...withoutOld, event.target.value]);
                } else {
                  setAnswer(index, withoutOld);
                }
              } else {
                setAnswer(index, event.target.value);
              }
            }}
            onFocus={() => {
              if (!isMultiSelect) {
                setAnswer(index, otherText || "");
              }
            }}
            placeholder="Type your own answer..."
            type="text"
            value={otherText}
          />
        </span>
      </label>
    </div>
  );
}

export function TaskClarificationDock({
  nodeName,
  requestKey,
  questions,
  answers,
  setAnswer,
  submittingClarification,
  submitClarification,
}: ClarificationDockProps) {
  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
    setActiveIndex(0);
  }, [requestKey]);

  useEffect(() => {
    setActiveIndex((current) =>
      Math.min(current, Math.max(questions.length - 1, 0)),
    );
  }, [questions.length]);

  const activeQuestion = questions[activeIndex];
  const activeAnswer = answers[activeIndex] ?? (activeQuestion?.multi_select ? [] : "");
  const questionId = `clarification-question-${requestKey ?? "task"}-${activeIndex}`;
  const descriptionId = activeQuestion?.why_it_matters
    ? `clarification-why-${requestKey ?? "task"}-${activeIndex}`
    : undefined;

  return (
    <section className="detail-surface-panel" data-testid="clarification-pane">
      <div className="detail-surface-panel__header detail-surface-panel__header--attention">
        <span className="detail-surface-panel__title">
          <svg
            aria-hidden="true"
            className="detail-surface-panel__title-icon"
            fill="none"
            height="14"
            viewBox="0 0 14 14"
            width="14"
          >
            <path
              d="M4.667 10.5 2.333 11.667V3.5a1.167 1.167 0 0 1 1.167-1.167h7a1.167 1.167 0 0 1 1.167 1.167v5.833A1.167 1.167 0 0 1 10.5 10.5H4.667Z"
              stroke="currentColor"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="1.1"
            />
          </svg>
          {nodeName ? `${nodeName} needs clarification` : "Clarification needed"}
        </span>
        {questions.length > 1 ? (
          <div className="detail-clarification__nav">
            <button
              aria-label="Previous clarification"
              className="detail-clarification__nav-button"
              disabled={activeIndex === 0}
              onClick={() => setActiveIndex((current) => Math.max(current - 1, 0))}
              type="button"
            >
              <svg aria-hidden="true" fill="none" height="14" viewBox="0 0 14 14" width="14">
                <path
                  d="M8.75 3.5 5.25 7l3.5 3.5"
                  stroke="currentColor"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="1.2"
                />
              </svg>
            </button>
            <span className="detail-clarification__nav-count">
              {activeIndex + 1} / {questions.length}
            </span>
            <button
              aria-label="Next clarification"
              className="detail-clarification__nav-button"
              disabled={activeIndex === questions.length - 1}
              onClick={() =>
                setActiveIndex((current) => Math.min(current + 1, questions.length - 1))
              }
              type="button"
            >
              <svg aria-hidden="true" fill="none" height="14" viewBox="0 0 14 14" width="14">
                <path
                  d="M5.25 3.5 8.75 7l-3.5 3.5"
                  stroke="currentColor"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="1.2"
                />
              </svg>
            </button>
          </div>
        ) : null}
      </div>

      <div className="detail-surface-panel__body">
        {activeQuestion ? (
          <div className="detail-clarification__question">
            <div className="detail-clarification__copy">
              <strong id={questionId}>{activeQuestion.question}</strong>
              {activeQuestion.why_it_matters ? (
                <p id={descriptionId}>{activeQuestion.why_it_matters}</p>
              ) : null}
            </div>
            <ClarificationQuestionField
              answer={activeAnswer}
              index={activeIndex}
              descriptionId={descriptionId}
              labelId={questionId}
              question={activeQuestion}
              setAnswer={setAnswer}
            />
          </div>
        ) : (
          <p className="muted-copy">No clarification questions were provided.</p>
        )}

        <div className="detail-surface-panel__footer">
          <button
            className="primary-action"
            disabled={submittingClarification}
            onClick={() => void submitClarification()}
            type="button"
          >
            {submittingClarification ? "Sending…" : "Submit"}
          </button>
        </div>
      </div>
    </section>
  );
}

export function TaskRetryDock({
  run,
  failureReason,
  submittingRetry,
  onRetry,
}: RetryDockProps) {
  return (
    <RecoveryCard
      actions={
        <button
          className="primary-action"
          data-testid="retry-step"
          disabled={submittingRetry || !run}
          onClick={() => void onRetry(false)}
          type="button"
        >
          {submittingRetry ? "Retrying…" : "Retry"}
        </button>
      }
      description={failureReason ?? "The current task requires intervention."}
      testId="failed-pane"
      title={run?.node_name ? `Task failed at ${run.node_name} node` : "Task failed"}
      tone="failed"
    />
  );
}

export function TaskFollowUpDock({
  configEntries,
  followUpConfigAlias,
  followUpDescription,
  setFollowUpDescription,
  onConfigChange,
  submittingFollowUp,
  onStartFollowUp,
}: FollowUpDockProps) {
  const launchable = configEntries.filter((e) => e.launchable);
  const selectedDescription = launchable.find((e) => e.alias === followUpConfigAlias)?.description;

  return (
    <section className="detail-surface-panel" data-testid="complete-pane">
      <div className="detail-surface-panel__header">
        <span className="detail-surface-panel__title">Follow-up task</span>
      </div>
      <div className="detail-surface-panel__body">
        {launchable.length > 1 ? (
          <div className="follow-up-config">
            <div className="follow-up-config__pills">
              {launchable.map((entry) => (
                <button
                  className={`follow-up-config__pill${entry.alias === followUpConfigAlias ? " is-selected" : ""}`}
                  key={entry.alias}
                  onClick={() => onConfigChange(entry.alias)}
                  type="button"
                >
                  {entry.alias}
                </button>
              ))}
            </div>
            {selectedDescription ? (
              <span className="follow-up-config__desc">{selectedDescription}</span>
            ) : null}
          </div>
        ) : null}
        <label className="field-block">
          <span className="field-block__label">Describe the follow-up</span>
          <textarea
            aria-label="Describe the follow-up"
            className="approval-feedback approval-feedback--compact"
            data-testid="follow-up-description"
            onChange={(event) => setFollowUpDescription(event.target.value)}
            placeholder="Continue from here..."
            rows={3}
            value={followUpDescription}
          />
        </label>
        <div className="detail-surface-panel__footer">
          <button
            className="primary-action"
            data-testid="start-follow-up"
            disabled={submittingFollowUp || !followUpDescription.trim()}
            onClick={() => void onStartFollowUp()}
            type="button"
          >
            {submittingFollowUp ? "Starting…" : "Start follow-up"}
          </button>
        </div>
      </div>
    </section>
  );
}

export function TaskBlockedDock({
  blockedStep,
  submittingContinue,
  onContinue,
}: BlockedDockProps) {
  return (
    <RecoveryCard
      actions={
        <button
          className="primary-action"
          data-testid="continue-blocked"
          disabled={submittingContinue}
          onClick={() => void onContinue()}
          type="button"
        >
          {submittingContinue ? "Continuing…" : "Continue"}
        </button>
      }
      description={blockedStep?.reason ?? "The current task is waiting to continue."}
      testId="blocked-pane"
      title={
        blockedStep?.node_name
          ? `Task paused at ${blockedStep.node_name}`
          : "Task is waiting to continue"
      }
      tone="blocked"
    />
  );
}
