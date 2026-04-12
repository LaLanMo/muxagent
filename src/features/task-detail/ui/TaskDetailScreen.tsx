import { useEffect, useLayoutEffect, useRef } from "react";
import { Bot, Check, CircleDashed, CircleX, FileText, Loader, User, type LucideIcon } from "lucide-react";
import {
  detailStatusLabel,
  formatRelativeTime,
} from "@/domain/task-shell";
import {
  buildTranscriptSnapshot,
  type SessionHistoryEvent,
  type TranscriptSnapshot,
} from "@/domain/session-history";
import {
  deriveTranscriptTimelineItems,
  timelineItemsToLines,
  type TranscriptTimelineItem,
} from "@/features/task-history/model/timeline";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import { Toast } from "@/features/shared/ui/Toast";
import type {
  ActivityRunActorType,
  TaskDetailActionSurface,
} from "@/features/task-detail/model/use-task-detail-screen";
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
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
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

function flowBullet(status: StageNode["status"]) {
  return status === "pending" ? "○" : "●";
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

type TaskDetailScreenProps = {
  shell: ShellChromeModel;
  goBackToTaskSurface: () => void;
  task?: TaskViewDto;
  loading: boolean;
  detailError?: string;
  title: string;
  statusLabel: string;
  statusTone: "running" | "awaiting" | "done" | "failed" | "neutral";
  configLabel: string;
  elapsedLabel: string;
  stageNodes: StageNode[];
  timelineRuns: NodeRunViewDto[];
  activityRunActorTypes: Record<string, ActivityRunActorType>;
  artifacts: ArtifactRefDto[];
  selection: TaskDetailSelection;
  modal: TaskDetailModal;
  currentRun?: NodeRunViewDto;
  selectedRun?: NodeRunViewDto;
  selectedArtifact?: ArtifactRefDto;
  artifactContent?: string;
  artifactError?: string;
  liveEvents: SessionHistoryEvent[];
  liveEventsRunId?: string;
  selectedRunHistory?: RunHistoryCacheEntry;
  workspaceActorState: string;
  supportsRunRecovery: boolean;
  actionSurface: TaskDetailActionSurface;
  inputRequest?: InputRequestDto;
  blockedStep?: BlockedStepDto;
  feedback: string;
  setFeedback: (value: string) => void;
  clarificationAnswers: Array<string | string[]>;
  setClarificationAnswer: (index: number, value: string | string[]) => void;
  submittingClarification: boolean;
  submittingDecision: boolean;
  followUpDescription: string;
  setFollowUpDescription: (value: string) => void;
  followUpConfigAlias?: string;
  setFollowUpConfigAlias: (alias: string) => void;
  configEntries: ConfigCatalogEntryDto[];
  submittingFollowUp: boolean;
  submittingRetry: boolean;
  submittingContinue: boolean;
  submittingRecovery: boolean;
  failureReason?: string;
  selectOverview: () => void;
  selectRun: (runId: string) => void;
  openTranscript: (runId: string) => void;
  openArtifact: (artifact: ArtifactRefDto) => void;
  submitApprove: () => Promise<void>;
  submitReject: () => Promise<void>;
  submitClarification: () => Promise<void>;
  submitFollowUp: () => Promise<void>;
  retryTask: (force?: boolean) => Promise<void>;
  continueBlockedTask: () => Promise<void>;
  recoverRun: (nodeRunId: string) => Promise<void>;
};

export function TaskDetailScreen({
  shell,
  goBackToTaskSurface,
  task,
  loading,
  detailError,
  title,
  statusLabel,
  statusTone,
  configLabel,
  stageNodes,
  timelineRuns,
  activityRunActorTypes,
  artifacts,
  selection,
  modal,
  currentRun,
  selectedRun,
  selectedArtifact,
  artifactContent,
  artifactError,
  liveEvents,
  liveEventsRunId,
  selectedRunHistory,
  workspaceActorState,
  supportsRunRecovery,
  actionSurface,
  inputRequest,
  blockedStep,
  feedback,
  setFeedback,
  clarificationAnswers,
  setClarificationAnswer,
  submittingClarification,
  submittingDecision,
  followUpDescription,
  setFollowUpDescription,
  followUpConfigAlias,
  setFollowUpConfigAlias,
  configEntries,
  submittingFollowUp,
  submittingRetry,
  submittingContinue,
  submittingRecovery,
  failureReason,
  selectOverview,
  selectRun,
  openTranscript,
  openArtifact,
  submitApprove,
  submitReject,
  submitClarification,
  submitFollowUp,
  retryTask,
  continueBlockedTask,
  recoverRun,
}: TaskDetailScreenProps) {
  const actionRunId =
    actionSurface.kind !== "none" && "run" in actionSurface
      ? actionSurface.run?.id
      : undefined;
  const realRunIds = new Set(timelineRuns.map((run) => run.id));
  const displayedActivityRuns =
    actionSurface.kind === "blocked" &&
    actionSurface.run &&
    !realRunIds.has(actionSurface.run.id)
      ? [...timelineRuns, actionSurface.run]
      : timelineRuns;
  const currentRunId = currentRun?.id;
  const liveSelectedRunEvents =
    selectedRun?.id && liveEventsRunId === selectedRun.id ? liveEvents : [];
  const transcript = buildTranscriptSnapshot({
    replay: selectedRunHistory?.result,
    liveEvents: liveSelectedRunEvents,
  });
  const rawTranscriptItems = deriveTranscriptTimelineItems(transcript);
  const selectedRunStreamLines = timelineItemsToLines(rawTranscriptItems);
  const selectedRunStreamSource =
    liveSelectedRunEvents.length > 0
      ? "live"
      : selectedRunStreamLines.length > 0
        ? "replay"
        : selectedRunHistory?.loading
          ? "loading"
          : "none";
  const canRecoverSelectedRun = Boolean(
    selectedRun &&
      selectedRun.id === currentRunId &&
      detailStatusLabel(selectedRun.status) === "running" &&
      selectedRunStreamSource === "none" &&
      selectedRunHistory &&
      !selectedRunHistory.loading &&
      !selectedRunHistory.error &&
      !selectedRun.session_id?.trim() &&
      !selectedRunHistory.result?.sessionId?.trim() &&
      !selectedRun.result &&
      supportsRunRecovery &&
      workspaceActorState !== "active",
  );
  const selectedRunClarificationItems = clarificationTranscriptItems({
    rawTranscriptItems,
    run: selectedRun,
  });
  const displayTranscriptItems = mergeDisplayTranscriptItems({
    clarificationItems: selectedRunClarificationItems,
    rawTranscriptItems,
    transcript,
  });
  const createdLabel = formatAbsoluteStamp(task?.task.created_at);
  const durationLabel = summarizeTaskDuration(task, timelineRuns);
  const runsLabel = summarizeRuns(timelineRuns);
  const promptLead = task?.task.description ?? title;
  const activityRef = useRef<HTMLElement | null>(null);
  const shouldStickActivityToBottomRef = useRef(true);
  const lastTaskIdRef = useRef<string | undefined>(undefined);
  const groupedArtifactPaths = new Set(
    timelineRuns.flatMap((run) =>
      artifactsForRun(run, artifacts).map((artifact) => artifact.resolved_path),
    ),
  );
  const ungroupedArtifacts = artifacts.filter(
    (artifact) => !groupedArtifactPaths.has(artifact.resolved_path),
  );

  const artifactModal =
    modal.kind === "artifact" ? (
      <TaskArtifactModal
        artifact={selectedArtifact}
        content={artifactContent}
        error={artifactError}
        onClose={() => {
          if (selectedArtifact?.node_run_id) {
            selectRun(selectedArtifact.node_run_id);
            return;
          }
          selectOverview();
        }}
      />
    ) : null;

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
    const activity = activityRef.current;
    if (!activity) {
      return;
    }
    const updateStickiness = () => {
      const distanceFromBottom =
        activity.scrollHeight - activity.scrollTop - activity.clientHeight;
      shouldStickActivityToBottomRef.current = distanceFromBottom <= 24;
    };
    updateStickiness();
    activity.addEventListener("scroll", updateStickiness);
    return () => {
      activity.removeEventListener("scroll", updateStickiness);
    };
  }, []);

  useLayoutEffect(() => {
    const activity = activityRef.current;
    const taskId = task?.task.id;
    if (!activity || !taskId) {
      return;
    }
    if (lastTaskIdRef.current === taskId) {
      return;
    }
    activity.scrollTop = activity.scrollHeight;
    shouldStickActivityToBottomRef.current = true;
    lastTaskIdRef.current = taskId;
  }, [task?.task.id]);

  useLayoutEffect(() => {
    const activity = activityRef.current;
    if (!activity || !shouldStickActivityToBottomRef.current) {
      return;
    }
    activity.scrollTop = activity.scrollHeight;
  }, [displayedActivityRuns.length, ungroupedArtifacts.length, actionSurface.kind]);

  let actionPanel = null;
  if (actionSurface.kind === "approval") {
    actionPanel = (
      <TaskApprovalDock
        feedback={feedback}
        setFeedback={setFeedback}
        submitApprove={submitApprove}
        submitReject={submitReject}
        submittingDecision={submittingDecision}
      />
    );
  } else if (actionSurface.kind === "clarification") {
    actionPanel = (
      <TaskClarificationDock
        answers={clarificationAnswers}
        questions={inputRequest?.questions ?? []}
        requestKey={`${inputRequest?.task_id ?? "task"}:${inputRequest?.node_run_id ?? "run"}`}
        setAnswer={setClarificationAnswer}
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
        followUpConfigAlias={followUpConfigAlias}
        followUpDescription={followUpDescription}
        onConfigChange={setFollowUpConfigAlias}
        onStartFollowUp={submitFollowUp}
        setFollowUpDescription={setFollowUpDescription}
        submittingFollowUp={submittingFollowUp}
      />
    );
  }

  return (
    <DesktopShellFrame
      addWorkspaceDisabled={shell.phase !== "connected"}
      footerNav={shell.footerNav}
      onPrimaryAction={shell.openNewTask}
      primaryActionDisabled={shell.phase !== "connected" || shell.workspaceCount === 0}
      primaryNav={shell.primaryNav}
      topBarClassName="desktop-shell__topbar--detail"
      topBarLeft={<span />}
      workspaceItems={shell.workspaceItems}
      onAddWorkspace={() => void shell.addWorkspace()}
    >
      <section className="detail-screen" data-testid="task-detail-screen">
        {detailError ? (
          <div className="toast-container">
            <Toast message={detailError} tone="error" onDismiss={() => {}} />
          </div>
        ) : null}

        <div className="detail-layout">
          <div className="detail-main-column">
            <header className="detail-main-header">
              <button
                aria-label="Back to tasks"
                className="detail-main-header__back"
                data-testid="task-detail-back"
                onClick={goBackToTaskSurface}
                type="button"
              >
                <span>‹  Tasks</span>
              </button>
              <div className="detail-main-header__prompt">
                <p className="detail-main-header__prompt-text">{promptLead}</p>
              </div>
            </header>
            <div className="detail-main-divider" />

            <section className="detail-activity" data-testid="detail-activity" ref={activityRef}>
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
                  const showInlineArtifactRow =
                    isRealRun &&
                    runArtifacts.length === 1 &&
                    selectedArtifact?.node_run_id !== run.id;
                  const timing = formatRunTiming(run);
                  const runMeta =
                    actionKindForRun === "approval" ||
                    actionKindForRun === "clarification" ||
                    actionKindForRun === "retry"
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
                        className="detail-activity-card__summary"
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
                            <span
                              className={`detail-activity-card__state detail-activity-card__state--${tone}`}
                            >
                              {runStatus}
                            </span>
                            <span className="detail-activity-card__title-spacer" />
                            {timing.duration ? (
                              <span className="detail-activity-card__duration">
                                {timing.duration}
                              </span>
                            ) : null}
                            <span className="detail-activity-card__time">{timing.relative}</span>
                          </span>
                          {showInlineArtifactRow ? (
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

            {actionSurface.kind === "follow_up" && actionPanel ? (
              <div className="detail-follow-up-slot">{actionPanel}</div>
            ) : null}
          </div>

          <aside className="detail-properties">
            <div className="detail-properties__header">
              <span className="detail-properties__eyebrow">Properties</span>
            </div>
            <div className="detail-properties__divider" />
            <div className="detail-properties__content">
              <div className="detail-properties__block">
                <span className="detail-properties__label">Status</span>
                <StatusBadge label={statusLabel} tone={statusTone} />
              </div>

              <div className="detail-properties__block">
                <span className="detail-properties__label">Config</span>
                <span className="detail-properties__value detail-properties__mono">
                  {configLabel}
                </span>
              </div>

              <div className="detail-properties__block">
                <span className="detail-properties__label">Flow</span>
                {stageNodes.length > 0 ? (
                  <div className="detail-properties__flow">
                    {stageNodes.map((node) => (
                      <span className="detail-properties__flow-row" key={node.name}>
                        <span
                          aria-hidden="true"
                          className={`detail-properties__flow-bullet detail-properties__flow-bullet--${node.status}`}
                        >
                          {flowBullet(node.status)}
                        </span>
                        <span className="detail-properties__value detail-properties__mono">
                          {node.name}
                        </span>
                      </span>
                    ))}
                  </div>
                ) : (
                  <span className="detail-properties__value detail-properties__muted">
                    No workflow nodes yet
                  </span>
                )}
              </div>

              <div className="detail-properties__block">
                <span className="detail-properties__label">Created</span>
                <span className="detail-properties__value">{createdLabel}</span>
              </div>

              <div className="detail-properties__block">
                <span className="detail-properties__label">Duration</span>
                <span className="detail-properties__value">{durationLabel}</span>
              </div>

              <div className="detail-properties__block">
                <span className="detail-properties__label">Runs</span>
                <span className="detail-properties__value detail-properties__muted">
                  {runsLabel}
                </span>
              </div>

            </div>
          </aside>
        </div>
        {artifactModal}
        {transcriptModal}
      </section>
    </DesktopShellFrame>
  );
}
