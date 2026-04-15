import { buildTaskDetailPath } from "@/domain/routes";
import {
  type BoardMetaDetails,
  type BoardFilter,
  type ScopedTaskView,
  buildBoardMetaDetails,
  formatRelativeTime,
  groupScopedTasksIntoBoardColumns,
  statusTone,
  taskBucket,
} from "@/domain/task-shell";
import type { TaskViewDto } from "@/rpc/types";

function homeRelativePath(normalized: string): string | undefined {
  const unixMatch = normalized.match(/^\/(?:Users|home)\/[^/]+(\/.*)?$/);
  if (unixMatch) {
    return `~${unixMatch[1] ?? ""}` || "~";
  }

  const windowsMatch = normalized.match(/^[A-Za-z]:\/Users\/[^/]+(\/.*)?$/);
  if (windowsMatch) {
    return `~${windowsMatch[1] ?? ""}` || "~";
  }

  return undefined;
}

function compactTaskPath(workDir?: string, fallbackLabel?: string): string {
  const normalized = workDir?.replace(/\\/g, "/").replace(/\/+$/, "");
  if (!normalized) {
    return fallbackLabel ?? "workspace";
  }

  const homeRelative = homeRelativePath(normalized);
  if (homeRelative) {
    return homeRelative || "~";
  }

  const absolutePrefix = normalized.startsWith("/") ? "/" : "";
  const parts = normalized.split("/").filter(Boolean);
  if (parts.length <= 3) {
    return `${absolutePrefix}${parts.join("/")}` || normalized;
  }

  return `…/${parts.slice(-3).join("/")}`;
}

function buildBoardMeta(task: TaskViewDto, fallbackLabel?: string): BoardMetaDetails {
  return buildBoardMetaDetails(task, fallbackLabel);
}

function buildListSubtitle(task: TaskViewDto, fallbackLabel?: string): string {
  const path = compactTaskPath(task.task.work_dir, fallbackLabel);
  const bucket = taskBucket(task);
  if (bucket === "failed") {
    return `${task.current_node_name ?? "failed"}  ·  ${formatRelativeTime(task.task.updated_at)}  ·  ${path}`;
  }
  if (bucket === "awaiting") {
    return `${task.current_node_name ?? "awaiting"}  ·  ${formatRelativeTime(task.task.updated_at)}  ·  ${path}`;
  }
  if (bucket === "done") {
    return `done  ·  ${formatRelativeTime(task.task.updated_at)}  ·  ${path}`;
  }
  return path;
}

type EntryTaskRowModel = {
  id: string;
  workspaceId?: string;
  title: string;
  subtitle: string;
  time: string;
  tone: "running" | "awaiting" | "done" | "failed" | "neutral";
  bucket: ReturnType<typeof taskBucket>;
  href: string;
};

export type EntryTaskBoardModel = {
  columns: Array<{
    key: string;
    label: string;
    cards: Array<{
      id: string;
      workspaceId?: string;
      href: string;
      title: string;
      meta: BoardMetaDetails;
      tone: "running" | "awaiting" | "done" | "failed" | "neutral";
      ancestorCount: number;
      ancestors: Array<{
        id: string;
        title: string;
        meta: BoardMetaDetails;
      }>;
    }>;
  }>;
  rows: EntryTaskRowModel[];
  hasTasks: boolean;
};

export function buildEntryTaskBoardModel(args: {
  scopedTasks: ScopedTaskView[];
  boardFilter: BoardFilter;
}): EntryTaskBoardModel {
  const groupedTasks = groupScopedTasksIntoBoardColumns(args.scopedTasks, args.boardFilter);

  const columns = groupedTasks.columns.map((column) => ({
    ...column,
    cards: column.tasks.map(({ leafTask, ancestors }) => ({
      id: leafTask.task.task.id,
      workspaceId: leafTask.workspaceId,
      href: buildTaskDetailPath(leafTask.workspaceId, leafTask.task.task.id),
      title: leafTask.task.task.description || leafTask.task.task.id,
      meta: buildBoardMeta(leafTask.task, leafTask.workspaceLabel),
      tone: statusTone(leafTask.task.status),
      ancestorCount: ancestors.length,
      ancestors: ancestors.map((ancestor) => ({
        id: ancestor.task.task.id,
        title: ancestor.task.task.description || ancestor.task.task.id,
        meta: buildBoardMeta(ancestor.task, ancestor.workspaceLabel),
      })),
    })),
  }));

  const rows = groupedTasks.visibleLeafTasks.map(({ leafTask }): EntryTaskRowModel => ({
    id: leafTask.task.task.id,
    workspaceId: leafTask.workspaceId,
    title: leafTask.task.task.description || leafTask.task.task.id,
    subtitle: buildListSubtitle(leafTask.task, leafTask.workspaceLabel),
    time: formatRelativeTime(leafTask.task.task.updated_at),
    tone: statusTone(leafTask.task.status),
    bucket: taskBucket(leafTask.task),
    href: buildTaskDetailPath(leafTask.workspaceId, leafTask.task.task.id),
  }));

  return {
    columns,
    rows,
    hasTasks: groupedTasks.allLeafTasks.length > 0,
  };
}
