import { useSearchParams } from "react-router-dom";
import { buildTaskDetailPath } from "@/domain/routes";
import {
  collectScopedTasks,
  filterTasks,
  formatRelativeTime,
  groupTasksIntoColumns,
  statusTone,
  taskBucket,
} from "@/domain/task-shell";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { useNewTaskModal } from "@/features/new-task/model/use-new-task-modal";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";
import type { TaskViewDto } from "@/rpc/types";

const emptyTasks: never[] = [];

function compactTaskPath(workDir?: string, fallbackLabel?: string): string {
  const normalized = workDir?.replace(/[\\/]+$/, "");
  if (!normalized) {
    return fallbackLabel ?? "workspace";
  }
  const parts = normalized.split(/[\\/]/).filter(Boolean);
  const projectsIndex = parts.lastIndexOf("Projects");
  if (projectsIndex >= 0 && projectsIndex < parts.length - 1) {
    const projectPath = parts.slice(projectsIndex).join("/");
    return `~/${projectPath}`;
  }
  if (parts[0] === "tmp") {
    return `~/${parts.at(-1) || fallbackLabel || "workspace"}`;
  }
  const tail = parts.slice(-2).join("/");
  return `~/${tail || parts.at(-1) || fallbackLabel || "workspace"}`;
}

function buildBoardMeta(task: TaskViewDto, fallbackLabel?: string): string {
  return compactTaskPath(task.task.work_dir, fallbackLabel);
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

export function useEntryScreen() {
  const shell = useShellModel();
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const tasksByWorkspaceId = useTaskSnapshotStore((state) => state.tasksByWorkspaceId);
  const scopedTasks = selectedWorkspaceId
    ? (tasksByWorkspaceId[selectedWorkspaceId] ?? emptyTasks).map((task) => ({
        workspaceId: selectedWorkspaceId,
        workspaceLabel:
          workspaces.find((workspace) => workspace.workspace_id === selectedWorkspaceId)
            ?.display_name ?? "Workspace",
        task,
      }))
    : collectScopedTasks(workspaces, tasksByWorkspaceId);
  const tasks = scopedTasks.map((entry) => entry.task);
  const scopedTaskByView = new WeakMap(
    scopedTasks.map((entry) => [entry.task, entry] as const),
  );
  const catalog = useWorkspaceStore((state) => state.catalog);
  const [searchParams, setSearchParams] = useSearchParams();
  const modalOpen = searchParams.get("newTask") === "1";

  function setModalOpen(nextOpen: boolean) {
    const next = new URLSearchParams(searchParams);
    if (nextOpen) {
      next.set("newTask", "1");
    } else {
      next.delete("newTask");
    }
    setSearchParams(next, { replace: true });
  }

  const columns = groupTasksIntoColumns(tasks, shell.boardFilter).map((column) => ({
    ...column,
    cards: column.tasks.map((task) => {
      const scope = scopedTaskByView.get(task);
      return {
        id: task.task.id,
        workspaceId: scope?.workspaceId,
        href: scope ? buildTaskDetailPath(scope.workspaceId, task.task.id) : "/",
        title: task.task.description || task.task.id,
        meta: buildBoardMeta(task, scope?.workspaceLabel),
        time: formatRelativeTime(task.task.updated_at),
        tone: statusTone(task.status),
      };
    }),
  }));
  const rows = filterTasks(tasks, shell.boardFilter).map((task) => {
    const scope = scopedTaskByView.get(task);
    return {
      id: task.task.id,
      workspaceId: scope?.workspaceId,
      title: task.task.description || task.task.id,
      subtitle: buildListSubtitle(task, scope?.workspaceLabel),
      time: formatRelativeTime(task.task.updated_at),
      tone: statusTone(task.status),
      bucket: taskBucket(task),
      href: scope ? buildTaskDetailPath(scope.workspaceId, task.task.id) : "/",
    };
  });

  const modal = useNewTaskModal({
    open: modalOpen,
    onClose: () => setModalOpen(false),
  });

  return {
    shell,
    columns,
    rows,
    hasTasks: tasks.length > 0,
    launchableEntries: (catalog?.entries ?? []).filter((entry) => entry.launchable),
    modalOpen,
    openModal: () => setModalOpen(true),
    closeModal: () => setModalOpen(false),
    modal,
  };
}
