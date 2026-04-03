import { useState } from "react";
import { buildTaskDetailPath } from "@/domain/routes";
import {
  formatRelativeTime,
  groupTasksIntoColumns,
  statusTone,
} from "@/domain/task-shell";
import { useShellChrome } from "@/features/app/model/use-shell-chrome";
import { useNewTaskModal } from "@/features/new-task/model/use-new-task-modal";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

const emptyTasks: never[] = [];

export function useEntryScreen() {
  const shell = useShellChrome();
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const tasks = useTaskSnapshotStore(
    (state) =>
      (selectedWorkspaceId
        ? state.tasksByWorkspaceId[selectedWorkspaceId]
        : undefined) ?? emptyTasks,
  );
  const catalog = useWorkspaceStore((state) => state.catalog);
  const [modalOpen, setModalOpen] = useState(false);

  const columns = groupTasksIntoColumns(tasks, shell.boardFilter).map((column) => ({
    ...column,
    cards: column.tasks.map((task) => ({
      id: task.task.id,
      href: selectedWorkspaceId
        ? buildTaskDetailPath(selectedWorkspaceId, task.task.id)
        : "/",
      title: task.task.description || task.task.id,
      meta:
        column.key === "failed"
          ? task.current_issue?.reason || task.current_node_name || "failed"
          : `node: ${task.current_node_name || "n/a"}`,
      time: formatRelativeTime(task.task.updated_at),
      tone: statusTone(task.status),
    })),
  }));

  const modal = useNewTaskModal({
    open: modalOpen,
    onClose: () => setModalOpen(false),
  });

  return {
    shell,
    columns,
    hasTasks: Boolean(selectedWorkspaceId) && tasks.length > 0,
    launchableEntries: (catalog?.entries ?? []).filter((entry) => entry.launchable),
    modalOpen,
    openModal: () => setModalOpen(true),
    closeModal: () => setModalOpen(false),
    modal,
  };
}
