import {
  useEffect,
  useEffectEvent,
  useId,
  useLayoutEffect,
  useRef,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
  type ReactNode,
} from "react";
import {
  ArrowRight,
  Bot,
  Check,
  ChevronRight,
  CircleDot,
  Copy,
  FileText,
  GitBranch,
  Image,
  Minus,
  Plus,
  RotateCcw,
  SlidersHorizontal,
  SquareArrowOutUpRight,
  User,
  X,
} from "lucide-react";
import ReactMarkdown, { type Components } from "react-markdown";
import remarkGfm from "remark-gfm";
import type { TranscriptSnapshot } from "@/domain/session-history";
import { detailStatusLabel } from "@/domain/task-shell";
import type { FollowUpDockState } from "@/features/task-detail/model/follow-up-dock-state";
import type { TaskDetailArtifactPreview } from "@/features/task-detail/model/use-task-detail-artifact-preview";
import type { TranscriptTimelineItem } from "@/features/task-history/model/timeline";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  ConfigCatalogEntryDto,
  FollowUpModeDto,
  InputQuestionDto,
  NodeRunViewDto,
  TaskFollowUpDto,
  TaskViewDto,
} from "@/rpc/types";
import type { RunHistoryCacheEntry } from "@/state/task-snapshot-store";
import { Button } from "@/features/shared/ui/Button";

type OverviewPaneProps = {
  task?: TaskViewDto;
  runCount: number;
  artifactCount: number;
};

type RunPaneProps = {
  run?: NodeRunViewDto;
  streamLines: string[];
  transcript: TranscriptSnapshot;
  rawTranscriptItems: TranscriptTimelineItem[];
  displayTranscriptItems: TranscriptTimelineItem[];
  clarificationItems: Extract<TranscriptTimelineItem, { kind: "message" }>[];
  historyEntry?: RunHistoryCacheEntry;
  streamSource: "live" | "replay" | "loading" | "none";
  isCurrentRun: boolean;
  showEmptyOutput: boolean;
  recoveryAction?: {
    submitting: boolean;
    onRecover: () => Promise<void>;
  };
  onClose?: () => void;
};

type ArtifactPaneProps = {
  artifact?: ArtifactRefDto;
  preview?: TaskDetailArtifactPreview;
  error?: string;
  actionError?: string;
  onOpenExternally?: () => void;
  onClose?: () => void;
};

type ApprovalDockProps = {
  feedback: string;
  setFeedback: (value: string) => void;
  submittingDecision: boolean;
  submitApprove: () => Promise<void>;
  submitReject: () => Promise<void>;
};

type ClarificationDockProps = {
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
  defaultConfigAlias?: string;
  followUp?: TaskFollowUpDto;
  followUpState?: FollowUpDockState;
  followUpConfigAlias?: string;
  followUpDescription: string;
  followUpMode?: FollowUpModeDto;
  setFollowUpDescription: (value: string) => void;
  onConfigChange: (alias: string) => void;
  onModeChange: (mode: FollowUpModeDto) => void;
  submittingFollowUp: boolean;
  onStartFollowUp: () => Promise<void>;
};

type BlockedDockProps = {
  blockedStep?: BlockedStepDto;
  submittingContinue: boolean;
  onContinue: () => Promise<void>;
};

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

function toneClassForStatus(status: string) {
  switch (status) {
    case "running":
      return "running";
    case "awaiting":
      return "awaiting";
    case "done":
      return "done";
    case "failed":
      return "failed";
    default:
      return "neutral";
  }
}

function formatPanelDuration(startIso?: string, endIso?: string) {
  if (!startIso) {
    return "Not started";
  }
  const start = Date.parse(startIso);
  const end = endIso ? Date.parse(endIso) : Date.now();
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) {
    return "In progress";
  }
  const totalSeconds = Math.max(1, Math.floor((end - start) / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const hours = Math.floor(minutes / 60);
  if (hours > 0) {
    return `${hours}h ${minutes % 60}m`;
  }
  if (minutes > 0) {
    return `${minutes}m ${seconds}s`;
  }
  return `${seconds}s`;
}

function summarizeUsageTokens(items: TranscriptTimelineItem[]) {
  return items.reduce((total, item) => {
    if (item.kind !== "usage") {
      return total;
    }
    return total + (item.usage.totalTokens ?? 0);
  }, 0);
}

function DetailToneBadge({
  label,
  tone,
}: {
  label: string;
  tone: string;
}) {
  return (
    <span className={`detail-tone-badge detail-tone-badge--${toneClassForStatus(tone)}`}>
      {label}
    </span>
  );
}

function DetailMetaItem({
  label,
  value,
}: {
  label: string;
  value: ReactNode;
}) {
  return (
    <span className="detail-modal-frame__meta-item">
      <span className="detail-modal-frame__meta-label">{label}</span>
      <span className="detail-modal-frame__meta-value">{value}</span>
    </span>
  );
}

function DetailInlineMetaPair({
  label,
  value,
}: {
  label: string;
  value: ReactNode;
}) {
  return (
    <span className="detail-artifact-modal__meta-pair">
      <span className="detail-modal-frame__meta-inline-label">{label}</span>
      <span className="detail-modal-frame__meta-inline-value">{value}</span>
    </span>
  );
}

function DetailModalFrame({
  eyebrow,
  title,
  subtitle,
  badge,
  leading,
  meta,
  metaClassName,
  caption,
  onClose,
  children,
  className = "",
}: {
  eyebrow?: string;
  title: string;
  subtitle?: string;
  badge?: ReactNode;
  leading?: ReactNode;
  meta?: ReactNode;
  metaClassName?: string;
  caption?: string;
  onClose?: () => void;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`detail-modal-frame${className ? ` ${className}` : ""}`}>
      <div className="detail-modal-frame__header">
        <div className="detail-modal-frame__header-main">
          {leading ? <span className="detail-modal-frame__leading">{leading}</span> : null}
          <div className="detail-modal-frame__copy">
            {eyebrow ? <span className="detail-modal-frame__eyebrow">{eyebrow}</span> : null}
            <div className="detail-modal-frame__title-row">
              <h3 className="detail-modal-frame__title">{title}</h3>
              {badge}
            </div>
            {subtitle ? <p className="detail-modal-frame__subtitle">{subtitle}</p> : null}
          </div>
        </div>
        {onClose ? (
          <button
            aria-label="Close detail"
            className="detail-modal-frame__dismiss"
            onClick={onClose}
            type="button"
          >
            <X aria-hidden="true" size={14} strokeWidth={1.9} />
          </button>
        ) : null}
      </div>
      {meta ? (
        <div className={`detail-modal-frame__meta${metaClassName ? ` ${metaClassName}` : ""}`}>
          {meta}
        </div>
      ) : null}
      {caption ? <p className="detail-modal-frame__caption">{caption}</p> : null}
      <div className="detail-modal-frame__body">{children}</div>
    </section>
  );
}

function DetailOverlayModal({
  children,
  onClose,
  testId,
}: {
  children: ReactNode;
  onClose: () => void;
  testId: string;
}) {
  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        onClose();
      }
    }

    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [onClose]);

  return (
    <div className="modal-layer" data-testid={testId}>
      <div className="modal-scrim" onClick={onClose} />
      <div className="detail-overlay">
        <div
          aria-modal="true"
          className="detail-overlay__dialog"
          onClick={(event) => event.stopPropagation()}
          role="dialog"
        >
          {children}
        </div>
      </div>
    </div>
  );
}

function prettyResult(result: Record<string, unknown> | undefined) {
  if (!result || Object.keys(result).length === 0) {
    return undefined;
  }
  return JSON.stringify(result, null, 2);
}

const transcriptMarkdownComponents: Components = {
  p({ children }) {
    return <p className="transcript-message__text">{children}</p>;
  },
  ul({ children }) {
    return <ul className="transcript-message__list">{children}</ul>;
  },
  ol({ children }) {
    return <ol className="transcript-message__list transcript-message__list--ordered">{children}</ol>;
  },
  li({ children }) {
    return <li className="transcript-message__list-item">{children}</li>;
  },
  pre({ children }) {
    return <pre className="transcript-message__pre">{children}</pre>;
  },
  code({ children, className, ...props }) {
    const content = String(children).replace(/\n$/, "");
    const isBlock = Boolean(className) || content.includes("\n");
    if (isBlock) {
      return (
        <code className={`transcript-message__code${className ? ` ${className}` : ""}`} {...props}>
          {content}
        </code>
      );
    }
    return (
      <code className="transcript-message__inline-code" {...props}>
        {children}
      </code>
    );
  },
  blockquote({ children }) {
    return <blockquote className="transcript-message__quote">{children}</blockquote>;
  },
  a({ children, href }) {
    return (
      <a className="transcript-message__link" href={href} rel="noreferrer" target="_blank">
        {children}
      </a>
    );
  },
};

