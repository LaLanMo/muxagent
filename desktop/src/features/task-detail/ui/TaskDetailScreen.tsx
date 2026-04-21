import { useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import {
  Bot,
  Check,
  ChevronDown,
  CircleDashed,
  CircleDot,
  CircleX,
  FileText,
  Loader,
  User,
  type LucideIcon,
} from "lucide-react";
import {
  detailStatusLabel,
  formatRelativeTime,
  isWorktreeTask,
  taskLaunchModeLabel,
} from "@/domain/task-shell";
import type { WorkbenchTabId } from "@/domain/routes";
import {
  buildTranscriptSnapshot,
  type SessionHistoryEvent,
  type TranscriptSnapshot,
} from "@/domain/session-history";
import {
  deriveTranscriptTimelineItems,
  timelineItemsToLines,
  type RunningActivityPreviewRow,
  type TranscriptTimelineItem,
} from "@/features/task-history/model/timeline";
import {
  useWorkbenchRegions,
  useWorkbenchTab,
} from "@/features/layout/ui/workbench-surface";
import { Button } from "@/features/shared/ui/Button";
import { DocumentContent } from "@/features/shared/ui/DocumentContent";
import { ConfirmDialog } from "@/features/shared/ui/ConfirmDialog";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import { Toast } from "@/features/shared/ui/Toast";
import { WorktreeGlyph } from "@/features/shared/ui/WorktreeGlyph";
import type {
  ActivityRunActorType,
  TaskDetailHistoryEntry,
  TaskDetailActionSurface,
} from "@/features/task-detail/model/use-task-detail-screen";
import type { FollowUpDockState } from "@/features/task-detail/model/follow-up-dock-state";
import type { TaskDetailArtifactPreview } from "@/features/task-detail/model/use-task-detail-artifact-preview";
import type { TaskDetailModal, TaskDetailSelection } from "@/features/task-detail/model/use-task-detail-selection";
import {
  TaskApprovalDock,
  TaskArtifactModal,
  TaskBlockedDock,
  TaskClarificationDock,
  TaskFollowUpDock,
  TaskRetryDock,
  TaskTranscriptModal,
} from "@/features/task-detail/ui/TaskDetailPanels";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  ClarificationExchangeDto,
  ConfigCatalogEntryDto,
  ConfigViewDto,
  FollowUpModeDto,
  ImageAttachmentInputDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskFollowUpDto,
  TaskViewDto,
  WorktreeCleanupInfoDto,
} from "@/rpc/types";
import type { RunHistoryCacheEntry } from "@/state/task-snapshot-store";

type StageNode = {
  name: string;
  status: "done" | "current" | "pending" | "failed";
};

const stageStatusIcons: Record<StageNode["status"], LucideIcon> = {
  done: Check,
  current: Loader,
  pending: CircleDashed,
  failed: CircleX,
};
const emptyRunningActivityPreview: RunningActivityPreviewRow[] = [];

function StageNodeIcon({ status }: { status: StageNode["status"] }) {
  const Icon = stageStatusIcons[status];
  return <Icon size={10} strokeWidth={2.2} />;
}

function ActivityRunIcon({
  actorType,
}: {
  actorType: ActivityRunActorType;
}) {
  const Icon = actorType === "human" ? User : Bot;
  return <Icon size={14} strokeWidth={1.9} />;
}

function formatRunTiming(run: NodeRunViewDto) {
  const relative = formatRelativeTime(run.completed_at ?? run.started_at);
  const start = Date.parse(run.started_at);
  const end = Date.parse(run.completed_at ?? "");
  if (
    Number.isFinite(start) &&
    Number.isFinite(end) &&
    end > start &&
    Date.now() - end < 24 * 60 * 60 * 1000
  ) {
    return {
      duration: formatDuration(Math.max(1, Math.floor((end - start) / 1000))),
      relative,
    };
  }
  return { relative };
}

