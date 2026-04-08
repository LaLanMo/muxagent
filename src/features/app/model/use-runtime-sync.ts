import { useEffect, useEffectEvent } from "react";
import { parseTaskNotification } from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import type { RuntimeNotification } from "@/platform/contract";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useRuntimeSync(): void {
  const upsertTask = useTaskSnapshotStore((state) => state.upsertTask);
  const appendLiveOutput = useTaskSnapshotStore((state) => state.appendLiveOutput);
  const invalidateTaskDetail = useTaskSnapshotStore(
    (state) => state.invalidateTaskDetail,
  );
  const resetTasks = useTaskSnapshotStore((state) => state.reset);
  const upsertWorkspace = useWorkspaceStore((state) => state.upsertWorkspace);
  const setWorkspaceFailed = useWorkspaceStore((state) => state.setFailed);
  const { removeWorkspaceFromState } = useWorkspaceSelection();

  const handleNotification = useEffectEvent((notification: RuntimeNotification) => {
    if (
      notification.kind === "workspace.added" ||
      notification.kind === "workspace.updated"
    ) {
      const payload = notification.payload as
        | { workspace?: Parameters<typeof upsertWorkspace>[0] }
        | undefined;
      if (payload?.workspace) {
        upsertWorkspace(payload.workspace);
      }
      return;
    }

    if (notification.kind === "workspace.removed") {
      if (notification.workspace_id) {
        void removeWorkspaceFromState(notification.workspace_id);
      }
      return;
    }

    const taskNotification = parseTaskNotification(notification);
    if (!taskNotification) {
      return;
    }

    if (taskNotification.taskView) {
      upsertTask(taskNotification.workspaceId, taskNotification.taskView);
    }

    if (taskNotification.progressLines.length > 0 || taskNotification.nodeRunId) {
      appendLiveOutput(
        taskNotification.workspaceId,
        taskNotification.taskId,
        taskNotification.nodeRunId,
        taskNotification.progressLines,
      );
    }

    if (taskNotification.shouldRefreshDetail) {
      invalidateTaskDetail(
        taskNotification.workspaceId,
        taskNotification.taskId,
      );
    }
  });

  const handleConnectionLoss = useEffectEvent((error: Error) => {
    resetTasks();
    setWorkspaceFailed(error.message);
  });

  useEffect(() => {
    const runtime = getRuntime();
    return runtime.backend.subscribe((notification) => {
      handleNotification(notification);
    });
  }, [handleNotification]);

  useEffect(() => {
    const runtime = getRuntime();
    return runtime.backend.onConnectionLoss((error) => {
      handleConnectionLoss(error);
    });
  }, [handleConnectionLoss]);
}
