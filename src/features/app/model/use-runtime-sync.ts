import { useEffect, useEffectEvent } from "react";
import { getRuntime } from "@/app/runtime";
import type { RuntimeNotification } from "@/platform/contract";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";

function extractProgressLines(notification: RuntimeNotification): string[] {
  const payload = notification.payload as
    | { event?: { progress?: RuntimeNotification["payload"] } }
    | undefined;
  const progress = payload?.event?.progress as
    | {
        message?: string;
        events?: Array<{ raw?: string }>;
      }
    | undefined;
  if (!progress) {
    return [];
  }

  const lines: string[] = [];
  for (const event of progress.events ?? []) {
    if (event.raw?.trim()) {
      lines.push(event.raw);
    }
  }
  if (lines.length === 0 && progress.message?.trim()) {
    lines.push(progress.message);
  }
  return lines;
}

export function useRuntimeSync(): void {
  const upsertTask = useTaskSnapshotStore((state) => state.upsertTask);
  const appendLiveOutput = useTaskSnapshotStore((state) => state.appendLiveOutput);
  const resetWorkspaceTasks = useTaskSnapshotStore((state) => state.resetWorkspace);
  const resetTasks = useTaskSnapshotStore((state) => state.reset);
  const upsertWorkspace = useWorkspaceStore((state) => state.upsertWorkspace);
  const removeWorkspace = useWorkspaceStore((state) => state.removeWorkspace);
  const setWorkspaceFailed = useWorkspaceStore((state) => state.setFailed);

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
        resetWorkspaceTasks(notification.workspace_id);
        removeWorkspace(notification.workspace_id);
      }
      return;
    }

    const payload = notification.payload as
      | {
          event?: {
            task_id?: string;
            task_view?: Parameters<typeof upsertTask>[1];
          };
        }
      | undefined;
    const event = payload?.event;
    const workspaceId = notification.workspace_id ?? "";
    if (!event || !workspaceId) {
      return;
    }

    if (event.task_view) {
      upsertTask(workspaceId, event.task_view);
    }

    const taskId = event.task_view?.task.id ?? event.task_id ?? "";
    if (!taskId) {
      return;
    }

    const progressLines = extractProgressLines(notification);
    if (progressLines.length > 0) {
      appendLiveOutput(workspaceId, taskId, progressLines);
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
