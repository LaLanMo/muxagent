import { taskEntityId } from "@/domain/task-identity";
import type {
  ArtifactRefDto,
  ConfigCatalogEntryDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
  WorkspaceSummaryDto,
} from "@/rpc/types";
import { buildTaskDetailPath } from "@/domain/routes";

export type BoardFilter = "all" | "mine" | "active" | "history" | "attention";
export type BoardBucket = "running" | "awaiting" | "done" | "failed";
export type BoardColumnBucket = "attention" | "running" | "completed";
export type DetailMode =
  | "live"
  | "approval"
  | "artifact"
  | "failed"
  | "complete"
  | "blocked";

export type BoardColumn = {
  key: BoardColumnBucket;
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

export type ScopedTaskView = {
  workspaceId: string;
  workspaceLabel: string;
  task: TaskViewDto;
};

export type BoardLeafTask = {
  leafTask: ScopedTaskView;
  ancestors: ScopedTaskView[];
};

export type ScopedBoardColumn = {
  key: BoardColumnBucket;
  label: string;
  tasks: BoardLeafTask[];
};

export type ScopedTaskBoardGrouping = {
  allLeafTasks: BoardLeafTask[];
  visibleLeafTasks: BoardLeafTask[];
  columns: ScopedBoardColumn[];
};

const boardColumnLabels: Record<BoardColumnBucket, string> = {
  attention: "Needs Attention",
  running: "Running",
  completed: "Completed",
};

const activeStatuses = new Set(["running", "queued", "starting"]);
const awaitingStatuses = new Set(["awaiting_user", "awaiting_input", "blocked"]);
const doneStatuses = new Set(["done", "completed", "success"]);
const failedStatuses = new Set(["failed", "error", "cancelled"]);

export type DetailStatusLabel =
  | "running"
  | "awaiting"
  | "done"
  | "failed"
  | "pending";

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
  const filtered = filterTasks(tasks, filter);

  return (["attention", "running", "completed"] as const).map((key) => ({
    key,
    label: boardColumnLabels[key],
    tasks: filtered.filter((task) => boardColumnBucket(task) === key),
  }))
  .filter((column) => column.tasks.length > 0 || filter === "all");
}

export function boardColumnBucket(task: TaskViewDto): BoardColumnBucket {
  const bucket = taskBucket(task);
  switch (bucket) {
    case "awaiting":
    case "failed":
      return "attention";
    case "done":
      return "completed";
    case "running":
    default:
      return "running";
  }
}

export function filterTasks(tasks: TaskViewDto[], filter: BoardFilter): TaskViewDto[] {
  return tasks.filter((task) => taskMatchesBoardFilter(task, filter));
}

function taskMatchesBoardFilter(task: TaskViewDto, filter: BoardFilter): boolean {
  const bucket = taskBucket(task);
  switch (filter) {
    case "attention":
      return bucket === "awaiting" || bucket === "failed";
    case "active":
      return bucket === "running";
    case "history":
      return bucket === "done";
    case "mine":
    case "all":
    default:
      return true;
  }
}

function sortScopedTasksByUpdatedAtDesc(
  left: ScopedTaskView,
  right: ScopedTaskView,
): number {
  return right.task.task.updated_at.localeCompare(left.task.task.updated_at);
}

function buildLeafTaskAncestors(
  leafTask: ScopedTaskView,
  taskIndex: ReadonlyMap<string, ScopedTaskView>,
): ScopedTaskView[] {
  const ancestors: ScopedTaskView[] = [];
  const visited = new Set<string>([
    taskEntityId(leafTask.workspaceId, leafTask.task.task.id),
  ]);
  let parentTaskId = leafTask.task.task.parent_task_id;

  while (parentTaskId) {
    const parentEntityId = taskEntityId(leafTask.workspaceId, parentTaskId);
    if (visited.has(parentEntityId)) {
      break;
    }
    visited.add(parentEntityId);
    const parentTask = taskIndex.get(parentEntityId);
    if (!parentTask) {
      break;
    }
    ancestors.unshift(parentTask);
    parentTaskId = parentTask.task.task.parent_task_id;
  }

  return ancestors;
}