function formatCount(count: number, singular: string, plural: string) {
  return `${count} ${count === 1 ? singular : plural}`;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function formatAbsoluteStamp(iso: string | undefined) {
  if (!iso) {
    return "—";
  }
  const value = new Date(iso);
  if (Number.isNaN(value.getTime())) {
    return "—";
  }
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(value);
}

function formatDuration(totalSeconds: number) {
  if (totalSeconds < 60) {
    return `${Math.max(1, totalSeconds)}s`;
  }
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const hours = Math.floor(minutes / 60);
  if (hours > 0) {
    return `${hours}h ${minutes % 60}m`;
  }
  return `${minutes}m ${seconds}s`;
}

function summarizeTaskDuration(task: TaskViewDto | undefined, runs: NodeRunViewDto[]) {
  const starts = runs
    .map((run) => Date.parse(run.started_at))
    .filter((value) => Number.isFinite(value));
  if (starts.length === 0) {
    return "Not started";
  }
  const start = Math.min(...starts);
  const hasOpenRun = runs.some((run) => {
    const label = detailStatusLabel(run.status);
    return label === "running" || label === "awaiting";
  });
  const ends = runs
    .map((run) => Date.parse(run.completed_at ?? ""))
    .filter((value) => Number.isFinite(value));
  const end = hasOpenRun ? Date.now() : ends.length > 0 ? Math.max(...ends) : Date.now();
  const duration = formatDuration(Math.max(1, Math.floor((end - start) / 1000)));
  const taskStatus = task ? detailStatusLabel(task.status) : "pending";
  return taskStatus === "running" || taskStatus === "awaiting"
    ? `${duration} (${taskStatus})`
    : duration;
}

function summarizeRuns(runs: NodeRunViewDto[]) {
  let done = 0;
  let running = 0;
  let pending = 0;
  let failed = 0;

  for (const run of runs) {
    switch (detailStatusLabel(run.status)) {
      case "done":
        done += 1;
        break;
      case "running":
        running += 1;
        break;
      case "awaiting":
      case "pending":
        pending += 1;
        break;
      case "failed":
        failed += 1;
        break;
    }
  }

  return [
    `${runs.length} total`,
    done > 0 ? `${done} done` : undefined,
    running > 0 ? `${running} running` : undefined,
    pending > 0 ? `${pending} pending` : undefined,
    failed > 0 ? `${failed} failed` : undefined,
  ]
    .filter(Boolean)
    .join(" · ");
}

function normalizeTranscriptText(value: string | undefined) {
  return value?.replace(/\s+/g, " ").trim() ?? "";
}

function formatClarificationSelection(selected: string | string[] | undefined) {
  if (typeof selected === "string") {
    return selected.trim();
  }
  if (!Array.isArray(selected)) {
    return "";
  }
  return selected
    .map((value) => value.trim())
    .filter(Boolean)
    .join(", ");
}

function clarificationExchangeText(
  exchange: ClarificationExchangeDto,
): string | undefined {
  const questions = exchange.request?.questions ?? [];
  const answers = exchange.response?.answers ?? [];
  const pairs = answers
    .map((answer, index) => {
      const selected = formatClarificationSelection(answer.selected);
      if (!selected) {
        return undefined;
      }
      return {
        answer: selected,
        question: questions[index]?.question?.trim() || `Question ${index + 1}`,
      };
    })
    .filter((entry): entry is { answer: string; question: string } => Boolean(entry));
  if (pairs.length === 0) {
    return undefined;
  }
  if (pairs.length === 1 && questions.length <= 1) {
    return pairs[0].answer;
  }
  return pairs
    .map(({ question, answer }) => `**${question}**\n${answer}`)
    .join("\n\n");
}

type ClarificationTranscriptItem = Extract<TranscriptTimelineItem, { kind: "message" }> & {
  mergeAt?: number;
};

function parseTranscriptTimestamp(value: string | undefined): number | undefined {
  const parsed = Date.parse(value ?? "");
  return Number.isFinite(parsed) ? parsed : undefined;
}

function transcriptItemTimestamps(transcript: TranscriptSnapshot) {
  const eventTimes = new Map<string, number>();
  for (const event of transcript.events) {
    const timestamp = parseTranscriptTimestamp(event.at ?? event.recordedAt);
    if (timestamp != null) {
      eventTimes.set(event.id, timestamp);
    }
  }

  const messageTimes = new Map<string, number>();
  for (const messageId of transcript.messageOrder) {
    const message = transcript.messages[messageId];
    if (!message) {
      continue;
    }
    for (const part of message.parts) {
      const lastEventId = part.eventIds.at(-1);
      const timestamp = lastEventId ? eventTimes.get(lastEventId) : undefined;
      if (timestamp != null) {
        messageTimes.set(`${message.id}:${part.id}`, timestamp);
      }
    }
  }

  const toolTimes = new Map<string, number>();
  for (const toolId of transcript.toolOrder) {
    const tool = transcript.tools[toolId];
    const lastEventId = tool?.eventIds.at(-1);
    const timestamp = lastEventId ? eventTimes.get(lastEventId) : undefined;
    if (timestamp != null) {
      toolTimes.set(toolId, timestamp);
    }
  }

  return {
    eventTimes,
    messageTimes,
    toolTimes,
  };
}

function rawTranscriptItemTimestamp(args: {
  item: TranscriptTimelineItem;
  timestamps: ReturnType<typeof transcriptItemTimestamps>;
}): number | undefined {
  const { item, timestamps } = args;
  if (item.kind === "message") {
    return timestamps.messageTimes.get(item.id);
  }
  if (item.kind === "tool") {
    return timestamps.toolTimes.get(item.id);
  }
  const timestamp = timestamps.eventTimes.get(item.id);
  return timestamp;
}

function clarificationTranscriptItems(args: {
  rawTranscriptItems: TranscriptTimelineItem[];
  run: NodeRunViewDto | undefined;
}): ClarificationTranscriptItem[] {
  const { rawTranscriptItems, run } = args;
  if (!run?.clarifications?.length) {
    return [];
  }
  const rawUserMessages = new Set(
    rawTranscriptItems
      .filter(
        (item): item is Extract<TranscriptTimelineItem, { kind: "message" }> =>
          item.kind === "message" && item.role === "user",
      )
      .map((item) => normalizeTranscriptText(item.text)),
  );

  return run.clarifications.flatMap((exchange, index) => {
    const text = clarificationExchangeText(exchange);
    if (!text) {
      return [];
    }
    if (rawUserMessages.has(normalizeTranscriptText(text))) {
      return [];
    }
    return [
      {
        id: `clarification:${run.id}:${index}`,
        kind: "message" as const,
        role: "user",
        partType: "text",
        text,
        source: "clarification",
        mergeAt:
          parseTranscriptTimestamp(exchange.responded_at) ??
          parseTranscriptTimestamp(exchange.created_at),
      },
    ];
  });
}

function mergeDisplayTranscriptItems(args: {
  clarificationItems: ClarificationTranscriptItem[];
  rawTranscriptItems: TranscriptTimelineItem[];
  transcript: TranscriptSnapshot;
}): TranscriptTimelineItem[] {
  const { clarificationItems, rawTranscriptItems, transcript } = args;
  if (clarificationItems.length === 0) {
    return rawTranscriptItems;
  }
  if (rawTranscriptItems.length === 0) {
    return clarificationItems;
  }

  const timestamps = transcriptItemTimestamps(transcript);
  const rawEntries = rawTranscriptItems.map((item) => ({
    item,
    timestamp: rawTranscriptItemTimestamp({
      item,
      timestamps,
    }),
  }));
  const mergedItems: TranscriptTimelineItem[] = [];
  const pendingUndatedClarifications: ClarificationTranscriptItem[] = [];
  let rawIndex = 0;

  for (const clarificationItem of clarificationItems) {
    if (clarificationItem.mergeAt == null) {
      pendingUndatedClarifications.push(clarificationItem);
      continue;
    }

    while (rawIndex < rawEntries.length) {
      const rawEntry = rawEntries[rawIndex];
      if (
        rawEntry.timestamp != null &&
        rawEntry.timestamp > clarificationItem.mergeAt
      ) {
        break;
      }
      mergedItems.push(rawEntry.item);
      rawIndex += 1;
    }

    if (pendingUndatedClarifications.length > 0) {
      mergedItems.push(...pendingUndatedClarifications);
      pendingUndatedClarifications.length = 0;
    }
    mergedItems.push(clarificationItem);
  }

  while (rawIndex < rawEntries.length) {
    mergedItems.push(rawEntries[rawIndex].item);
    rawIndex += 1;
  }

  if (pendingUndatedClarifications.length > 0) {
    mergedItems.push(...pendingUndatedClarifications);
  }

  return mergedItems;
}

function artifactsForRun(run: NodeRunViewDto, artifacts: ArtifactRefDto[]) {
  return artifacts.filter((artifact) => {
    if (artifact.node_run_id && artifact.node_run_id === run.id) {
      return true;
    }
    return (
      run.artifact_paths?.includes(artifact.raw_path) ||
      run.artifact_paths?.includes(artifact.preview_name)
    );
  });
}

function activityCardTone(args: {
  run: NodeRunViewDto;
  actionRunId?: string;
  actionKind: TaskDetailActionSurface["kind"];
}) {
  const { run, actionRunId, actionKind } = args;
  if (actionRunId === run.id) {
    if (actionKind === "retry") {
      return "failed";
    }
    if (actionKind !== "none" && actionKind !== "follow_up") {
      return "awaiting";
    }
  }

  switch (detailStatusLabel(run.status)) {
    case "awaiting":
      return "awaiting";
    case "failed":
      return "failed";
    case "running":
      return "running";
    case "done":
      return "done";
    default:
      return "default";
  }
}

function activityMeta(run: NodeRunViewDto, artifactCount: number) {
  const status = detailStatusLabel(run.status);
  if (status === "failed" && run.failure_reason) {
    return run.failure_reason;
  }
  if (status === "awaiting") {
    return "waiting for input";
  }
  if (artifactCount > 0) {
    return formatCount(artifactCount, "artifact", "artifacts");
  }
  return undefined;
}

function completedRunSummary(run: NodeRunViewDto) {
  if (detailStatusLabel(run.status) !== "done") {
    return "";
  }
  const summary = run.result?.summary;
  return typeof summary === "string" ? summary.trim() : "";
}

type TaskDetailScreenProps = {
  shell?: unknown;
  task?: TaskViewDto;
  config?: ConfigViewDto;
  loading: boolean;
  detailError?: string;
  historyEntries: TaskDetailHistoryEntry[];
  title: string;
  statusLabel: string;
  statusTone: "running" | "awaiting" | "done" | "failed" | "neutral";
  configLabel: string;
  elapsedLabel: string;
  stageNodes: StageNode[];
  timelineRuns: NodeRunViewDto[];
  runningActivityPreviewByRunId: Record<string, RunningActivityPreviewRow[]>;
  activityPreviewSignature: string;
  activityRunActorTypes: Record<string, ActivityRunActorType>;
  artifacts: ArtifactRefDto[];
  selection: TaskDetailSelection;
  modal: TaskDetailModal;
  currentRun?: NodeRunViewDto;
  selectedRun?: NodeRunViewDto;
  selectedArtifact?: ArtifactRefDto;
  artifactPreview?: TaskDetailArtifactPreview;
  artifactError?: string;
  artifactActionError?: string;
  liveEvents: SessionHistoryEvent[];
  liveEventsRunId?: string;
  selectedRunHistory?: RunHistoryCacheEntry;
  selectedRunFullHistory?: RunHistoryCacheEntry;
  workspaceActorState: string;
  staleReconcilePending: boolean;
  supportsRunRecovery: boolean;
  actionSurface: TaskDetailActionSurface;
  inputRequest?: InputRequestDto;
  blockedStep?: BlockedStepDto;
  submittingClarification: boolean;
  submittingDecision: boolean;
  followUp?: TaskFollowUpDto;
  followUpState?: FollowUpDockState;
  worktreeCleanupInfo?: WorktreeCleanupInfoDto;
  worktreeCleanupLoading: boolean;
  worktreeCleanupError?: string;
  retryWorktreeCleanupInfo: () => void;
  configEntries: ConfigCatalogEntryDto[];
  submittingFollowUp: boolean;
  worktreeCleanupDialogOpen: boolean;
  submittingWorktreeCleanup: boolean;
  submittingRetry: boolean;
  submittingContinue: boolean;
  submittingRecovery: boolean;
  failureReason?: string;
  selectOverview: () => void;
  selectRun: (runId: string) => void;
  openAncestorTask: (taskId: string) => void;
  openTranscript: (runId: string) => void;
  openArtifact: (artifact: ArtifactRefDto) => void;
  openArtifactExternally: () => Promise<void>;
  submitApprove: (
    feedback: string,
    imageAttachments?: ImageAttachmentInputDto[],
  ) => Promise<void>;
  submitReject: (
    feedback: string,
    imageAttachments?: ImageAttachmentInputDto[],
  ) => Promise<void>;
  submitClarification: (answers: Array<string | string[]>) => Promise<void>;
  submitFollowUp: (args: {
    description: string;
    followUpConfigAlias?: string;
    followUpMode?: FollowUpModeDto;
    imageAttachments?: ImageAttachmentInputDto[];
  }) => Promise<boolean>;
  openWorktreeCleanupDialog: () => Promise<void>;
  closeWorktreeCleanupDialog: () => void;
  confirmWorktreeCleanup: () => Promise<void>;
  retryTask: (force?: boolean) => Promise<void>;
  continueBlockedTask: () => Promise<void>;
  recoverRun: (nodeRunId: string) => Promise<void>;
};

function runtimeDisplayName(runtimeId: string): string {
  switch (runtimeId.trim()) {
    case "claude":
    case "claude-code":
      return "Claude Code";
    case "codex":
      return "Codex";
    case "copilot":
      return "GitHub Copilot";
    case "gemini":
      return "Gemini";
    case "goose":
      return "Goose";
    case "opencode":
      return "OpenCode";
    default:
      return runtimeId.trim();
  }
}

function resolveRunRuntimeNameFromConfig(
  run: NodeRunViewDto | undefined,
  config: ConfigViewDto | undefined,
): string | undefined {
  if (!run || !isRecord(config?.config)) {
    return undefined;
  }
  const nodeDefinitions = isRecord(config.config.node_definitions)
    ? config.config.node_definitions
    : undefined;
  const definitionValue = nodeDefinitions?.[run.node_name];
  const definition = isRecord(definitionValue) ? definitionValue : undefined;
  const nodeType = typeof definition?.type === "string" ? definition.type.trim() : "";
  if (nodeType === "human" || nodeType === "terminal") {
    return undefined;
  }
  const nodeRuntimeId =
    typeof definition?.runtime === "string" ? definition.runtime.trim() : "";
  const configRuntimeId =
    typeof config.config.runtime === "string" ? config.config.runtime.trim() : "";
  const runtimeId = nodeRuntimeId || configRuntimeId;
  return runtimeId ? runtimeDisplayName(runtimeId) : undefined;
}

export function resolveTaskRuntimeName(
  task: TaskViewDto | undefined,
  run: NodeRunViewDto | undefined,
  config: ConfigViewDto | undefined,
  configEntries: ConfigCatalogEntryDto[],
): string | undefined {
  const runRuntimeName = resolveRunRuntimeNameFromConfig(run, config);
  if (runRuntimeName) {
    return runRuntimeName;
  }
  if (!task) {
    return undefined;
  }
  const configPath = task.task.config_path.trim();
  const configAlias = task.task.config_alias.trim();
  const matchedEntry =
    configEntries.find((entry) => entry.config_path === configPath) ??
    configEntries.find((entry) => entry.alias === configAlias);
  if (!matchedEntry) {
    return undefined;
  }
  const runtimeLabel = (matchedEntry.runtime_name || matchedEntry.runtime_id || "").trim();
  return runtimeLabel || "Automatic";
}

type TaskDetailPropertiesContentProps = {
  statusLabel: string;
  statusTone: "running" | "awaiting" | "done" | "failed" | "neutral";
  configLabel: string;
  stageNodes: StageNode[];
  launchedInWorktree: boolean;
  launchModeLabel?: string;
  createdLabel: string;
  durationLabel: string;
  runsLabel: string;
  showCleanupPropertyBlock: boolean;
  cleanupView: string;
  showCleanupMessage: boolean;
  cleanupMeta?: string;
  worktreeCleanupInfo?: WorktreeCleanupInfoDto;
  worktreeCleanupError?: string;
  worktreeCleanupLoading: boolean;
  submittingWorktreeCleanup: boolean;
  retryWorktreeCleanupInfo: () => void;
  openWorktreeCleanupDialog: () => Promise<void>;
};

function stageFlowGlyph(status: StageNode["status"]) {
  switch (status) {
    case "done":
      return "●";
    case "current":
      return "◐";
    case "failed":
      return "✕";
    case "pending":
    default:
      return "○";
  }
}

function TaskDetailCleanupBlock({
  showCleanupPropertyBlock,
  cleanupView,
  showCleanupMessage,
  cleanupMeta,
  worktreeCleanupInfo,
  worktreeCleanupError,
  worktreeCleanupLoading,
  submittingWorktreeCleanup,
  retryWorktreeCleanupInfo,
  openWorktreeCleanupDialog,
}: Pick<
  TaskDetailPropertiesContentProps,
  | "showCleanupPropertyBlock"
  | "cleanupView"
  | "showCleanupMessage"
  | "cleanupMeta"
  | "worktreeCleanupInfo"
  | "worktreeCleanupError"
  | "worktreeCleanupLoading"
  | "submittingWorktreeCleanup"
  | "retryWorktreeCleanupInfo"
  | "openWorktreeCleanupDialog"
>) {
  if (!showCleanupPropertyBlock) {
    return null;
  }

  return (
    <div
      className="detail-properties__block detail-properties__block--cleanup"
      data-testid="detail-worktree-cleanup"
    >
      <span className="detail-properties__label">Worktree cleanup</span>
      <div className="detail-properties__cleanup" data-cleanup-view={cleanupView}>
        {cleanupView === "loading" ? (
          <p
            className="detail-properties__value detail-properties__cleanup-message"
            data-testid="worktree-cleanup-loading"
          >
            Checking worktree…
          </p>
        ) : null}

        {cleanupView === "error" ? (
          <>
            <p
              className="detail-properties__value detail-properties__cleanup-message"
              data-testid="worktree-cleanup-error"
            >
              {worktreeCleanupError ?? "Failed to check worktree status."}
            </p>
            <Button
              className="detail-properties__cleanup-button"
              data-testid="worktree-cleanup-retry"
              disabled={worktreeCleanupLoading}
              onClick={() => {
                retryWorktreeCleanupInfo();
              }}
              size="sm"
              type="button"
              variant="secondary"
            >
              {worktreeCleanupLoading ? "Retrying…" : "Retry"}
            </Button>
          </>
        ) : null}

        {showCleanupMessage ? (
          <p
            className="detail-properties__value detail-properties__cleanup-message"
            data-testid="worktree-cleanup-message"
          >
            {worktreeCleanupInfo?.message ?? "Worktree cleanup unavailable."}
          </p>
        ) : null}

        {cleanupMeta && cleanupView !== "missing" ? (
          <p className="detail-properties__cleanup-meta">{cleanupMeta}</p>
        ) : null}

        {cleanupView === "available" ? (
          <Button
            className="detail-properties__cleanup-button"
            data-testid="worktree-cleanup-trigger"
            disabled={submittingWorktreeCleanup}
            onClick={() => {
              void openWorktreeCleanupDialog();
            }}
            size="sm"
            type="button"
            variant="danger"
          >
            {submittingWorktreeCleanup ? "Removing…" : "Remove worktree"}
          </Button>
        ) : null}
      </div>
    </div>
  );
}

function TaskDetailPropertiesPanel({
  statusLabel,
  statusTone,
  configLabel,
  stageNodes,
  launchedInWorktree,
  launchModeLabel,
  createdLabel,
  durationLabel,
  runsLabel,
  showCleanupPropertyBlock,
  cleanupView,
  showCleanupMessage,
  cleanupMeta,
  worktreeCleanupInfo,
  worktreeCleanupError,
  worktreeCleanupLoading,
  submittingWorktreeCleanup,
  retryWorktreeCleanupInfo,
  openWorktreeCleanupDialog,
}: TaskDetailPropertiesContentProps) {
  return (
    <section className="detail-properties-surface" data-testid="detail-properties-surface">
      <div className="detail-properties__content">
        <div className="detail-properties__block" data-testid="detail-task-status">
          <span className="detail-properties__label">Status</span>
          <StatusBadge label={statusLabel} tone={statusTone} />
        </div>

        <div className="detail-properties__block" data-testid="detail-task-duration">
          <span className="detail-properties__label">Duration</span>
          <span className="detail-properties__value">{durationLabel}</span>
        </div>

        <div className="detail-properties__block" data-testid="detail-task-config">
          <span className="detail-properties__label">Config</span>
          <span className="detail-properties__value detail-properties__mono">
            {configLabel}
          </span>
        </div>

        {launchModeLabel ? (
          <div className="detail-properties__block" data-testid="detail-task-launch-mode">
            <span className="detail-properties__label">Launch mode</span>
            <span className="detail-properties__value detail-properties__launch-mode">
              {launchedInWorktree ? (
                <span
                  className="detail-properties__launch-mode-icon-wrap"
                  data-testid="detail-task-launch-mode-icon"
                >
                  <WorktreeGlyph
                    className="detail-properties__launch-mode-icon"
                    size={12}
                    strokeWidth={1.95}
                  />
                </span>
              ) : null}
              <span>{launchModeLabel}</span>
            </span>
          </div>
        ) : null}

        {stageNodes.length > 0 ? (
          <div className="detail-properties__block" data-testid="detail-task-flow">
            <span className="detail-properties__label">Flow</span>
            <div className="detail-properties__flow">
              {stageNodes.map((node) => (
                <div className="detail-properties__flow-row" key={node.name}>
                  <span
                    aria-hidden="true"
                    className={`detail-properties__flow-bullet detail-properties__flow-bullet--${node.status}`}
                  >
                    {stageFlowGlyph(node.status)}
                  </span>
                  <span className="detail-properties__value">{node.name}</span>
                </div>
              ))}
            </div>
          </div>
        ) : null}

        <div className="detail-properties__block" data-testid="detail-task-created">
          <span className="detail-properties__label">Created</span>
          <span className="detail-properties__value">{createdLabel}</span>
        </div>

        <div className="detail-properties__block" data-testid="detail-task-runs">
          <span className="detail-properties__label">Runs</span>
          <span className="detail-properties__value detail-properties__muted">
            {runsLabel}
          </span>
        </div>

        <TaskDetailCleanupBlock
          cleanupMeta={cleanupMeta}
          cleanupView={cleanupView}
          openWorktreeCleanupDialog={openWorktreeCleanupDialog}
          retryWorktreeCleanupInfo={retryWorktreeCleanupInfo}
          showCleanupMessage={showCleanupMessage}
          showCleanupPropertyBlock={showCleanupPropertyBlock}
          submittingWorktreeCleanup={submittingWorktreeCleanup}
          worktreeCleanupError={worktreeCleanupError}
          worktreeCleanupInfo={worktreeCleanupInfo}
          worktreeCleanupLoading={worktreeCleanupLoading}
        />
      </div>
    </section>
  );
}

export function TaskDetailScreen({
  task,
  config,
  loading,
  detailError,
  historyEntries,
  title,
  statusLabel,
  statusTone,
  configLabel,
  stageNodes,
  timelineRuns,
  runningActivityPreviewByRunId,
  activityPreviewSignature,
  activityRunActorTypes,
  artifacts,
  selection,
  modal,
  currentRun,
  selectedRun,
  selectedArtifact,
  artifactPreview,
  artifactError,
  artifactActionError,
  liveEvents,
  liveEventsRunId,
  selectedRunHistory,
  selectedRunFullHistory,
  workspaceActorState,
  staleReconcilePending,
  supportsRunRecovery,
  actionSurface,
  inputRequest,
  blockedStep,
  submittingClarification,
  submittingDecision,
  followUp,
  followUpState,
  worktreeCleanupInfo,
  worktreeCleanupLoading,
  worktreeCleanupError,
  retryWorktreeCleanupInfo,
  configEntries,
  submittingFollowUp,
  worktreeCleanupDialogOpen,
  submittingWorktreeCleanup,
  submittingRetry,
  submittingContinue,
  submittingRecovery,
  failureReason,
  selectOverview,
  selectRun,
  openAncestorTask,
  openTranscript,
  openArtifact,
  openArtifactExternally,
  submitApprove,
  submitReject,
  submitClarification,
  submitFollowUp,
  openWorktreeCleanupDialog,
  closeWorktreeCleanupDialog,
  confirmWorktreeCleanup,
  retryTask,
  continueBlockedTask,
  recoverRun,
}: TaskDetailScreenProps) {
  const actionRunId =
    actionSurface.kind !== "none" && "run" in actionSurface
      ? actionSurface.run?.id
      : undefined;
  const realRunIds = useMemo(
    () => new Set(timelineRuns.map((run) => run.id)),
    [timelineRuns],
  );
  const displayedActivityRuns = useMemo(() => {
    return actionSurface.kind === "blocked" &&
      actionSurface.run &&
      !realRunIds.has(actionSurface.run.id)
      ? [...timelineRuns, actionSurface.run]
      : timelineRuns;
  }, [actionSurface, realRunIds, timelineRuns]);
  const currentRunId = currentRun?.id;
  const {
    transcript,
    rawTranscriptItems,
    selectedRunStreamLines,
    selectedRunStreamSource,
    canRecoverSelectedRun,
    selectedRunClarificationItems,
    displayTranscriptItems,
  } = useMemo(() => {
    const currentLiveSelectedRunEvents =
      selectedRun?.id && liveEventsRunId === selectedRun.id ? liveEvents : [];
    const currentReplay =
      selectedRunFullHistory?.fullResult ?? selectedRunHistory?.result;
    const currentTranscript = buildTranscriptSnapshot({
      replay: currentReplay,
      liveEvents: currentLiveSelectedRunEvents,
    });
    const currentRawTranscriptItems = deriveTranscriptTimelineItems(currentTranscript);
    const currentSelectedRunStreamLines = timelineItemsToLines(currentRawTranscriptItems);
    const currentTranscriptLoading =
      modal.kind === "transcript"
        ? Boolean(
            selectedRunFullHistory?.fullLoading &&
              !selectedRunFullHistory?.fullResult &&
              currentLiveSelectedRunEvents.length === 0,
          )
        : Boolean(selectedRunHistory?.loading);
    const currentSelectedRunStreamSource: "live" | "replay" | "loading" | "none" =
      currentLiveSelectedRunEvents.length > 0
        ? "live"
        : currentSelectedRunStreamLines.length > 0
          ? "replay"
          : currentTranscriptLoading
            ? "loading"
            : "none";
    const currentCanRecoverSelectedRun = Boolean(
      selectedRun &&
        selectedRun.id === currentRunId &&
        detailStatusLabel(selectedRun.status) === "running" &&
        currentSelectedRunStreamSource !== "live" &&
        currentSelectedRunStreamSource !== "loading" &&
        selectedRunHistory &&
        !selectedRunHistory.loading &&
        !selectedRunHistory.error &&
        !selectedRun.result &&
        supportsRunRecovery &&
        workspaceActorState !== "active",
    );
    const currentSelectedRunClarificationItems = clarificationTranscriptItems({
      rawTranscriptItems: currentRawTranscriptItems,
      run: selectedRun,
    });
    const currentDisplayTranscriptItems = mergeDisplayTranscriptItems({
      clarificationItems: currentSelectedRunClarificationItems,
      rawTranscriptItems: currentRawTranscriptItems,
      transcript: currentTranscript,
    });

    return {
      transcript: currentTranscript,
      rawTranscriptItems: currentRawTranscriptItems,
      selectedRunStreamLines: currentSelectedRunStreamLines,
      selectedRunStreamSource: currentSelectedRunStreamSource,
      canRecoverSelectedRun: currentCanRecoverSelectedRun,
      selectedRunClarificationItems: currentSelectedRunClarificationItems,
      displayTranscriptItems: currentDisplayTranscriptItems,
    };
  }, [
    currentRunId,
    liveEvents,
    liveEventsRunId,
    modal.kind,
    selectedRun,
    selectedRunFullHistory,
    selectedRunHistory,
    supportsRunRecovery,
    workspaceActorState,
  ]);
  const createdLabel = formatAbsoluteStamp(task?.task.created_at);
  const durationLabel = summarizeTaskDuration(task, timelineRuns);
  const runsLabel = summarizeRuns(timelineRuns);
  const launchModeLabel = task ? taskLaunchModeLabel(task) : undefined;
  const launchedInWorktree = launchModeLabel === "Worktree";
  const cleanupEligible = Boolean(task && task.status === "done" && isWorktreeTask(task));
  const cleanupTaskCount = worktreeCleanupInfo?.shared_task_count ?? 0;
  const cleanupDirtyCount = worktreeCleanupInfo?.dirty_count ?? 0;
  const cleanupBlockedBy = worktreeCleanupInfo?.blocked_by ?? [];
  const showCleanupPropertyBlock = cleanupEligible;
  const cleanupMeta = [
    cleanupDirtyCount > 0
      ? formatCount(cleanupDirtyCount, "uncommitted change", "uncommitted changes")
      : undefined,
    cleanupTaskCount > 1
      ? `shared by ${formatCount(cleanupTaskCount, "task", "tasks")}`
      : undefined,
  ]
    .filter((value): value is string => Boolean(value))
    .join(" · ");
  const cleanupView: "loading" | "error" | "available" | "blocked" | "missing" | "hidden" =
    !cleanupEligible
      ? "hidden"
      : worktreeCleanupInfo?.state === "available"
        ? "available"
        : worktreeCleanupInfo?.state === "blocked"
          ? "blocked"
          : worktreeCleanupInfo?.state === "missing"
            ? "missing"
            : worktreeCleanupError
              ? "error"
              : "loading";
  const showCleanupMessage =
    cleanupView === "blocked" || cleanupView === "missing";
  const propertiesPanel = useMemo(
    () => (
      <TaskDetailPropertiesPanel
        cleanupMeta={cleanupMeta}
        cleanupView={cleanupView}
        configLabel={configLabel}
        createdLabel={createdLabel}
        durationLabel={durationLabel}
        launchModeLabel={launchModeLabel}
        launchedInWorktree={launchedInWorktree}
        openWorktreeCleanupDialog={openWorktreeCleanupDialog}
        retryWorktreeCleanupInfo={retryWorktreeCleanupInfo}
        runsLabel={runsLabel}
        showCleanupMessage={showCleanupMessage}
        showCleanupPropertyBlock={showCleanupPropertyBlock}
        stageNodes={stageNodes}
        statusLabel={statusLabel}
        statusTone={statusTone}
        submittingWorktreeCleanup={submittingWorktreeCleanup}
        worktreeCleanupError={worktreeCleanupError}
        worktreeCleanupInfo={worktreeCleanupInfo}
        worktreeCleanupLoading={worktreeCleanupLoading}
      />
    ),
    [
      cleanupMeta,
      cleanupView,
      configLabel,
      createdLabel,
      durationLabel,
      launchModeLabel,
      launchedInWorktree,
      openWorktreeCleanupDialog,
      retryWorktreeCleanupInfo,
      runsLabel,
      showCleanupMessage,
      showCleanupPropertyBlock,
      stageNodes,
      statusLabel,
      statusTone,
      submittingWorktreeCleanup,
      worktreeCleanupError,
      worktreeCleanupInfo,
      worktreeCleanupLoading,
    ],
  );
  const promptLead = task?.task.description ?? title;
  const showHistorySection = historyEntries.length > 0;
  const [historyCollapsed, setHistoryCollapsed] = useState(false);
  const mainContentRef = useRef<HTMLDivElement | null>(null);
  const shouldStickMainContentToBottomRef = useRef(true);
  const lastTaskIdRef = useRef<string | undefined>(undefined);
  const ungroupedArtifacts = useMemo(() => {
    const groupedArtifactPaths = new Set(
      timelineRuns.flatMap((run) =>
        artifactsForRun(run, artifacts).map((artifact) => artifact.resolved_path),
      ),
    );
    return artifacts.filter(
      (artifact) => !groupedArtifactPaths.has(artifact.resolved_path),
    );
  }, [artifacts, timelineRuns]);

  const artifactModal =
    modal.kind === "artifact" ? (
      <TaskArtifactModal
        artifact={selectedArtifact}
        preview={artifactPreview}
        error={artifactError}
        actionError={artifactActionError}
        onOpenExternally={() => void openArtifactExternally()}
        onClose={() => {
          if (selectedArtifact?.node_run_id) {
            selectRun(selectedArtifact.node_run_id);
            return;
          }
          selectOverview();
        }}
      />
    ) : null;

  const taskRuntimeName = resolveTaskRuntimeName(
    task,
    selectedRun,
    config,
    configEntries,
  );

  const transcriptModal =
    modal.kind === "transcript" ? (
      <TaskTranscriptModal
        isCurrentRun={selectedRun?.id === currentRunId}
        onClose={() => {
          if (selectedRun?.id) {
            selectRun(selectedRun.id);
            return;
          }
          selectOverview();
        }}
        streamLines={selectedRunStreamLines}
        streamSource={selectedRunStreamSource}
        transcript={transcript}
        rawTranscriptItems={rawTranscriptItems}
        displayTranscriptItems={displayTranscriptItems}
        clarificationItems={selectedRunClarificationItems}
        runtimeName={taskRuntimeName}
        run={selectedRun}
        showEmptyOutput={Boolean(selectedRun)}
        recoveryAction={
          selectedRun && canRecoverSelectedRun
            ? {
                submitting: submittingRecovery,
                onRecover: () => recoverRun(selectedRun.id),
              }
            : undefined
        }
      />
    ) : null;

  useEffect(() => {
    setHistoryCollapsed(false);
  }, [task?.task.id]);

  useEffect(() => {
    const mainContent = mainContentRef.current;
    if (!mainContent) {
      return;
    }
    const updateStickiness = () => {
      const distanceFromBottom =
        mainContent.scrollHeight - mainContent.scrollTop - mainContent.clientHeight;
      shouldStickMainContentToBottomRef.current = distanceFromBottom <= 24;
    };
    updateStickiness();
    mainContent.addEventListener("scroll", updateStickiness);
    return () => {
      mainContent.removeEventListener("scroll", updateStickiness);
    };
  }, []);

  useLayoutEffect(() => {
    const mainContent = mainContentRef.current;
    const taskId = task?.task.id;
    if (!mainContent || !taskId) {
      return;
    }
    if (lastTaskIdRef.current === taskId) {
      return;
    }
    mainContent.scrollTop = mainContent.scrollHeight;
    shouldStickMainContentToBottomRef.current = true;
    lastTaskIdRef.current = taskId;
  }, [task?.task.id]);

  useLayoutEffect(() => {
    const mainContent = mainContentRef.current;
    if (!mainContent || !shouldStickMainContentToBottomRef.current) {
      return;
    }
    mainContent.scrollTop = mainContent.scrollHeight;
  }, [
    actionSurface.kind,
    activityPreviewSignature,
    displayedActivityRuns.length,
    historyCollapsed,
    historyEntries.length,
    ungroupedArtifacts.length,
  ]);

  let actionPanel = null;
  if (actionSurface.kind === "approval") {
    actionPanel = (
      <TaskApprovalDock
        requestKey={`${inputRequest?.task_id ?? "task"}:${inputRequest?.node_run_id ?? "run"}`}
        submitApprove={submitApprove}
        submitReject={submitReject}
        submittingDecision={submittingDecision}
      />
    );
  } else if (actionSurface.kind === "clarification") {
    actionPanel = (
      <TaskClarificationDock
        questions={inputRequest?.questions ?? []}
        requestKey={`${inputRequest?.task_id ?? "task"}:${inputRequest?.node_run_id ?? "run"}`}
        submitClarification={submitClarification}
        submittingClarification={submittingClarification}
      />
    );
  } else if (actionSurface.kind === "blocked") {
    actionPanel = (
      <TaskBlockedDock
        blockedStep={blockedStep}
        onContinue={continueBlockedTask}
        submittingContinue={submittingContinue}
      />
    );
  } else if (actionSurface.kind === "retry") {
    actionPanel = (
      <TaskRetryDock
        failureReason={failureReason}
        onRetry={retryTask}
        run={actionSurface.run}
        submittingRetry={submittingRetry}
      />
    );
  } else if (actionSurface.kind === "follow_up") {
    actionPanel = (
      <TaskFollowUpDock
        configEntries={configEntries}
        defaultConfigAlias={task?.task.config_alias}
        followUp={followUp}
        followUpState={followUpState}
        taskKey={task?.task.id ?? "task"}
        onStartFollowUp={submitFollowUp}
        submittingFollowUp={submittingFollowUp}
      />
    );
  }

  const detailMainColumnClassName =
    actionSurface.kind === "follow_up"
      ? "detail-main-column detail-main-column--follow-up"
      : "detail-main-column";
  const workbenchTab = useMemo(
    () => ({
      key: `task-detail-tab:${task?.task.id ?? "loading"}`,
      tabId: task ? (`task-detail:${task.task.id}` as WorkbenchTabId) : undefined,
      title:
        title.trim().length > 40
          ? `${title.trim().slice(0, 37).trimEnd()}…`
          : title.trim() || "Task",
    }),
    [task, title],
  );
  const workbenchRegions = useMemo(
    () =>
      task
        ? {
            key: `task-detail-regions:${task.task.id}`,
            tabId: `task-detail:${task.task.id}` as WorkbenchTabId,
            secondarySidebar: {
              defaultOpen: true,
              preferredSize: 320,
              panel: {
                title: "Properties",
                size: 320,
                testId: "detail-properties-header",
                content: propertiesPanel,
              },
            },
          }
        : null,
    [propertiesPanel, task],
  );
  useWorkbenchTab(workbenchTab);
  useWorkbenchRegions(workbenchRegions);
  const detailLayoutClassName = "detail-layout detail-layout--workbench";
  const showInlineFollowUp = actionSurface.kind === "follow_up" && Boolean(actionPanel);

  return (
    <section className="detail-screen" data-testid="task-detail-screen">
        {detailError || staleReconcilePending ? (
          <div className="toast-container">
            {detailError ? (
              <Toast message={detailError} tone="error" onDismiss={() => {}} />
            ) : null}
            {staleReconcilePending ? (
              <Toast
                duration={0}
                dismissible={false}
                message="Checking stale run state. If the previous executor was interrupted, this task will update automatically when reconciliation finishes."
                onDismiss={() => {}}
                testId="detail-stale-reconcile-toast"
                tone="warning"
              />
            ) : null}
          </div>
        ) : null}

        <div className={detailLayoutClassName}>
          <div className={detailMainColumnClassName}>
            <div
              className="detail-main-content"
              data-testid="detail-main-content"
              ref={mainContentRef}
            >
              <header className="detail-main-header">
                <div className="detail-main-header__prompt">
                  <div
                    className="detail-main-header__prompt-body"
                    data-no-window-drag="true"
                    data-testid="task-detail-header-description"
                  >
                    <DocumentContent
                      className="detail-main-header__prompt-text"
                      content={promptLead}
                      format="markdown"
                      variant="compact"
                    />
                  </div>
                </div>
              </header>
              <div className="detail-main-divider" />

              {showHistorySection ? (
                <>
                  <section
                    className="detail-history"
                    data-collapsed={historyCollapsed ? "true" : "false"}
                    data-testid="detail-task-history"
                  >
                    <button
                      aria-controls="detail-task-history-feed"
                      aria-expanded={!historyCollapsed}
                      className="detail-history__header"
                      data-testid="detail-task-history-toggle"
                      onClick={() => setHistoryCollapsed((value) => !value)}
                      type="button"
                    >
                      <span aria-hidden="true" className="detail-history__header-icon">
                        <ChevronDown size={12} strokeWidth={1.9} />
                      </span>
                      <span className="detail-history__eyebrow">History</span>
                      <span aria-hidden="true" className="detail-history__header-dot">
                        ·
                      </span>
                      <span
                        className="detail-history__count"
                        data-testid="detail-task-history-count"
                      >
                        {`${historyEntries.length} ${
                          historyEntries.length === 1 ? "iteration" : "iterations"
                        }`}
                      </span>
                    </button>

                    <div
                      className="detail-history__feed"
                      hidden={historyCollapsed}
                      id="detail-task-history-feed"
                    >
                      {historyEntries.map((entry) => (
                        <button
                          className="detail-history__row"
                          data-testid={`detail-task-ancestor-${entry.taskId}`}
                          key={entry.taskId}
                          onClick={() => openAncestorTask(entry.taskId)}
                          type="button"
                        >
                          <span aria-hidden="true" className="detail-history__row-icon">
                            <CircleDot size={14} strokeWidth={1.9} />
                          </span>
                          <span className="detail-history__row-copy">
                            <span className="detail-history__row-title">
                              <span className="detail-history__row-title-text">
                                {entry.description}
                              </span>
                              <span className="detail-history__row-spacer" />
                              <span className="detail-history__row-time">
                                {entry.relativeUpdatedAt}
                              </span>
                            </span>
                            {entry.metaLabel ? (
                              <span className="detail-history__row-meta">{entry.metaLabel}</span>
                            ) : null}
                          </span>
                        </button>
                      ))}
                    </div>
                  </section>
                  <div className="detail-history-divider" />
                </>
              ) : null}

              <section className="detail-activity" data-testid="detail-activity">
                <div className="detail-activity__header">
                  <span className="detail-activity__eyebrow">Activity</span>
                  {loading ? (
                    <span className="detail-activity__summary">Loading…</span>
                  ) : null}
                </div>

                <div className="detail-activity__list">
                  {displayedActivityRuns.map((run) => {
                  const isRealRun = realRunIds.has(run.id);
                  const runArtifacts = isRealRun ? artifactsForRun(run, artifacts) : [];
                  const actionKindForRun =
                    actionRunId === run.id && actionSurface.kind !== "none"
                      ? actionSurface.kind
                      : "none";
                  const tone = activityCardTone({
                    run,
                    actionRunId,
                    actionKind: actionSurface.kind,
                  });
                  const actorType = activityRunActorTypes[run.id] ?? "agent";
                  const runStatus = detailStatusLabel(run.status);
                  const showActionPanel = actionRunId === run.id && actionPanel;
                  const runSelected = isRealRun
                    ? selection.kind === "run"
                      ? selection.runId === run.id
                      : selectedArtifact?.node_run_id === run.id
                    : Boolean(showActionPanel && selection.kind === "overview");
                  const runningActivityPreview = isRealRun
                    ? runningActivityPreviewByRunId[run.id] ?? emptyRunningActivityPreview
                    : emptyRunningActivityPreview;
                  const showRunningPreview =
                    !showActionPanel && runningActivityPreview.length > 0;
                  const showInlineArtifactRow =
                    isRealRun &&
                    !showRunningPreview &&
                    runArtifacts.length === 1 &&
                    selectedArtifact?.node_run_id !== run.id;
                  const summaryMarkdown = isRealRun ? completedRunSummary(run) : "";
                  const timing = formatRunTiming(run);
                  const showRunStateBadge = runStatus !== "done";
                  const runMeta =
                    actionKindForRun === "approval" ||
                    actionKindForRun === "clarification" ||
                    actionKindForRun === "retry"
                      ? undefined
                      : showRunningPreview
                        ? undefined
                        : showInlineArtifactRow
                          ? undefined
                          : activityMeta(run, runArtifacts.length);
                    return (
                      <article
                        className={`detail-activity-card detail-activity-card--${tone}${
                          runSelected ? " is-selected" : ""
                        }`}
                        key={run.id}
                      >
                      <div
                        aria-pressed={runSelected}
                        className={`detail-activity-card__summary${
                          showRunningPreview ? " detail-activity-card__summary--with-preview" : ""
                        }`}
                        data-testid={`detail-run-${run.id}`}
                        onClick={() => {
                          if (!isRealRun) {
                            selectOverview();
                            return;
                          }
                          if (actionKindForRun !== "none") {
                            selectRun(run.id);
                            return;
                          }
                          openTranscript(run.id);
                        }}
                        onKeyDown={(event) => {
                          if (event.key === "Enter" || event.key === " ") {
                            event.preventDefault();
                            if (!isRealRun) {
                              selectOverview();
                              return;
                            }
                            if (actionKindForRun !== "none") {
                              selectRun(run.id);
                              return;
                            }
                            openTranscript(run.id);
                          }
                        }}
                        role="button"
                        tabIndex={0}
                      >
                        <span
                          aria-hidden="true"
                          className={`detail-activity-card__icon detail-activity-card__icon--${tone}`}
                          data-actor-type={actorType}
                          data-testid={`detail-run-icon-${run.id}`}
                        >
                          <ActivityRunIcon actorType={actorType} />
                        </span>
                        <span className="detail-activity-card__copy">
                          <span className="detail-activity-card__title-row">
                            <span className="detail-activity-card__title">{run.node_name}</span>
                            {showRunStateBadge ? (
                              <span
                                className={`detail-activity-card__state detail-activity-card__state--${tone}`}
                              >
                                {runStatus}
                              </span>
                            ) : null}
                            <span className="detail-activity-card__title-spacer" />
                            {timing.duration ? (
                              <span className="detail-activity-card__duration">
                                {timing.duration}
                              </span>
                            ) : null}
                            <span className="detail-activity-card__time">{timing.relative}</span>
                          </span>
                          {showRunningPreview ? (
                            <span
                              className="detail-activity-card__preview"
                              data-testid={`detail-run-preview-${run.id}`}
                            >
                              {runningActivityPreview.map((row, index) => (
                                <span
                                  className={`detail-activity-card__preview-row detail-activity-card__preview-row--${row.tone}`}
                                  data-testid={`detail-run-preview-row-${run.id}-${index}`}
                                  key={row.id}
                                >
                                  <span
                                    aria-hidden="true"
                                    className={`detail-activity-card__preview-dot detail-activity-card__preview-dot--${row.tone}`}
                                  />
                                  <span className="detail-activity-card__preview-text">
                                    {row.text}
                                  </span>
                                </span>
                              ))}
                            </span>
                          ) : showInlineArtifactRow ? (
                            <button
                              className="detail-activity-card__file-row"
                              onClick={(event) => {
                                event.stopPropagation();
                                openArtifact(runArtifacts[0]);
                              }}
                              type="button"
                            >
                              <FileText aria-hidden="true" size={11} strokeWidth={1.9} />
                              <span>{runArtifacts[0].preview_name}</span>
                            </button>
                          ) : runMeta ? (
                            <span className="detail-activity-card__meta">{runMeta}</span>
                          ) : null}
                        </span>
                      </div>

                      {!showInlineArtifactRow && runArtifacts.length > 0 ? (
                        <div className="detail-activity-card__artifacts">
                          {runArtifacts.map((artifact) => (
                            <button
                              className={`detail-activity-card__artifact${
                                selectedArtifact?.resolved_path === artifact.resolved_path
                                  ? " is-selected"
                                  : ""
                              }`}
                              key={artifact.resolved_path}
                              onClick={() => openArtifact(artifact)}
                              type="button"
                            >
                              {artifact.preview_name}
                            </button>
                          ))}
                        </div>
                      ) : runArtifacts.length > 0 ? (
                        null
                      ) : null}

                      {summaryMarkdown ? (
                        <div
                          className="detail-activity-card__result-summary"
                          data-testid={`detail-run-summary-${run.id}`}
                        >
                          <DocumentContent
                            className="detail-activity-card__result-summary-document"
                            content={summaryMarkdown}
                            format="markdown"
                            variant="compact"
                          />
                        </div>
                      ) : null}

                      {showActionPanel ? (
                        <div className="detail-activity-card__body">
                          {showActionPanel ? actionPanel : null}
                        </div>
                      ) : null}
                      </article>
                    );
                  })}

                  {ungroupedArtifacts.length > 0 ? (
                    <article className="detail-activity-card detail-activity-card--default">
                      <div className="detail-activity-card__summary">
                        <span
                          aria-hidden="true"
                          className="detail-activity-card__icon detail-activity-card__icon--default"
                        >
                          <StageNodeIcon status="pending" />
                        </span>
                        <span className="detail-activity-card__copy">
                          <span className="detail-activity-card__title-row">
                            <span className="detail-activity-card__title">artifacts</span>
                          </span>
                          <span className="detail-activity-card__meta">
                            {formatCount(ungroupedArtifacts.length, "artifact", "artifacts")}
                          </span>
                        </span>
                      </div>
                      <div className="detail-activity-card__artifacts">
                        {ungroupedArtifacts.map((artifact) => (
                          <button
                            className={`detail-activity-card__artifact${
                              selectedArtifact?.resolved_path === artifact.resolved_path
                                ? " is-selected"
                                : ""
                            }`}
                            key={artifact.resolved_path}
                            onClick={() => openArtifact(artifact)}
                            type="button"
                          >
                            {artifact.preview_name}
                          </button>
                        ))}
                      </div>
                    </article>
                  ) : null}
                </div>
              </section>
            </div>

            {showInlineFollowUp ? (
              <div className="detail-follow-up-slot">{actionPanel}</div>
            ) : null}
          </div>
        </div>
        {artifactModal}
        {transcriptModal}
      <ConfirmDialog
        body={
          worktreeCleanupInfo ? (
            <>
              <p>
                {worktreeCleanupInfo.removal_scope === "shared_worktree"
                  ? `Remove the shared worktree used by ${cleanupTaskCount} tasks?`
                  : "Remove this worktree?"}
              </p>
              <p>
                {cleanupDirtyCount > 0
                  ? `This worktree currently has ${cleanupDirtyCount} uncommitted change${cleanupDirtyCount === 1 ? "" : "s"}.`
                  : "This worktree has no uncommitted changes."}
              </p>
              {cleanupBlockedBy.length > 0 ? (
                <p>
                  Blocked by:{" "}
                  {cleanupBlockedBy
                    .map((entry) => `${entry.description || entry.task_id} (${entry.status})`)
                    .join(", ")}
                </p>
              ) : null}
            </>
          ) : (
            ""
          )
        }
        confirmDisabled={!worktreeCleanupInfo?.can_remove || submittingWorktreeCleanup}
        confirmLabel="Remove worktree"
        onCancel={closeWorktreeCleanupDialog}
        onConfirm={() => void confirmWorktreeCleanup()}
        open={worktreeCleanupDialogOpen}
        title={
          worktreeCleanupInfo?.removal_scope === "shared_worktree"
            ? "Remove shared worktree"
            : "Remove worktree"
        }
      />
    </section>
  );
}
