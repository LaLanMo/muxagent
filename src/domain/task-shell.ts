import type {
  ArtifactRefDto,
  ConfigCatalogEntryDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";
import { buildTaskDetailPath } from "@/domain/routes";

export type BoardFilter = "all" | "mine" | "active" | "history";
export type BoardBucket = "running" | "awaiting" | "done" | "failed";
export type DetailMode =
  | "live"
  | "approval"
  | "artifact"
  | "failed"
  | "complete"
  | "blocked";

export type BoardColumn = {
  key: BoardBucket;
  label: string;
  tasks: TaskViewDto[];
};

export type InboxItem = {
  id: string;
  title: string;
  subtitle: string;
  tone: "awaiting" | "failed";
  href: string;
  updatedAt: string;
};

const columnLabels: Record<BoardBucket, string> = {
  running: "RUNNING",
  awaiting: "AWAITING",
  done: "DONE",
  failed: "FAILED",
};

const activeStatuses = new Set(["running", "queued", "starting"]);
const awaitingStatuses = new Set(["awaiting_user", "awaiting_input", "blocked"]);
const doneStatuses = new Set(["done", "completed", "success"]);
const failedStatuses = new Set(["failed", "error", "cancelled"]);

export function displayWorkspaceName(workDir?: string): string {
  if (!workDir) {
    return "Select workspace";
  }
  const normalized = workDir.replace(/[\\/]+$/, "");
  const parts = normalized.split(/[\\/]/).filter(Boolean);
  return parts.at(-1) ?? workDir;
}

export function taskBucket(task: TaskViewDto): BoardBucket {
  const status = task.status.toLowerCase();
  if (failedStatuses.has(status)) {
    return "failed";
  }
  if (awaitingStatuses.has(status)) {
    return "awaiting";
  }
  if (doneStatuses.has(status)) {
    return "done";
  }
  if (activeStatuses.has(status)) {
    return "running";
  }
  return "running";
}

export function groupTasksIntoColumns(
  tasks: TaskViewDto[],
  filter: BoardFilter,
): BoardColumn[] {
  const filtered = tasks.filter((task) => {
    const bucket = taskBucket(task);
    switch (filter) {
      case "active":
        return bucket === "running" || bucket === "awaiting";
      case "history":
        return bucket === "done" || bucket === "failed";
      case "mine":
      case "all":
      default:
        return true;
    }
  });

  return (["running", "awaiting", "done", "failed"] as const).map((key) => ({
    key,
    label: columnLabels[key],
    tasks: filtered.filter((task) => taskBucket(task) === key),
  }));
}

export function statusTone(
  status: string,
): "running" | "awaiting" | "done" | "failed" | "neutral" {
  const bucket = taskBucket({ status } as TaskViewDto);
  switch (bucket) {
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

export function formatRelativeTime(iso: string | undefined): string {
  if (!iso) {
    return "now";
  }
  const ms = Date.now() - Date.parse(iso);
  if (!Number.isFinite(ms) || ms < 0) {
    return "now";
  }
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) {
    return `${seconds}s`;
  }
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return `${minutes}m`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours}h ago`;
  }
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

export function buildStageNodes(task: TaskViewDto): string[] {
  const ordered = new Set<string>();
  for (const run of task.node_runs ?? []) {
    ordered.add(run.node_name);
  }
  if (task.current_node_name) {
    ordered.add(task.current_node_name);
  }
  return [...ordered];
}

export function stageStatusForNode(
  task: TaskViewDto,
  nodeName: string,
): "done" | "current" | "pending" | "failed" {
  const runs = (task.node_runs ?? []).filter((run) => run.node_name === nodeName);
  if (runs.some((run) => failedStatuses.has(run.status.toLowerCase()))) {
    return "failed";
  }
  if (task.current_node_name === nodeName && taskBucket(task) === "awaiting") {
    return "current";
  }
  if (task.current_node_name === nodeName && taskBucket(task) === "running") {
    return "current";
  }
  if (runs.some((run) => doneStatuses.has(run.status.toLowerCase()))) {
    return "done";
  }
  return "pending";
}

export function flowNodesForConfig(entry?: ConfigCatalogEntryDto): string[] {
  if (!entry?.node_names?.length) {
    return [];
  }
  const maxVisible = 5;
  if (entry.node_names.length <= maxVisible) {
    return entry.node_names;
  }
  return [
    ...entry.node_names.slice(0, maxVisible),
    `+${entry.node_names.length - maxVisible} more nodes`,
  ];
}

export function detailModeForTask(args: {
  task: TaskViewDto;
  inputRequest?: InputRequestDto;
  selectedArtifact?: ArtifactRefDto;
}): DetailMode {
  if (args.selectedArtifact) {
    return "artifact";
  }
  const bucket = taskBucket(args.task);
  if (bucket === "failed") {
    return "failed";
  }
  if (bucket === "done") {
    return "complete";
  }
  if (args.inputRequest) {
    return "approval";
  }
  if (bucket === "awaiting" && (args.task.blocked_steps?.length ?? 0) > 0) {
    return "blocked";
  }
  return "live";
}

export function buildInboxItems(
  tasks: TaskViewDto[],
  workspaceId: string,
): InboxItem[] {
  return tasks
    .filter((task) => {
      const bucket = taskBucket(task);
      return bucket === "awaiting" || bucket === "failed";
    })
    .map((task) => ({
      id: task.task.id,
      title: task.task.description || task.task.id,
      subtitle:
        taskBucket(task) === "awaiting"
          ? `Awaiting at ${task.current_node_name || "current node"}`
          : task.current_issue?.reason || "Needs intervention",
      tone: (taskBucket(task) === "awaiting" ? "awaiting" : "failed") as
        | "awaiting"
        | "failed",
      href: buildTaskDetailPath(workspaceId, task.task.id),
      updatedAt: task.task.updated_at,
    }))
    .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt));
}

export function artifactPreviewLabel(artifact: ArtifactRefDto): string {
  return artifact.preview_name || artifact.preview_title || artifact.display_path;
}

export function latestRun(task: TaskViewDto): NodeRunViewDto | undefined {
  return [...(task.node_runs ?? [])].sort((left, right) =>
    right.started_at.localeCompare(left.started_at),
  )[0];
}