export function groupScopedTasksIntoBoardColumns(
  scopedTasks: ScopedTaskView[],
  filter: BoardFilter,
): ScopedTaskBoardGrouping {
  const taskIndex = new Map(
    scopedTasks.map((task) => [
      taskEntityId(task.workspaceId, task.task.task.id),
      task,
    ] as const),
  );
  const taskEntityIdsWithChildren = new Set<string>();

  for (const task of scopedTasks) {
    if (!task.task.task.parent_task_id) {
      continue;
    }
    taskEntityIdsWithChildren.add(
      taskEntityId(task.workspaceId, task.task.task.parent_task_id),
    );
  }

  const allLeafTasks = [...scopedTasks]
    .filter(
      (task) =>
        !taskEntityIdsWithChildren.has(taskEntityId(task.workspaceId, task.task.task.id)),
    )
    .map((leafTask) => ({
      leafTask,
      ancestors: buildLeafTaskAncestors(leafTask, taskIndex),
    }))
    .sort((left, right) =>
      sortScopedTasksByUpdatedAtDesc(left.leafTask, right.leafTask),
    );
  const visibleLeafTasks = allLeafTasks.filter((task) =>
    taskMatchesBoardFilter(task.leafTask.task, filter),
  );
  const columns = (["attention", "running", "completed"] as const)
    .map((key) => ({
      key,
      label: boardColumnLabels[key],
      tasks: visibleLeafTasks.filter(
        (task) => boardColumnBucket(task.leafTask.task) === key,
      ),
    }))
    .filter((column) => column.tasks.length > 0 || filter === "all");

  return {
    allLeafTasks,
    visibleLeafTasks,
    columns,
  };
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

export function detailStatusLabel(status: string): DetailStatusLabel {
  const normalized = status.toLowerCase();
  if (
    awaitingStatuses.has(normalized) ||
    normalized.includes("await") ||
    normalized.includes("block")
  ) {
    return "awaiting";
  }
  if (
    failedStatuses.has(normalized) ||
    normalized.includes("fail") ||
    normalized.includes("error")
  ) {
    return "failed";
  }
  if (
    doneStatuses.has(normalized) ||
    normalized.includes("done") ||
    normalized.includes("success") ||
    normalized.includes("complete")
  ) {
    return "done";
  }
  if (
    activeStatuses.has(normalized) ||
    normalized.includes("run") ||
    normalized.includes("start") ||
    normalized.includes("queue")
  ) {
    return "running";
  }
  return "pending";
}

export function findLatestActionableBlockedRun(
  runs: NodeRunViewDto[],
  blockedStep?: { node_name: string },
): NodeRunViewDto | undefined {
  if (!blockedStep) {
    return undefined;
  }

  return [...runs]
    .reverse()
    .find((run) => {
      if (run.node_name !== blockedStep.node_name) {
        return false;
      }
      const statusLabel = detailStatusLabel(run.status);
      return statusLabel === "awaiting" || statusLabel === "running";
    });
}

export function detailStatusTitle(status: string): string {
  switch (detailStatusLabel(status)) {
    case "running":
      return "Running";
    case "awaiting":
      return "Awaiting";
    case "done":
      return "Done";
    case "failed":
      return "Failed";
    case "pending":
    default:
      return "Pending";
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

export function formatBoardRelativeTime(iso: string | undefined): string {
  return formatRelativeTime(iso).replace(" ago", "");
}

function normalizeBoardSummaryLabel(value: string): string {
  return value
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function boardStageLabel(task: TaskViewDto): string {
  const currentNode = normalizeBoardSummaryLabel(task.current_node_name ?? "");
  if (currentNode) {
    return currentNode.toLowerCase();
  }
  return normalizeBoardSummaryLabel(detailStatusTitle(task.status)).toLowerCase();
}

export function buildBoardMetaSummary(
  task: TaskViewDto,
  workspaceLabel?: string,
): string {
  const workspace = workspaceLabel?.trim() || displayWorkspaceName(task.task.work_dir);
  return [
    boardStageLabel(task),
    formatBoardRelativeTime(task.task.updated_at),
    workspace,
  ]
    .filter(Boolean)
    .join(" · ");
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
  const isBlocked =
    args.task.current_issue?.kind === "blocked_step" ||
    (args.task.blocked_steps?.length ?? 0) > 0;
  const bucket = taskBucket(args.task);
  if (isBlocked) {
    return "blocked";
  }
  if (bucket === "failed") {
    return "failed";
  }
  if (bucket === "done") {
    return "complete";
  }
  if (args.inputRequest) {
    return "approval";
  }
  return "live";
}

export function buildInboxItems(
  tasks: ScopedTaskView[],
): InboxItem[] {
  return tasks
    .filter((entry) => {
      const bucket = taskBucket(entry.task);
      return bucket === "awaiting" || bucket === "failed";
    })
    .map((entry) => ({
      id: entry.task.task.id,
      title: entry.task.task.description || entry.task.task.id,
      subtitle: `${
        taskBucket(entry.task) === "awaiting"
          ? `Awaiting at ${entry.task.current_node_name || "current node"}`
          : entry.task.current_issue?.reason || "Needs intervention"
      } · ${entry.workspaceLabel}`,
      tone: (taskBucket(entry.task) === "awaiting" ? "awaiting" : "failed") as
        | "awaiting"
        | "failed",
      href: buildTaskDetailPath(entry.workspaceId, entry.task.task.id),
      updatedAt: entry.task.task.updated_at,
    }))
    .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt));
}

export function collectScopedTasks(
  workspaces: WorkspaceSummaryDto[],
  taskIdsByWorkspaceId: Record<string, string[]>,
  tasksById: Record<string, TaskViewDto>,
): ScopedTaskView[] {
  return workspaces
    .flatMap((workspace) =>
      (taskIdsByWorkspaceId[workspace.workspace_id] ?? [])
        .map((taskId) => tasksById[taskEntityId(workspace.workspace_id, taskId)])
        .filter((task): task is TaskViewDto => Boolean(task))
        .map((task) => ({
          workspaceId: workspace.workspace_id,
          workspaceLabel: workspace.display_name,
          task,
        })),
    )
    .sort((left, right) =>
      right.task.task.updated_at.localeCompare(left.task.task.updated_at),
    );
}

export function artifactPreviewLabel(artifact: ArtifactRefDto): string {
  return artifact.preview_name || artifact.preview_title || artifact.display_path;
}

export function latestRun(task: TaskViewDto): NodeRunViewDto | undefined {
  return [...(task.node_runs ?? [])].sort((left, right) =>
    right.started_at.localeCompare(left.started_at),
  )[0];
}