function normalizeArtifactModalContent(content: string | undefined) {
  if (!content) {
    return content;
  }

  const lines = content.replace(/\r\n/g, "\n").split("\n");
  let contentStart = 0;

  if (lines[0]?.startsWith("#")) {
    contentStart = 1;
    while (lines[contentStart] === "") {
      contentStart += 1;
    }
  }

  const metadataPrefixes = ["Task:", "Node:", "Artifact:"];
  const hasMetadataBlock = metadataPrefixes.every((prefix, index) =>
    lines[contentStart + index]?.startsWith(prefix),
  );

  if (!hasMetadataBlock) {
    return content;
  }

  let metadataEnd = contentStart + metadataPrefixes.length;
  while (lines[metadataEnd] === "") {
    metadataEnd += 1;
  }

  const preservedHead = lines.slice(0, contentStart);
  const remaining = lines.slice(metadataEnd);
  const normalized = [...preservedHead];

  if (preservedHead.length > 0 && remaining.length > 0) {
    normalized.push("");
  }
  normalized.push(...remaining);

  return normalized.join("\n").replace(/\n{3,}/g, "\n\n").trim();
}

function ArtifactModalContent({
  content,
  format,
}: {
  content?: string;
  format: "markdown" | "text";
}) {
  const normalized = normalizeArtifactModalContent(content) ?? "Loading artifact...";
  const markdownComponents: Components = {
    table({ children }) {
      return <table>{children}</table>;
    },
    a({ children }) {
      return <a className="detail-artifact-modal__link">{children}</a>;
    },
  };

  if (format === "markdown") {
    return (
      <article className="document-content markdown-document detail-artifact-modal__document">
        <ReactMarkdown components={markdownComponents} remarkPlugins={[remarkGfm]}>
          {normalized}
        </ReactMarkdown>
      </article>
    );
  }

  return (
    <pre className="document-content detail-artifact-modal__document detail-artifact-modal__text">
      {normalized}
    </pre>
  );
}

type ArtifactImageFitMode = "contain" | "fit-width" | "actual";

const artifactImageFitModeOptions: Array<{
  value: ArtifactImageFitMode;
  label: string;
}> = [
  { value: "contain", label: "Contain" },
  { value: "fit-width", label: "Fit width" },
  { value: "actual", label: "100%" },
];

const ARTIFACT_IMAGE_ZOOM_STEP = 0.25;
const ARTIFACT_IMAGE_MIN_ZOOM = 0.25;
const ARTIFACT_IMAGE_MAX_ZOOM = 4;
const artifactImageExtensions = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".webp",
  ".bmp",
  ".svg",
]);

function clampNumber(value: number, minimum: number, maximum: number) {
  return Math.min(maximum, Math.max(minimum, value));
}

function artifactPreviewExtension(artifact: ArtifactRefDto | undefined): string {
  if (!artifact) {
    return "";
  }
  for (const candidate of [
    artifact.preview_name,
    artifact.resolved_path,
    artifact.raw_path,
  ]) {
    const normalized = candidate.trim().replace(/\\/g, "/").toLowerCase();
    const basename = normalized.slice(normalized.lastIndexOf("/") + 1);
    const dotIndex = basename.lastIndexOf(".");
    if (dotIndex > 0) {
      return basename.slice(dotIndex);
    }
  }
  return "";
}

function isImageArtifact(artifact: ArtifactRefDto | undefined): boolean {
  return Boolean(artifact && !artifact.markdown && artifactImageExtensions.has(artifactPreviewExtension(artifact)));
}

function formatArtifactByteLength(bytes: number | undefined): string {
  if (!bytes || bytes <= 0) {
    return "Unknown";
  }
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  const kilobytes = bytes / 1024;
  if (kilobytes < 1024) {
    return `${kilobytes.toFixed(kilobytes >= 100 ? 0 : 1)} KB`;
  }
  const megabytes = kilobytes / 1024;
  return `${megabytes.toFixed(megabytes >= 100 ? 0 : 1)} MB`;
}

function formatArtifactImageDimensions(
  dimensions: { width: number; height: number } | undefined,
): string {
  if (!dimensions) {
    return "Loading…";
  }
  return `${dimensions.width} × ${dimensions.height}`;
}

function computeArtifactImageBaseScale({
  fitMode,
  naturalSize,
  containerSize,
}: {
  fitMode: ArtifactImageFitMode;
  naturalSize?: {
    width: number;
    height: number;
  };
  containerSize: {
    width: number;
    height: number;
  };
}) {
  if (!naturalSize || naturalSize.width <= 0 || naturalSize.height <= 0) {
    return 1;
  }
  if (fitMode === "actual") {
    return 1;
  }
  if (containerSize.width <= 0 || containerSize.height <= 0) {
    return 1;
  }
  if (fitMode === "fit-width") {
    return Math.min(containerSize.width / naturalSize.width, 1);
  }
  return Math.min(
    containerSize.width / naturalSize.width,
    containerSize.height / naturalSize.height,
    1,
  );
}

function useArtifactImageViewerState(
  preview: Extract<TaskDetailArtifactPreview, { kind: "image" }> | undefined,
  artifactPath: string | undefined,
) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [fitMode, setFitMode] = useState<ArtifactImageFitMode>("contain");
  const [zoomMultiplier, setZoomMultiplier] = useState(1);
  const [naturalSize, setNaturalSize] = useState<
    | {
        width: number;
        height: number;
      }
    | undefined
  >();
  const [loadError, setLoadError] = useState<string | undefined>();
  const [containerSize, setContainerSize] = useState({ width: 0, height: 0 });

  useEffect(() => {
    setFitMode("contain");
    setZoomMultiplier(1);
    setNaturalSize(undefined);
    setLoadError(undefined);
    setContainerSize({ width: 0, height: 0 });
  }, [artifactPath, preview?.url]);

  useLayoutEffect(() => {
    if (!preview) {
      return;
    }
    const container = containerRef.current;
    if (!container) {
      return;
    }
    const updateSize = (width: number, height: number) => {
      setContainerSize({
        width,
        height,
      });
    };
    updateSize(container.clientWidth, container.clientHeight);
    if (typeof ResizeObserver === "undefined") {
      return;
    }
    const observer = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (!entry) {
        return;
      }
      updateSize(entry.contentRect.width, entry.contentRect.height);
    });
    observer.observe(container);
    return () => {
      observer.disconnect();
    };
  }, [preview]);

  const baseScale = computeArtifactImageBaseScale({
    fitMode,
    naturalSize,
    containerSize,
  });
  const effectiveScale = clampNumber(baseScale * zoomMultiplier, 0.05, 8);
  const renderedWidth = naturalSize
    ? Math.max(1, Math.round(naturalSize.width * effectiveScale))
    : undefined;
  const renderedHeight = naturalSize
    ? Math.max(1, Math.round(naturalSize.height * effectiveScale))
    : undefined;
  const zoomLabel = naturalSize
    ? `${Math.round(effectiveScale * 100)}%`
    : "Loading…";

  function selectFitMode(nextMode: ArtifactImageFitMode) {
    setFitMode(nextMode);
    setZoomMultiplier(1);
  }

  function adjustZoom(delta: number) {
    setZoomMultiplier((value) =>
      clampNumber(
        Number((value + delta).toFixed(2)),
        ARTIFACT_IMAGE_MIN_ZOOM,
        ARTIFACT_IMAGE_MAX_ZOOM,
      ),
    );
  }

  return {
    containerRef,
    fitMode,
    loadError,
    naturalSize,
    renderedWidth,
    renderedHeight,
    zoomLabel,
    canZoomIn:
      Boolean(naturalSize) &&
      !loadError &&
      zoomMultiplier < ARTIFACT_IMAGE_MAX_ZOOM,
    canZoomOut:
      Boolean(naturalSize) &&
      !loadError &&
      zoomMultiplier > ARTIFACT_IMAGE_MIN_ZOOM,
    selectFitMode,
    zoomIn: () => adjustZoom(ARTIFACT_IMAGE_ZOOM_STEP),
    zoomOut: () => adjustZoom(-ARTIFACT_IMAGE_ZOOM_STEP),
    handleImageLoad: (image: HTMLImageElement) => {
      setLoadError(undefined);
      setNaturalSize({
        width: image.naturalWidth,
        height: image.naturalHeight,
      });
    },
    handleImageError: () => {
      setLoadError("Couldn't render this image preview. Open it externally instead.");
    },
  };
}

