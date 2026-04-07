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

const emptyTasks: never[] = [];

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
        meta: `${
          task.current_issue?.reason ||
          task.current_node_name ||
          task.status.toLowerCase()
        }${scope && !selectedWorkspaceId ? ` · ${scope.workspaceLabel}` : ""}`,
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
      subtitle: `${
        task.current_issue?.reason
          ? task.current_issue.reason
          : `node: ${task.current_node_name || "n/a"}`
      }${scope && !selectedWorkspaceId ? ` · ${scope.workspaceLabel}` : ""}`,
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