function ArtifactImageViewer({
  artifact,
  preview,
  viewer,
}: {
  artifact?: ArtifactRefDto;
  preview: Extract<TaskDetailArtifactPreview, { kind: "image" }>;
  viewer: ReturnType<typeof useArtifactImageViewerState>;
}) {
  if (viewer.loadError) {
    return (
      <div className="detail-artifact-modal__image-status detail-artifact-modal__image-status--error">
        <p>{viewer.loadError}</p>
      </div>
    );
  }

  const aspectRatio = viewer.naturalSize
    ? viewer.naturalSize.width / Math.max(viewer.naturalSize.height, 1)
    : undefined;
  const frameClassName = [
    "detail-artifact-modal__image-frame",
    viewer.naturalSize &&
    (viewer.naturalSize.width < 120 || viewer.naturalSize.height < 120)
      ? "detail-artifact-modal__image-frame--tiny"
      : "",
    aspectRatio && (aspectRatio >= 3 || aspectRatio <= 0.35)
      ? "detail-artifact-modal__image-frame--panoramic"
      : "",
  ]
    .filter(Boolean)
    .join(" ");
  const imageStyle =
    viewer.renderedWidth && viewer.renderedHeight
      ? {
          width: `${viewer.renderedWidth}px`,
          height: `${viewer.renderedHeight}px`,
        }
      : undefined;
  const viewerClassName = [
    "detail-artifact-modal__image-viewer",
    aspectRatio && aspectRatio >= 3 ? "detail-artifact-modal__image-viewer--panoramic" : "",
  ]
    .filter(Boolean)
    .join(" ");

  return (
    <div className={viewerClassName}>
      <div
        className={`detail-artifact-modal__image-canvas detail-artifact-modal__image-canvas--${viewer.fitMode}`}
        data-testid="artifact-image-canvas"
        ref={viewer.containerRef}
      >
        <div className="detail-artifact-modal__image-stage">
          <div className={frameClassName}>
            <img
              alt={artifact?.preview_name || "Artifact image preview"}
              className="detail-artifact-modal__image"
              data-testid="artifact-image-preview"
              onError={() => viewer.handleImageError()}
              onLoad={(event) => viewer.handleImageLoad(event.currentTarget)}
              src={preview.url}
              style={imageStyle}
            />
          </div>
        </div>
      </div>
    </div>
  );
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

function shortenArtifactPath(value: string | undefined) {
  const trimmed = value?.trim();
  if (!trimmed) {
    return "unavailable";
  }
  if (trimmed.length <= 52) {
    return trimmed;
  }
  const normalized = trimmed.replaceAll("\\", "/");
  const segments = normalized.split("/").filter(Boolean);
  const tail = segments.slice(-3).join("/");
  if (tail.length <= 40) {
    return `…/${tail}`;
  }
  return `…${trimmed.slice(-47)}`;
}

async function copyTextToClipboard(value: string) {
  if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(value);
    return;
  }
  if (typeof document === "undefined") {
    throw new Error("Clipboard API unavailable");
  }
  const textarea = document.createElement("textarea");
  textarea.value = value;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "absolute";
  textarea.style.left = "-9999px";
  document.body.appendChild(textarea);
  textarea.select();
  const copied = document.execCommand("copy");
  document.body.removeChild(textarea);
  if (!copied) {
    throw new Error("Clipboard copy failed");
  }
}

function useClipboardCopy() {
  const [copyState, setCopyState] = useState<"idle" | "copied" | "failed">("idle");

  useEffect(() => {
    if (copyState === "idle") {
      return;
    }
    const timeoutId = window.setTimeout(() => {
      setCopyState("idle");
    }, 1600);
    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [copyState]);

  const copyValue = useEffectEvent(async (value: string | undefined) => {
    if (!value) {
      return;
    }
    try {
      await copyTextToClipboard(value);
      setCopyState("copied");
    } catch {
      setCopyState("failed");
    }
  });

  return { copyState, copyValue };
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
  recoveryAction?: RunPaneProps["recoveryAction"],
) {
  if (streamSource === "loading") {
    return {
      title: "Loading run history…",
      detail: "Fetching persisted session events for this node run.",
    };
  }
  if (recoveryAction) {
    return {
      title: run.session_id ? "Run may be stale" : "No live output recorded yet",
      detail: run.session_id
        ? "This run is still marked active, but only recovered transcript history is available. If the previous executor was interrupted, recover this run to refresh its state."
        : "This run is still marked active, but no session or transcript was attached. If the previous executor was interrupted, recover this run to refresh its state.",
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

function formatInlineDuration(durationMs: number | undefined): string | undefined {
  if (!durationMs || durationMs <= 0) {
    return undefined;
  }
  const totalSeconds = Math.max(1, Math.round(durationMs / 100) / 10);
  if (totalSeconds >= 60) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = Math.round((totalSeconds % 60) * 10) / 10;
    return seconds > 0 ? `${minutes}m ${seconds}s` : `${minutes}m`;
  }
  return `${totalSeconds}s`;
}

function ExpandChevron({ open = false }: { open?: boolean }) {
  return (
    <ChevronRight
      aria-hidden="true"
      className={`transcript-chevron${open ? " transcript-chevron--open" : ""}`}
      size={12}
      strokeWidth={2}
    />
  );
}

function DoneCheck() {
  return (
    <Check
      aria-hidden="true"
      className="transcript-status-icon transcript-status-icon--done"
      size={14}
      strokeWidth={2.2}
    />
  );
}

function TranscriptFactoryMarker({
  kind,
}: {
  kind: "assistant" | "user" | "neutral";
}) {
  if (kind === "neutral") {
    return <span className="transcript-factory-marker transcript-factory-marker--neutral" />;
  }

  const Icon = kind === "user" ? User : Bot;
  return (
    <span className={`transcript-factory-marker transcript-factory-marker--${kind}`}>
      <Icon aria-hidden="true" size={12} strokeWidth={1.9} />
    </span>
  );
}

function TranscriptFactoryRow({
  marker,
  children,
  className = "",
}: {
  marker: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={`transcript-factory-row${className ? ` ${className}` : ""}`}>
      <span className="transcript-factory-row__marker">{marker}</span>
      <div className="transcript-factory-row__body">{children}</div>
    </div>
  );
}

function formatTranscriptTestId(value: string) {
  return value.replace(/[^a-zA-Z0-9_-]+/g, "-");
}

function prettyToolLabel(label: string | undefined) {
  const trimmed = label?.trim();
  if (!trimmed) {
    return "Tool";
  }
  return trimmed.charAt(0).toUpperCase() + trimmed.slice(1);
}

function summarizeToolKinds(tools: ToolItem[]): string {
  const counts = new Map<string, number>();
  for (const tool of tools) {
    const label = prettyToolLabel(tool.label);
    counts.set(label, (counts.get(label) ?? 0) + 1);
  }
  return [...counts.entries()]
    .map(([label, count]) => (count > 1 ? `${label} ×${count}` : label))
    .join(", ");
}

function formatToolRowLabel(tool: ToolItem): string {
  const label = prettyToolLabel(tool.label);
  const subject = tool.subject?.trim() || tool.title?.trim();
  return subject ? `${label} · ${subject}` : label;
}

function tryPrettyToolJson(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  if (!trimmed) {
    return undefined;
  }
  try {
    return JSON.stringify(JSON.parse(trimmed), null, 2);
  } catch {
    return trimmed;
  }
}

type ToolDetailSection =
  | {
      kind: "meta";
      label: string;
      items: Array<{ label: string; value: string }>;
    }
  | {
      kind: "json" | "text" | "raw";
      label: string;
      content: string;
      tone?: "error";
    }
  | {
      kind: "image";
      label: string;
      src: string;
      alt: string;
      mimeType?: string;
    };

function collectToolDetailContext(tool: ToolItem, transcript: TranscriptSnapshot) {
  const aggregatedTool = transcript.tools[tool.toolId];
  const eventIdSet = new Set(aggregatedTool?.eventIds || tool.eventIds);
  const toolEvents = transcript.events.filter(
    (event): event is Extract<(typeof transcript.events)[number], { kind: "tool" }> =>
      event.kind === "tool" && eventIdSet.has(event.id),
  );
  return { aggregatedTool, toolEvents };
}

function uniqueJoined(values: Array<string | undefined>, separator = "\n\n") {
  return values
    .filter((value): value is string => Boolean(value?.trim()))
    .filter((value, index, all) => all.indexOf(value) === index)
    .join(separator);
}

function buildGenericToolDetailSections(tool: ToolItem, transcript: TranscriptSnapshot): ToolDetailSection[] {
  const { aggregatedTool, toolEvents } = collectToolDetailContext(tool, transcript);
  const inputSummary = [
    aggregatedTool?.inputSummary,
    tool.subject,
    ...toolEvents.map((event) => event.inputSummary),
  ]
    .filter((value): value is string => Boolean(value?.trim()))
    .filter((value, index, values) => values.indexOf(value) === index)
    .join("\n");
  const rawInputJson = aggregatedTool?.rawInputJson || tool.rawInputJson || toolEvents.find((event) => event.rawInputJson)?.rawInputJson;
  const outputText = uniqueJoined([
    aggregatedTool?.outputText,
    tool.outputText,
    ...toolEvents.map((event) => event.outputText),
  ]);
  const rawOutputJson =
    aggregatedTool?.rawOutputJson ||
    tool.rawOutputJson ||
    toolEvents.find((event) => event.rawOutputJson)?.rawOutputJson;
  const errorText = uniqueJoined([
    aggregatedTool?.errorText,
    tool.errorText,
    ...toolEvents.map((event) => event.errorText),
  ]);
  const paths = [...(aggregatedTool?.paths || []), ...tool.paths, ...toolEvents.flatMap((event) => event.paths)]
    .filter(Boolean)
    .filter((value, index, values) => values.indexOf(value) === index);
  const diffs = [...(aggregatedTool?.diffs || []), ...tool.diffs, ...toolEvents.flatMap((event) => event.diffs)]
    .filter(
      (diff, index, values) =>
        values.findIndex(
          (value) =>
            value.path === diff.path &&
            value.oldText === diff.oldText &&
            value.newText === diff.newText,
        ) === index,
    );
  const sections: ToolDetailSection[] = [];

  if (inputSummary?.trim()) {
    sections.push({ kind: "text", label: "Input", content: inputSummary.trim() });
  }

  const prettyInput = tryPrettyToolJson(rawInputJson);
  if (prettyInput) {
    sections.push({ kind: "json", label: "Raw input", content: prettyInput });
  }

  if (paths.length > 0) {
    sections.push({
      kind: "text",
      label: paths.length === 1 ? "Path" : "Paths",
      content: paths.join("\n"),
    });
  }

  if (outputText?.trim()) {
    sections.push({ kind: "text", label: "Output", content: outputText.trim() });
  }

  const prettyOutput = tryPrettyToolJson(rawOutputJson);
  if (prettyOutput) {
    sections.push({ kind: "json", label: "Raw output", content: prettyOutput });
  }

  if (diffs.length > 0) {
    sections.push({
      kind: "text",
      label: diffs.length === 1 ? "Diff" : "Diffs",
      content: diffs
        .map((diff, index) =>
          [
            diff.path ? `${diff.path}` : `change ${index + 1}`,
            diff.oldText ? `old:\n${diff.oldText}` : undefined,
            diff.newText ? `new:\n${diff.newText}` : undefined,
          ]
            .filter(Boolean)
            .join("\n\n"),
        )
        .join("\n\n"),
    });
  }

  if (errorText?.trim()) {
    sections.push({ kind: "text", label: "Error", content: errorText.trim(), tone: "error" });
  }

  return sections;
}

function buildMcpToolDetailSections(tool: ToolItem, transcript: TranscriptSnapshot): ToolDetailSection[] {
  const { aggregatedTool, toolEvents } = collectToolDetailContext(tool, transcript);
  const mcp =
    aggregatedTool?.mcp ??
    toolEvents.find((event) => event.mcp)?.mcp;
  if (!mcp) {
    return buildGenericToolDetailSections(tool, transcript);
  }

  const sections: ToolDetailSection[] = [];
  const metadata = [
    { label: "Server", value: mcp.server?.trim() },
    { label: "Tool", value: mcp.tool?.trim() },
    { label: "Status", value: (aggregatedTool?.status || tool.status || "").trim() || undefined },
    { label: "Duration", value: formatInlineDuration(aggregatedTool?.durationMs ?? tool.durationMs) },
  ]
    .filter((item): item is { label: string; value: string } => Boolean(item.value?.trim()));
  if (metadata.length > 0) {
    sections.push({ kind: "meta", label: "Invocation", items: metadata });
  }

  const prettyArguments = tryPrettyToolJson(mcp.argumentsJson);
  if (prettyArguments) {
    sections.push({ kind: "json", label: "Arguments", content: prettyArguments });
  }

  const prettyStructured = tryPrettyToolJson(mcp.structuredContentJson);
  if (prettyStructured) {
    sections.push({ kind: "json", label: "Structured content", content: prettyStructured });
  }

  let textIndex = 0;
  let imageIndex = 0;
  let fallbackIndex = 0;
  for (const block of mcp.outputBlocks) {
    if (block.type === "text" && block.text?.trim()) {
      textIndex += 1;
      sections.push({
        kind: "text",
        label: textIndex > 1 ? `Text output ${textIndex}` : "Text output",
        content: block.text.trim(),
      });
      continue;
    }
    if (block.type === "image" && block.dataUrl?.trim()) {
      imageIndex += 1;
      sections.push({
        kind: "image",
        label: imageIndex > 1 ? `Image ${imageIndex}` : "Image",
        src: block.dataUrl,
        alt: `${formatToolRowLabel(tool)} image ${imageIndex}`,
        mimeType: block.mimeType,
      });
      continue;
    }
    if (block.type === "json" && block.json?.trim()) {
      fallbackIndex += 1;
      sections.push({
        kind: "json",
        label: block.label?.trim() || (fallbackIndex > 1 ? `JSON block ${fallbackIndex}` : "JSON block"),
        content: tryPrettyToolJson(block.json) || block.json.trim(),
      });
      continue;
    }
    if (block.text?.trim() || block.json?.trim()) {
      fallbackIndex += 1;
      sections.push({
        kind: "raw",
        label: block.label?.trim() || (fallbackIndex > 1 ? `Raw block ${fallbackIndex}` : "Raw block"),
        content: (block.text || block.json || "").trim(),
      });
    }
  }

  if (!mcp.outputBlocks.length && aggregatedTool?.outputText?.trim()) {
    sections.push({ kind: "text", label: "Output preview", content: aggregatedTool.outputText.trim() });
  }

  const errorText = uniqueJoined([
    aggregatedTool?.errorText,
    tool.errorText,
    ...toolEvents.map((event) => event.errorText),
  ]);
  if (errorText.trim()) {
    sections.push({ kind: "text", label: "Error", content: errorText.trim(), tone: "error" });
  }

  const prettyDebug = tryPrettyToolJson(mcp.debugJson ?? aggregatedTool?.rawOutputJson);
  if (prettyDebug) {
    sections.push({ kind: "json", label: "Debug", content: prettyDebug });
  }

  return sections;
}

function buildToolDetailSections(tool: ToolItem, transcript: TranscriptSnapshot): ToolDetailSection[] {
  const aggregatedTool = transcript.tools[tool.toolId];
  if (tool.label === "MCP" || aggregatedTool?.toolKind === "mcp" || aggregatedTool?.mcp) {
    return buildMcpToolDetailSections(tool, transcript);
  }
  return buildGenericToolDetailSections(tool, transcript);
}

function TranscriptToolGroup({
  tools,
  transcript,
}: {
  tools: ToolItem[];
  transcript: TranscriptSnapshot;
}) {
  const kindSummary = summarizeToolKinds(tools);
  const durationMs = tools.reduce((total, tool) => total + (tool.durationMs ?? 0), 0);
  const summaryText = [
    `${tools.length} tool call${tools.length > 1 ? "s" : ""}`,
    kindSummary,
    formatInlineDuration(durationMs || undefined),
  ]
    .filter(Boolean)
    .join(" · ");
  const [open, setOpen] = useState(false);
  const [activeToolId, setActiveToolId] = useState<string | undefined>(undefined);
  const summaryTestId = `transcript-tool-group-${formatTranscriptTestId(tools[0]?.toolId || tools[0]?.id || "group")}`;

  return (
    <div className="transcript-tool-group">
      <button
        className={`transcript-tool-group__summary${open ? " is-open" : ""}`}
        data-testid={summaryTestId}
        onClick={() => {
          setOpen((current) => {
            const next = !current;
            if (!next) {
              setActiveToolId(undefined);
            }
            return next;
          });
        }}
        type="button"
      >
        <ExpandChevron open={open} />
        <span className="transcript-tool-group__summary-text">{summaryText}</span>
      </button>
      {open ? (
        <div className="transcript-tool-group__list">
          {tools.map((tool) => {
            const toolKey = formatTranscriptTestId(tool.toolId || tool.id);
            const sections = buildToolDetailSections(tool, transcript);
            const hasDetails = sections.length > 0;
            const isActive = activeToolId === tool.toolId;
            const detailDuration = formatInlineDuration(tool.durationMs);

            return (
              <div className="transcript-tool-group__item" key={tool.id}>
                {hasDetails ? (
                  <button
                    className={`transcript-tool-group__detail-row transcript-tool-group__detail-row--interactive${isActive ? " is-open" : ""}`}
                    data-testid={`transcript-tool-${toolKey}`}
                    onClick={() =>
                      setActiveToolId((current) => (current === tool.toolId ? undefined : tool.toolId))
                    }
                    type="button"
                  >
                    <span className="transcript-tool-group__detail-arrow">↘</span>
                    <span className="transcript-tool-group__detail-body">
                      {formatToolRowLabel(tool)}
                    </span>
                    {detailDuration ? (
                      <span className="transcript-tool-group__detail-duration">{detailDuration}</span>
                    ) : null}
                    {tool.status ? (
                      <span
                        className={`transcript-tool-group__detail-state transcript-tool-group__detail-state--${tool.status}`}
                      >
                        {tool.status}
                      </span>
                    ) : (
                      <DoneCheck />
                    )}
                  </button>
                ) : (
                  <div className="transcript-tool-group__detail-row" data-testid={`transcript-tool-${toolKey}`}>
                    <span className="transcript-tool-group__detail-arrow">↘</span>
                    <span className="transcript-tool-group__detail-body">
                      {formatToolRowLabel(tool)}
                    </span>
                    {detailDuration ? (
                      <span className="transcript-tool-group__detail-duration">{detailDuration}</span>
                    ) : null}
                    {tool.status ? (
                      <span
                        className={`transcript-tool-group__detail-state transcript-tool-group__detail-state--${tool.status}`}
                      >
                        {tool.status}
                      </span>
                    ) : (
                      <DoneCheck />
                    )}
                  </div>
                )}
                {isActive ? (
                  <div
                    className="transcript-tool-group__detail-panel"
                    data-testid={`transcript-tool-detail-${toolKey}`}
                  >
                    {sections.map((section, index) => {
                      if (section.kind === "meta") {
                        return (
                          <section
                            className="transcript-tool-group__detail-block transcript-tool-group__detail-block--meta"
                            key={`${tool.id}-${section.label}-${index}`}
                          >
                            <span className="transcript-tool-group__detail-label">{section.label}</span>
                            <div className="transcript-tool-group__detail-metadata">
                              {section.items.map((item) => (
                                <div
                                  className="transcript-tool-group__detail-metadata-row"
                                  key={`${tool.id}-${section.label}-${item.label}`}
                                >
                                  <span className="transcript-tool-group__detail-metadata-label">
                                    {item.label}
                                  </span>
                                  <span className="transcript-tool-group__detail-metadata-value">
                                    {item.value}
                                  </span>
                                </div>
                              ))}
                            </div>
                          </section>
                        );
                      }
                      if (section.kind === "image") {
                        return (
                          <section
                            className="transcript-tool-group__detail-block transcript-tool-group__detail-block--image"
                            key={`${tool.id}-${section.label}-${index}`}
                          >
                            <span className="transcript-tool-group__detail-label">{section.label}</span>
                            <div className="transcript-tool-group__detail-image-frame">
                              <img
                                alt={section.alt}
                                className="transcript-tool-group__detail-image"
                                src={section.src}
                              />
                            </div>
                            {section.mimeType ? (
                              <span className="transcript-tool-group__detail-image-meta">
                                {section.mimeType}
                              </span>
                            ) : null}
                          </section>
                        );
                      }
                      return (
                        <section
                          className={`transcript-tool-group__detail-block${
                            section.tone ? ` transcript-tool-group__detail-block--${section.tone}` : ""
                          }`}
                          key={`${tool.id}-${section.label}-${index}`}
                        >
                          <span className="transcript-tool-group__detail-label">{section.label}</span>
                          <pre className="transcript-tool-group__detail-content">{section.content}</pre>
                        </section>
                      );
                    })}
                  </div>
                ) : null}
              </div>
            );
          })}
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
  return (
    <TranscriptFactoryRow className="transcript-thinking" marker={<TranscriptFactoryMarker kind="neutral" />}>
      <p className="transcript-thinking__label">Thinking</p>
      <p className="transcript-thinking__text">{item.text}</p>
    </TranscriptFactoryRow>
  );
}

function TranscriptMessageBlock({
  item,
}: {
  item: Extract<TranscriptTimelineItem, { kind: "message" }>;
}) {
  const isUser = item.role === "user";

  return (
    <TranscriptFactoryRow
      className={`transcript-message${isUser ? " transcript-message--user" : ""}`}
      marker={<TranscriptFactoryMarker kind={isUser ? "user" : "assistant"} />}
    >
      <div className="transcript-message__markdown">
        <ReactMarkdown components={transcriptMarkdownComponents} remarkPlugins={[remarkGfm]}>
          {item.text}
        </ReactMarkdown>
      </div>
    </TranscriptFactoryRow>
  );
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
    <div className="detail-pane detail-pane--overview" data-testid="overview-pane">
      <DetailModalFrame
        badge={
          task ? (
            <DetailToneBadge
              label={detailStatusLabel(task.status)}
              tone={detailStatusLabel(task.status)}
            />
          ) : undefined
        }
        eyebrow="Overview"
        meta={
          <>
            <DetailMetaItem label="Runs" value={runCount} />
            <DetailMetaItem label="Artifacts" value={artifactCount} />
            <DetailMetaItem
              label="Current node"
              value={task?.current_node_name || "No active node"}
            />
          </>
        }
        subtitle="Task summary and task-level actions"
        title={task?.task.description || "Task"}
      >
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
      </DetailModalFrame>
    </div>
  );
}

export function TaskTranscriptModal({
  run,
  streamLines,
  transcript,
  rawTranscriptItems,
  displayTranscriptItems,
  clarificationItems,
  streamSource,
  isCurrentRun,
  showEmptyOutput,
  recoveryAction,
  onClose,
}: RunPaneProps) {
  if (!run) {
    return null;
  }

  const resultContent = prettyResult(run.result);
  const hasStreamOutput = streamLines.length > 0;
  const historyProvenance = formatHistoryProvenance(transcript.provenance);
  const historyCompleteness = formatHistoryCompleteness(transcript.completeness);
  const historyStatusDetail = describeHistoryStatus(streamSource, transcript);
  const providerSessionId = (transcript.sessionId || run.session_id || "").trim();
  const sessionValue = shortenSessionId(providerSessionId);
  const sessionDetail = providerSessionId || "Awaiting session id";
  const totalTokens = summarizeUsageTokens(rawTranscriptItems);
  const eventCount = transcript.events.length || streamLines.length;
  const runStatus = detailStatusLabel(run.status);
  const { copyState, copyValue } = useClipboardCopy();
  const transcriptAvailability = describeTranscriptAvailability(
    streamSource,
    transcript,
    run,
    isCurrentRun,
    recoveryAction,
  );

  function renderTranscriptItem(item: TranscriptTimelineItem) {
    if (item.kind === "message") {
      return (
        <TranscriptMessageBlock key={item.id} item={item} />
      );
    }
    if (item.kind === "tool") {
      const detailParts = [
        item.paths[0],
        formatInlineDuration(item.durationMs),
        item.status ? item.status : undefined,
      ].filter(Boolean);
      return (
        <TranscriptFactoryRow key={item.id} marker={<TranscriptFactoryMarker kind="neutral" />}>
          <div className="transcript-factory-inline">
            <strong className="transcript-factory-inline__title">
              {item.status && item.subject
                ? `${item.label} ${item.status}: ${item.subject}`
                : item.subject
                  ? `${item.label}: ${item.subject}`
                  : item.status
                    ? `${item.label} ${item.status}`
                    : item.label}
            </strong>
            {detailParts.length > 0 ? (
              <p className="transcript-factory-inline__meta">{detailParts.join(" · ")}</p>
            ) : null}
            {item.errorText ? (
              <p className="transcript-factory-inline__meta transcript-tool-row__code--error">
                {item.errorText}
              </p>
            ) : null}
          </div>
        </TranscriptFactoryRow>
      );
    }
    if (item.kind === "plan") {
      return (
        <TranscriptFactoryRow key={item.id} marker={<TranscriptFactoryMarker kind="assistant" />}>
          <div className="transcript-factory-inline">
            <p className="transcript-message__text">{item.summary}</p>
            {item.steps.length > 0 ? (
              <p className="transcript-factory-inline__meta">
                {item.steps
                  .map((step) => `${step.status === "completed" ? "✓" : "•"} ${step.text}`)
                  .join("  ")}
              </p>
            ) : null}
          </div>
        </TranscriptFactoryRow>
      );
    }
    if (item.kind === "usage") {
      return (
        <TranscriptFactoryRow key={item.id} marker={<TranscriptFactoryMarker kind="neutral" />}>
          <div className="transcript-factory-inline">
            <p className="transcript-message__text">{item.summary}</p>
            <p className="transcript-factory-inline__meta">
              total {item.usage.totalTokens ?? 0}
              {item.usage.durationMs ? ` · ${item.usage.durationMs} ms` : ""}
            </p>
          </div>
        </TranscriptFactoryRow>
      );
    }
    return (
      <TranscriptFactoryRow key={item.id} marker={<TranscriptFactoryMarker kind="neutral" />}>
        <div className="transcript-factory-inline">
          <p className="transcript-factory-inline__meta">{item.text || item.raw}</p>
        </div>
      </TranscriptFactoryRow>
    );
  }

  function renderTranscriptTimeline(items: GroupedTranscriptItem[]) {
    return (
      <div className="transcript-timeline" data-testid="transcript-timeline">
        {items.map((item) => {
          if (item.kind === "tool-group") {
            return <TranscriptToolGroup key={item.id} tools={item.tools} transcript={transcript} />;
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
    );
  }

  const groupedRawItems = groupTranscriptItems(rawTranscriptItems);
  const groupedDisplayItems = groupTranscriptItems(displayTranscriptItems);

  return (
    <DetailOverlayModal
      onClose={onClose ?? (() => {})}
      testId={streamSource === "live" ? "live-modal" : "transcript-modal"}
    >
      <DetailModalFrame
        badge={<DetailToneBadge label={runStatus} tone={runStatus} />}
        className="detail-modal-frame--transcript"
        leading={
          <span className={`detail-transcript-modal__leading detail-transcript-modal__leading--${toneClassForStatus(runStatus)}`}>
            <Bot aria-hidden="true" size={12} strokeWidth={1.9} />
          </span>
        }
        meta={
          <>
            <span className="detail-modal-frame__meta-inline-value">
              {formatPanelDuration(run.started_at, run.completed_at)}
            </span>
            <span className="detail-modal-frame__meta-inline-separator">·</span>
            <span className="detail-modal-frame__meta-inline-value">
              {totalTokens.toLocaleString()} tokens
            </span>
            <span className="detail-modal-frame__meta-inline-separator">·</span>
            <span className="detail-modal-frame__meta-inline-value">
              {eventCount} events
            </span>
            <span className="detail-modal-frame__meta-inline-separator">·</span>
            <span className="detail-modal-frame__meta-inline-label">Session</span>
            <button
              aria-label={providerSessionId ? "Copy provider session ID" : "Provider session ID unavailable"}
              className="detail-modal-frame__meta-inline-copy"
              disabled={!providerSessionId}
              onClick={() => {
                void copyValue(providerSessionId);
              }}
              title={providerSessionId || undefined}
              type="button"
            >
              {copyState === "copied" ? (
                <Check aria-hidden="true" size={11} strokeWidth={2} />
              ) : (
                <Copy aria-hidden="true" size={11} strokeWidth={1.9} />
              )}
              <span>{sessionValue}</span>
            </button>
          </>
        }
        onClose={onClose}
        title={run.node_name}
      >
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

        {(() => {
          if (groupedRawItems.length > 0) {
            return (
              <div
                className="detail-modal-frame__surface detail-modal-frame__surface--transcript"
                data-testid="detail-output-surface"
              >
                <pre hidden>{legacyTranscriptText(displayTranscriptItems)}</pre>
                {renderTranscriptTimeline(groupedDisplayItems)}
              </div>
            );
          }
          let fallbackBody: ReactNode = null;
          if (hasStreamOutput) {
            fallbackBody = (
              <div
                className="detail-modal-frame__surface detail-modal-frame__surface--transcript"
                data-testid="detail-output-surface"
              >
                <pre className="detail-code-block">{streamLines.join("\n")}</pre>
              </div>
            );
          } else if (resultContent) {
            fallbackBody = (
              <div
                className="detail-modal-frame__surface detail-modal-frame__surface--transcript"
                data-testid="detail-output-surface"
              >
                <pre className="detail-code-block">{resultContent}</pre>
              </div>
            );
          } else if (showEmptyOutput) {
            fallbackBody = (
              <div
                className="detail-modal-frame__surface detail-modal-frame__surface--transcript"
                data-testid="detail-output-surface"
              >
                <div className="detail-empty-card detail-empty-card--embedded">
                  <strong>{transcriptAvailability.title}</strong>
                  <p>{transcriptAvailability.detail}</p>
                  {recoveryAction ? (
                    <Button
                      data-testid="recover-run"
                      disabled={recoveryAction.submitting}
                      leadingIcon={<RotateCcw strokeWidth={1.9} />}
                      onClick={() => {
                        void recoveryAction.onRecover();
                      }}
                      size="sm"
                      type="button"
                      variant="ghost"
                    >
                      {recoveryAction.submitting ? "Recovering…" : "Recover run"}
                    </Button>
                  ) : null}
                </div>
              </div>
            );
          }

          if (clarificationItems.length === 0) {
            return fallbackBody;
          }

          return (
            <>
              {fallbackBody}
              <div
                className="detail-modal-frame__surface detail-modal-frame__surface--transcript"
                data-testid="transcript-submitted-input"
              >
                <span className="detail-section__label">Submitted input</span>
                {renderTranscriptTimeline(groupTranscriptItems(clarificationItems))}
              </div>
            </>
          );
        })()}
      </DetailModalFrame>
    </DetailOverlayModal>
  );
}

export function TaskArtifactModal({
  artifact,
  preview,
  error,
  actionError,
  onOpenExternally,
  onClose,
}: ArtifactPaneProps) {
  const artifactPath =
    artifact?.resolved_path?.trim() ||
    artifact?.display_path?.trim() ||
    artifact?.raw_path?.trim() ||
    "";
  const { copyState, copyValue } = useClipboardCopy();
  const imagePreview = preview?.kind === "image" ? preview : undefined;
  const imageArtifact = Boolean(imagePreview) || isImageArtifact(artifact);
  const viewer = useArtifactImageViewerState(
    imagePreview,
    artifact?.resolved_path,
  );
  const meta = imagePreview ? (
    <>
      <div className="detail-artifact-modal__meta-summary">
        <DetailInlineMetaPair
          label="Image"
          value={formatArtifactImageDimensions(viewer.naturalSize)}
        />
        <span className="detail-modal-frame__meta-inline-separator">·</span>
        <DetailInlineMetaPair
          label="File"
          value={formatArtifactByteLength(imagePreview.byteLength)}
        />
        <span className="detail-modal-frame__meta-inline-separator">·</span>
        <DetailInlineMetaPair label="Zoom" value={viewer.zoomLabel} />
        <span className="detail-modal-frame__meta-inline-separator">·</span>
        <button
          aria-label={artifactPath ? "Copy artifact file path" : "Artifact file path unavailable"}
          className="detail-modal-frame__meta-inline-copy"
          data-testid="artifact-path-copy"
          disabled={!artifactPath}
          onClick={() => {
            void copyValue(artifactPath);
          }}
          title={artifactPath || undefined}
          type="button"
        >
          {copyState === "copied" ? (
            <Check aria-hidden="true" size={11} strokeWidth={2} />
          ) : (
            <Copy aria-hidden="true" size={11} strokeWidth={1.9} />
          )}
          <span>{shortenArtifactPath(artifactPath)}</span>
        </button>
      </div>
      <div className="detail-artifact-modal__toolbar">
        <div
          aria-label="Image fit mode"
          className="detail-artifact-modal__segmented"
          role="group"
        >
          {artifactImageFitModeOptions.map((option) => (
            <Button
              aria-pressed={viewer.fitMode === option.value}
              className={`detail-artifact-modal__segmented-button${
                viewer.fitMode === option.value ? " is-active" : ""
              }`}
              data-testid={`artifact-image-mode-${option.value}`}
              key={option.value}
              onClick={() => viewer.selectFitMode(option.value)}
              size="sm"
              type="button"
              variant="ghost"
            >
              {option.label}
            </Button>
          ))}
        </div>
        <div aria-label="Image zoom" className="detail-artifact-modal__zoom-controls" role="group">
          <Button
            aria-label="Zoom out"
            className="detail-artifact-modal__icon-button"
            data-testid="artifact-image-zoom-out"
            disabled={!viewer.canZoomOut}
            leadingIcon={<Minus size={13} strokeWidth={2} />}
            onClick={viewer.zoomOut}
            size="sm"
            type="button"
            variant="ghost"
          >
            Zoom out
          </Button>
          <Button
            aria-label="Zoom in"
            className="detail-artifact-modal__icon-button"
            data-testid="artifact-image-zoom-in"
            disabled={!viewer.canZoomIn}
            leadingIcon={<Plus size={13} strokeWidth={2} />}
            onClick={viewer.zoomIn}
            size="sm"
            type="button"
            variant="ghost"
          >
            Zoom in
          </Button>
        </div>
        <Button
          className="detail-artifact-modal__open-button"
          data-testid="artifact-open-externally"
          disabled={!artifact || !onOpenExternally}
          leadingIcon={<SquareArrowOutUpRight size={13} strokeWidth={1.9} />}
          onClick={onOpenExternally}
          size="sm"
          type="button"
          variant="ghost"
        >
          Open externally
        </Button>
      </div>
    </>
  ) : artifact ? (
    <>
      <div className="detail-artifact-modal__meta-summary">
        <DetailInlineMetaPair
          label="Format"
          value={imageArtifact ? "Image" : artifact.markdown ? "Markdown" : "Text"}
        />
        <span className="detail-modal-frame__meta-inline-separator">·</span>
        <button
          aria-label={artifactPath ? "Copy artifact file path" : "Artifact file path unavailable"}
          className="detail-modal-frame__meta-inline-copy"
          data-testid="artifact-path-copy"
          disabled={!artifactPath}
          onClick={() => {
            void copyValue(artifactPath);
          }}
          title={artifactPath || undefined}
          type="button"
        >
          {copyState === "copied" ? (
            <Check aria-hidden="true" size={11} strokeWidth={2} />
          ) : (
            <Copy aria-hidden="true" size={11} strokeWidth={1.9} />
          )}
          <span>{shortenArtifactPath(artifactPath)}</span>
        </button>
      </div>
      <div className="detail-artifact-modal__toolbar">
        <Button
          className="detail-artifact-modal__open-button"
          data-testid="artifact-open-externally"
          disabled={!onOpenExternally}
          leadingIcon={<SquareArrowOutUpRight size={13} strokeWidth={1.9} />}
          onClick={onOpenExternally}
          size="sm"
          type="button"
          variant="ghost"
        >
          Open externally
        </Button>
      </div>
    </>
  ) : undefined;

  return (
    <DetailOverlayModal onClose={onClose ?? (() => {})} testId="artifact-modal">
      <DetailModalFrame
        className="detail-modal-frame--artifact"
        leading={
          <span className="detail-artifact-modal__leading">
            {imagePreview ? (
              <Image aria-hidden="true" size={16} strokeWidth={1.9} />
            ) : (
              <FileText aria-hidden="true" size={16} strokeWidth={1.9} />
            )}
          </span>
        }
        meta={meta}
        metaClassName="detail-artifact-modal__meta"
        onClose={onClose}
        subtitle={`from ${artifact?.source_label || artifact?.node_name || "preview"}`}
        title={artifact?.preview_name || "Preview"}
      >
        {error && !imageArtifact ? <p className="screen-error">{error}</p> : null}
        {actionError ? <p className="screen-error">{actionError}</p> : null}

        <div
          className="detail-modal-frame__surface detail-modal-frame__surface--artifact"
          data-testid="artifact-preview-surface"
        >
          {imagePreview ? (
            <ArtifactImageViewer
              artifact={artifact}
              preview={imagePreview}
              viewer={viewer}
            />
          ) : imageArtifact ? (
            <div
              className={`detail-artifact-modal__image-status${
                error ? " detail-artifact-modal__image-status--error" : ""
              }`}
            >
              <p>{error ?? "Loading image preview…"}</p>
            </div>
          ) : (
            <ArtifactModalContent
              content={preview?.kind === "image" ? undefined : preview?.content}
              format={artifact?.markdown ? "markdown" : "text"}
            />
          )}
        </div>
      </DetailModalFrame>
    </DetailOverlayModal>
  );
}

export function TaskApprovalDock({
  feedback,
  setFeedback,
  submittingDecision,
  submitApprove,
  submitReject,
}: ApprovalDockProps) {
  return (
    <section className="detail-inline-action detail-inline-action--approval" data-testid="approval-pane">
      <p className="detail-inline-action__intro">
        The agent has submitted work for your review. Open the artifact above to see the full
        content.
      </p>
      <label className="detail-inline-action__field">
        <span className="detail-inline-action__label">Feedback (optional)</span>
        <textarea
          className="detail-inline-action__textarea"
          onChange={(event) => setFeedback(event.target.value)}
          placeholder="Leave a note for the agent..."
          rows={2}
          value={feedback}
        />
      </label>

      <div className="detail-inline-action__footer">
        <Button
          data-testid="approval-reject"
          disabled={submittingDecision}
          onClick={() => void submitReject()}
          size="md"
          type="button"
          variant="secondary"
        >
          Reject
        </Button>
        <Button
          data-testid="approval-approve"
          disabled={submittingDecision}
          onClick={() => void submitApprove()}
          size="md"
          type="button"
          variant="primary"
        >
          Approve
        </Button>
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
}: {
  question: InputQuestionDto;
  index: number;
  answer: string | string[];
  setAnswer: (index: number, value: string | string[]) => void;
  labelId: string;
}) {
  const options = question.options ?? [];
  const isMultiSelect = question.multi_select;

  if (options.length === 0) {
    return (
      <textarea
        aria-labelledby={labelId}
        className="detail-inline-action__textarea detail-inline-action__textarea--multiline"
        onChange={(event) => setAnswer(index, event.target.value)}
        placeholder="Type your answer..."
        rows={3}
        value={typeof answer === "string" ? answer : answer.join(", ")}
      />
    );
  }

  const isOther = !isMultiSelect
    ? typeof answer === "string" && !options.some((o) => o.label === answer) && answer !== ""
    : false;
  const [otherText, setOtherText] = useState(isOther ? (answer as string) : "");
  const otherSelected = isOther || otherText.trim().length > 0;

  return (
    <div
      className={`detail-inline-choice-list${
        isMultiSelect ? " detail-inline-choice-list--multi" : ""
      }`}
    >
      {options.map((option) => {
        const checked = Array.isArray(answer)
          ? answer.includes(option.label)
          : answer === option.label;
        return (
          <label
            className={`detail-inline-choice${checked ? " is-selected" : ""}`}
            key={option.label}
          >
            <input
              checked={checked}
              className="detail-inline-choice__input"
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
            <span className="detail-inline-choice__control" aria-hidden="true" />
            <span className="detail-inline-choice__copy">
              <span className="detail-inline-choice__label">{option.label}</span>
            </span>
          </label>
        );
      })}
      <div
        className={`detail-inline-choice detail-inline-choice--other${
          otherSelected ? " is-selected" : ""
        }`}
      >
        <span className="detail-inline-choice__copy detail-inline-choice__copy--other">
          <span className="detail-inline-choice__label">Other:</span>
          <input
            className="detail-inline-choice__other-input"
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
      </div>
    </div>
  );
}

export function TaskClarificationDock({
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

  return (
    <section className="detail-inline-action detail-inline-action--clarification" data-testid="clarification-pane">
      {questions.length > 1 ? (
        <div className="detail-inline-action__nav-row">
          <span className="detail-inline-action__nav-label">
            Question {activeIndex + 1} of {questions.length}
          </span>
          <div className="detail-inline-action__nav-controls">
            <button
              aria-label="Previous clarification"
              className="detail-inline-action__nav-button"
              disabled={activeIndex === 0}
              onClick={() => setActiveIndex((current) => Math.max(current - 1, 0))}
              type="button"
            >
              <span aria-hidden="true">‹</span>
            </button>
            <button
              aria-label="Next clarification"
              className="detail-inline-action__nav-button"
              disabled={activeIndex === questions.length - 1}
              onClick={() =>
                setActiveIndex((current) => Math.min(current + 1, questions.length - 1))
              }
              type="button"
            >
              <span aria-hidden="true">›</span>
            </button>
          </div>
        </div>
      ) : null}

      {activeQuestion ? (
        <div className="detail-inline-action__question-block">
          <div className="detail-inline-action__question">
            <strong id={questionId}>{activeQuestion.question}</strong>
          </div>
          <ClarificationQuestionField
            answer={activeAnswer}
            index={activeIndex}
            labelId={questionId}
            question={activeQuestion}
            setAnswer={setAnswer}
          />
          <div className="detail-inline-action__footer">
            <Button
              disabled={submittingClarification}
              onClick={() => void submitClarification()}
              size="md"
              type="button"
              variant="primary"
            >
              {submittingClarification ? "Sending…" : "Submit"}
            </Button>
          </div>
        </div>
      ) : (
        <p className="muted-copy">No clarification questions were provided.</p>
      )}
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
    <section className="detail-retry-dock" data-testid="failed-pane">
      <p className="detail-retry-dock__error">
        {failureReason ?? "The current task requires intervention."}
      </p>
      <Button
        data-testid="retry-step"
        disabled={submittingRetry || !run}
        leadingIcon={<RotateCcw strokeWidth={1.85} />}
        onClick={() => void onRetry(false)}
        size="sm"
        type="button"
        variant="ghost"
      >
        {submittingRetry ? "Retrying…" : "Retry"}
      </Button>
    </section>
  );
}

function followUpModeLabel(mode: FollowUpModeDto) {
  switch (mode) {
    case "continue_here":
      return "Continue here";
    case "fork_head":
      return "Fork from HEAD";
    case "fork_with_changes":
      return "Fork with changes";
  }
}

function followUpModeMeta(mode: FollowUpModeDto, changeCount: number) {
  switch (mode) {
    case "continue_here":
      return "same worktree";
    case "fork_head":
      return `without ${changeCount} uncommitted`;
    case "fork_with_changes":
      return `with ${changeCount} uncommitted`;
  }
}

function followUpTriggerMeta(mode: FollowUpModeDto, changeCount: number) {
  if (mode === "continue_here") {
    return undefined;
  }
  return `${changeCount} uncommitted`;
}

function followUpModeIcon(mode: FollowUpModeDto) {
  return mode === "continue_here" ? CircleDot : GitBranch;
}

function FollowUpModeGlyph({ mode }: { mode: FollowUpModeDto }) {
  const Icon = followUpModeIcon(mode);
  return <Icon aria-hidden="true" size={14} strokeWidth={1.8} />;
}

export function TaskFollowUpDock({
  configEntries,
  defaultConfigAlias,
  followUp,
  followUpState,
  followUpConfigAlias,
  followUpDescription,
  followUpMode,
  setFollowUpDescription,
  onConfigChange,
  onModeChange,
  submittingFollowUp,
  onStartFollowUp,
}: FollowUpDockProps) {
  const launchable = configEntries.filter((entry) => entry.launchable);
  const selectedEntry =
    launchable.find((entry) => entry.alias === followUpConfigAlias) ??
    launchable.find((entry) => entry.alias === defaultConfigAlias) ??
    launchable[0];
  const configPickerId = useId();
  const modePickerId = useId();
  const rootRef = useRef<HTMLElement | null>(null);
  const configTriggerRef = useRef<HTMLButtonElement | null>(null);
  const modeTriggerRef = useRef<HTMLButtonElement | null>(null);
  const inputRef = useRef<HTMLTextAreaElement | null>(null);
  const [configPickerOpen, setConfigPickerOpen] = useState(false);
  const [modePickerOpen, setModePickerOpen] = useState(false);
  const dockState = followUpState ?? (followUp ? "refine" : "basic");

  const closeOverlays = useEffectEvent(
    (focusTarget?: "config-trigger" | "mode-trigger" | "input") => {
      setConfigPickerOpen(false);
      setModePickerOpen(false);
      if (focusTarget === "config-trigger") {
        configTriggerRef.current?.focus();
        return;
      }
      if (focusTarget === "mode-trigger") {
        modeTriggerRef.current?.focus();
        return;
      }
      if (focusTarget === "input") {
        inputRef.current?.focus();
      }
    },
  );

  useEffect(() => {
    if (dockState !== "refine" && modePickerOpen) {
      setModePickerOpen(false);
    }
  }, [dockState, modePickerOpen]);

  useEffect(() => {
    if (!configPickerOpen && !modePickerOpen) {
      return;
    }

    function handlePointerDown(event: PointerEvent) {
      if (!(event.target instanceof Node)) {
        return;
      }
      if (!rootRef.current?.contains(event.target)) {
        closeOverlays();
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.preventDefault();
        closeOverlays(
          modePickerOpen ? "mode-trigger" : configPickerOpen ? "config-trigger" : undefined,
        );
      }
    }

    document.addEventListener("pointerdown", handlePointerDown, true);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("pointerdown", handlePointerDown, true);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [closeOverlays, configPickerOpen, modePickerOpen]);

  useLayoutEffect(() => {
    const input = inputRef.current;
    if (!input) {
      return;
    }
    input.style.height = "0px";
    input.style.height = `${input.scrollHeight}px`;
  }, [followUpDescription]);

  function handleDescriptionKeyDown(event: ReactKeyboardEvent<HTMLTextAreaElement>) {
    if (
      event.key !== "Enter" ||
      event.shiftKey ||
      event.altKey ||
      event.ctrlKey ||
      event.metaKey
    ) {
      return;
    }
    if (event.nativeEvent.isComposing || event.keyCode === 229) {
      return;
    }
    event.preventDefault();
    if (dockState !== "pending" && !submittingFollowUp) {
      void onStartFollowUp();
    }
  }

  const selectedAlias = selectedEntry?.alias ?? followUpConfigAlias ?? defaultConfigAlias ?? "";
  const selectedMode: FollowUpModeDto =
    followUpMode && followUp?.available_modes.includes(followUpMode)
      ? followUpMode
      : followUp?.default_mode ?? "continue_here";
  const modeTriggerMeta = followUp ? followUpTriggerMeta(selectedMode, followUp.uncommitted_change_count) : undefined;
  const canSubmit = dockState !== "pending" && !submittingFollowUp;
  const configSelectable = launchable.length > 1;

  return (
    <section
      className="detail-follow-up-rail"
      data-follow-up-state={dockState}
      data-testid="complete-pane"
      ref={rootRef}
    >
      <form
        className={`detail-follow-up-rail__box${
          configPickerOpen || modePickerOpen ? " is-picker-open" : ""
        } detail-follow-up-rail__box--${dockState}`}
        onSubmit={(event) => {
          event.preventDefault();
          if (dockState !== "pending") {
            void onStartFollowUp();
          }
        }}
      >
        <textarea
          aria-label="Follow-up description"
          className="detail-follow-up-rail__input"
          data-testid="follow-up-description"
          disabled={submittingFollowUp}
          onChange={(event) => setFollowUpDescription(event.target.value)}
          onKeyDown={handleDescriptionKeyDown}
          placeholder="Send a follow-up request..."
          ref={inputRef}
          rows={1}
          value={followUpDescription}
        />
        <div className="detail-follow-up-rail__divider" />
        <div className="detail-follow-up-rail__footer">
          <div className="detail-follow-up-rail__footer-left">
            {selectedAlias ? (
              <div className="detail-follow-up-rail__config-anchor">
                <button
                  aria-controls={configPickerOpen ? configPickerId : undefined}
                  aria-expanded={configPickerOpen}
                  aria-haspopup="listbox"
                  className="detail-follow-up-rail__config-trigger"
                  data-testid="follow-up-config-trigger"
                  disabled={submittingFollowUp || !configSelectable}
                  onClick={() => {
                    if (!configSelectable) {
                      return;
                    }
                    setModePickerOpen(false);
                    setConfigPickerOpen((current) => !current);
                  }}
                  ref={configTriggerRef}
                  type="button"
                >
                  <SlidersHorizontal aria-hidden="true" size={12} strokeWidth={1.9} />
                  <span>{selectedAlias}</span>
                </button>
                {configPickerOpen ? (
                  <div
                    aria-label="Configs"
                    className="detail-follow-up-rail__config-picker"
                    data-testid="follow-up-config-picker"
                    id={configPickerId}
                    role="listbox"
                  >
                    <span className="detail-follow-up-rail__config-picker-label">Configs</span>
                    {launchable.map((entry) => {
                      const selected = entry.alias === selectedEntry?.alias;
                      const nodeCountLabel =
                        entry.node_names != null
                          ? `${entry.node_names.length} ${entry.node_names.length === 1 ? "node" : "nodes"}`
                          : undefined;
                      return (
                        <button
                          aria-selected={selected}
                          className={`detail-follow-up-rail__config-option${selected ? " is-selected" : ""}`}
                          data-testid={`follow-up-config-option-${entry.alias}`}
                          key={entry.alias}
                          onClick={() => {
                            onConfigChange(entry.alias);
                            closeOverlays("input");
                          }}
                          role="option"
                          type="button"
                        >
                          <span className="detail-follow-up-rail__config-option-name">
                            {entry.alias}
                          </span>
                          {nodeCountLabel ? (
                            <>
                              <span className="detail-follow-up-rail__config-option-divider" />
                              <span className="detail-follow-up-rail__config-option-count">
                                {nodeCountLabel}
                              </span>
                            </>
                          ) : null}
                        </button>
                      );
                    })}
                  </div>
                ) : null}
              </div>
            ) : null}
          </div>
          <div className="detail-follow-up-rail__footer-actions">
            {dockState === "pending" ? (
              <div
                className="detail-follow-up-rail__mode-pill detail-follow-up-rail__mode-pill--pending"
                data-testid="follow-up-mode-pending"
              >
                <span>Resolving follow-up modes…</span>
              </div>
            ) : dockState === "refine" ? (
              <div className="detail-follow-up-rail__mode-anchor">
                <button
                  aria-controls={modePickerOpen ? modePickerId : undefined}
                  aria-expanded={modePickerOpen}
                  aria-haspopup="listbox"
                  className="detail-follow-up-rail__mode-trigger"
                  data-testid="follow-up-mode-trigger"
                  disabled={submittingFollowUp || !followUp}
                  onClick={() => {
                    if (!followUp) {
                      return;
                    }
                    setConfigPickerOpen(false);
                    setModePickerOpen((current) => !current);
                  }}
                  ref={modeTriggerRef}
                  type="button"
                >
                  <span className="detail-follow-up-rail__mode-trigger-main">
                    <FollowUpModeGlyph mode={selectedMode} />
                    <span>{followUpModeLabel(selectedMode)}</span>
                    {modeTriggerMeta ? (
                      <span
                        className="detail-follow-up-rail__mode-trigger-meta"
                        data-testid="follow-up-dirty-hint"
                      >
                        · {modeTriggerMeta}
                      </span>
                    ) : null}
                  </span>
                </button>
                {modePickerOpen && followUp ? (
                  <div
                    aria-label="Follow-up modes"
                    className="detail-follow-up-rail__mode-popup"
                    data-testid="follow-up-mode-popup"
                    id={modePickerId}
                    role="listbox"
                  >
                    <span className="detail-follow-up-rail__mode-popup-label">Mode</span>
                    {followUp.available_modes.map((mode) => {
                      const selected = mode === selectedMode;
                      return (
                        <button
                          aria-selected={selected}
                          className={`detail-follow-up-rail__mode-option${selected ? " is-selected" : ""}`}
                          data-testid={`follow-up-mode-option-${mode}`}
                          key={mode}
                          onClick={() => {
                            onModeChange(mode);
                            closeOverlays("input");
                          }}
                          role="option"
                          type="button"
                        >
                          <span className="detail-follow-up-rail__mode-option-title">
                            {followUpModeLabel(mode)}
                          </span>
                          <span className="detail-follow-up-rail__mode-option-rule" />
                          <span className="detail-follow-up-rail__mode-option-meta">
                            {followUpModeMeta(mode, followUp.uncommitted_change_count)}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                ) : null}
              </div>
            ) : null}
            <Button
              className="detail-follow-up-rail__send"
              data-testid="follow-up-send"
              disabled={!canSubmit}
              size="sm"
              type="submit"
              variant="primary"
            >
              {submittingFollowUp ? "Sending…" : "Send"}
            </Button>
          </div>
        </div>
      </form>
    </section>
  );
}

export function TaskBlockedDock({
  blockedStep,
  submittingContinue,
  onContinue,
}: BlockedDockProps) {
  return (
    <section className="detail-retry-dock detail-blocked-dock" data-testid="blocked-pane">
      <p className="detail-retry-dock__error detail-blocked-dock__description">
        {blockedStep?.reason ?? "The current task is waiting to continue."}
      </p>
      <Button
        className="detail-blocked-dock__continue-button"
        data-testid="continue-blocked"
        disabled={submittingContinue}
        leadingIcon={
          !submittingContinue
            ? <ArrowRight size={13} strokeWidth={1.9} />
            : undefined
        }
        onClick={() => void onContinue()}
        size="sm"
        type="button"
        variant="ghost"
      >
        {submittingContinue ? "Continuing…" : "Continue"}
      </Button>
    </section>
  );
}
