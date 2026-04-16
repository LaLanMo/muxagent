import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  cleanupTaskWorktree,
  continueBlockedUntilResumed,
  loadTaskList,
  recoverStaleTaskRun,
  retryTaskUntilResumed,
  startFollowUpAndReloadTaskList,
  submitTaskApproval,
  submitTaskClarification,
} from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import { buildTaskDetailPath } from "@/domain/routes";
import type { LoadTaskDetailFn } from "@/features/task-detail/model/use-task-detail-data";
import type {
  ConfigCatalogEntryDto,
  FollowUpModeDto,
  InputRequestDto,
  TaskViewDto,
  WorktreeCleanupInfoDto,
} from "@/rpc/types";
import { tasksForWorkspace, useTaskSnapshotStore } from "@/state/task-snapshot-store";
import type { LoadTaskWorktreeCleanupInfoFn } from "@/features/task-detail/model/use-task-worktree-cleanup";

function resolveFollowUpConfigEntry(args: {
  configEntries: ConfigCatalogEntryDto[];
  task: TaskViewDto;
  followUpConfigAlias?: string;
}) {
  const { configEntries, task, followUpConfigAlias } = args;
  return (
    configEntries.find(
      (entry) => entry.launchable && entry.alias === followUpConfigAlias,
    ) ??
    configEntries.find(
      (entry) => entry.launchable && entry.alias === task.task.config_alias,
    ) ??
    configEntries.find((entry) => entry.launchable)
  );
}

type UseTaskDetailActionsArgs = {
  workspaceId: string;
  taskId: string;
  task: TaskViewDto | undefined;
  configEntries: ConfigCatalogEntryDto[];
  inputRequest: InputRequestDto | undefined;
  latestFailedRunId: string | undefined;
  loadDetail: LoadTaskDetailFn;
  worktreeCleanupInfo: WorktreeCleanupInfoDto | undefined;
  loadCleanupInfo: LoadTaskWorktreeCleanupInfoFn;
};

export function useTaskDetailActions({
  workspaceId,
  taskId,
  task,
  configEntries,
  inputRequest,
  latestFailedRunId,
  loadDetail,
  worktreeCleanupInfo,
  loadCleanupInfo,
}: UseTaskDetailActionsArgs) {
  const navigate = useNavigate();
  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
  const taskIdsByWorkspaceId = useTaskSnapshotStore(
    (state) => state.taskIdsByWorkspaceId,
  );
  const setTasks = useTaskSnapshotStore((state) => state.setTasks);
  const failTaskDetail = useTaskSnapshotStore(
    (state) => state.failTaskDetail,
  );
  const clearTaskDetailIssue = useTaskSnapshotStore(
    (state) => state.clearTaskDetailIssue,
  );
  const invalidateTaskDetail = useTaskSnapshotStore(
    (state) => state.invalidateTaskDetail,
  );
  const [submittingDecision, setSubmittingDecision] = useState(false);
  const [submittingClarification, setSubmittingClarification] = useState(false);
  const [submittingFollowUp, setSubmittingFollowUp] = useState(false);
  const [worktreeCleanupDialogOpen, setWorktreeCleanupDialogOpen] = useState(false);
  const [loadingWorktreeCleanupDialog, setLoadingWorktreeCleanupDialog] = useState(false);
  const [submittingWorktreeCleanup, setSubmittingWorktreeCleanup] = useState(false);
  const [retryingNodeId, setRetryingNodeId] = useState<string | undefined>();
  const [continuingBlocked, setContinuingBlocked] = useState(false);
  const [recoveringNodeId, setRecoveringNodeId] = useState<string | undefined>();
  const tasks = tasksForWorkspace(taskIdsByWorkspaceId, tasksById, workspaceId);

  useEffect(() => {
    setWorktreeCleanupDialogOpen(false);
    setLoadingWorktreeCleanupDialog(false);
  }, [taskId]);

  async function runTaskAction(
    fallbackMessage: string,
    action: () => Promise<void>,
  ): Promise<boolean> {
    clearTaskDetailIssue(workspaceId, taskId);
    try {
      await action();
      return true;
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : typeof error === "string" && error.trim()
            ? error
            : fallbackMessage;
      failTaskDetail(
        workspaceId,
        taskId,
        message,
      );
      return false;
    }
  }

  async function submitDecision(approved: boolean, feedback: string): Promise<void> {
    if (!inputRequest || !taskId || !workspaceId) {
      return;
    }
    setSubmittingDecision(true);
    try {
      await runTaskAction("Failed to submit approval", async () => {
        await submitTaskApproval(getRuntime(), {
          workspaceId,
          taskId,
          inputRequest,
          approved,
          feedback,
        });
        invalidateTaskDetail(workspaceId, taskId);
      });
    } finally {
      setSubmittingDecision(false);
    }
  }

  async function submitClarification(
    clarificationAnswers: Array<string | string[]>,
  ): Promise<void> {
    if (!inputRequest || inputRequest.kind !== "clarification" || !taskId || !workspaceId) {
      return;
    }
    const questions = inputRequest.questions ?? [];
    if (questions.length === 0) {
      return;
    }
    setSubmittingClarification(true);
    try {
      await runTaskAction("Failed to submit clarification", async () => {
        await submitTaskClarification(getRuntime(), {
          workspaceId,
          taskId,
          inputRequest,
          answers: clarificationAnswers.map((answer, index) => {
            const question = questions[index];
            if (question?.multi_select) {
              return Array.isArray(answer) ? answer : [];
            }
            return typeof answer === "string" ? answer.trim() : "";
          }),
        });
        invalidateTaskDetail(workspaceId, taskId);
      });
    } finally {
      setSubmittingClarification(false);
    }
  }

  async function submitFollowUp(args: {
    description: string;
    followUpConfigAlias?: string;
    followUpMode?: FollowUpModeDto;
  }): Promise<boolean> {
    if (!task || !workspaceId || !taskId) {
      return false;
    }
    const { description, followUpConfigAlias, followUpMode } = args;
    const selectedConfig = resolveFollowUpConfigEntry({
      configEntries,
      task,
      followUpConfigAlias,
    });
    const trimmed = description.trim();
    if (!trimmed) {
      failTaskDetail(
        workspaceId,
        taskId,
        "Follow-up description is required",
      );
      return false;
    }
    setSubmittingFollowUp(true);
    try {
      return await runTaskAction("Failed to start follow-up task", async () => {
        const { tasks: nextTasks, followUpTaskId } =
          await startFollowUpAndReloadTaskList(getRuntime(), {
            workspaceId,
            taskId,
            task,
            description: trimmed,
            followUpMode,
            selectedConfig: selectedConfig
              ? {
                  alias: selectedConfig.alias,
                  configPath: selectedConfig.config_path,
                }
              : undefined,
            existingTaskIds: new Set(tasks.map((entry) => entry.task.id)),
          });
        setTasks(workspaceId, nextTasks);
        if (followUpTaskId) {
          navigate(buildTaskDetailPath(workspaceId, followUpTaskId));
        }
      });
    } finally {
      setSubmittingFollowUp(false);
    }
  }

  async function confirmWorktreeCleanup(): Promise<void> {
    if (!workspaceId || !taskId || !worktreeCleanupInfo?.can_remove) {
      return;
    }
    setSubmittingWorktreeCleanup(true);
    try {
      await runTaskAction("Failed to remove worktree", async () => {
        const result = await cleanupTaskWorktree(getRuntime(), {
          workspace_id: workspaceId,
          task_id: taskId,
        });
        const refreshes = [
          loadDetail({ showLoading: false }),
          loadCleanupInfo({ showLoading: false }),
          loadTaskList(getRuntime(), workspaceId).then((nextTasks) =>
            setTasks(workspaceId, nextTasks),
          ),
        ];
        await Promise.all(refreshes);
        if (result.outcome === "failed") {
          throw new Error(result.info?.message ?? "Failed to remove worktree");
        }
        setWorktreeCleanupDialogOpen(false);
      });
    } finally {
      setSubmittingWorktreeCleanup(false);
    }
  }

  async function openWorktreeCleanupDialog(): Promise<void> {
    if (!workspaceId || !taskId) {
      return;
    }
    if (worktreeCleanupInfo) {
      setWorktreeCleanupDialogOpen(true);
      return;
    }
    setLoadingWorktreeCleanupDialog(true);
    try {
      const info = await loadCleanupInfo();
      if (info) {
        setWorktreeCleanupDialogOpen(true);
      }
    } finally {
      setLoadingWorktreeCleanupDialog(false);
    }
  }

  async function retryNode(nodeRunId: string, force: boolean): Promise<void> {
    if (!workspaceId || !taskId || !nodeRunId) {
      return;
    }
    setRetryingNodeId(nodeRunId);
    try {
      await runTaskAction("Failed to retry node", async () => {
        await retryTaskUntilResumed(getRuntime(), {
          workspaceId,
          taskId,
          nodeRunId,
          force,
          loadDetail: () => loadDetail({ showLoading: false }),
        });
        invalidateTaskDetail(workspaceId, taskId);
      });
    } finally {
      setRetryingNodeId(undefined);
    }
  }

  async function continueBlockedAction(): Promise<void> {
    if (!workspaceId || !taskId) {
      return;
    }
    setContinuingBlocked(true);
    try {
      await runTaskAction("Failed to continue blocked task", async () => {
        await continueBlockedUntilResumed(getRuntime(), {
          workspaceId,
          taskId,
          loadDetail: () => loadDetail({ showLoading: false }),
        });
        invalidateTaskDetail(workspaceId, taskId);
      });
    } finally {
      setContinuingBlocked(false);
    }
  }

  async function recoverRun(nodeRunId: string): Promise<void> {
    if (!workspaceId || !taskId || !nodeRunId) {
      return;
    }
    setRecoveringNodeId(nodeRunId);
    clearTaskDetailIssue(workspaceId, taskId);
    try {
      const result = await recoverStaleTaskRun(getRuntime(), {
        workspace_id: workspaceId,
        task_id: taskId,
        node_run_id: nodeRunId,
      });
      if (result.outcome === "busy") {
        throw new Error(
          "This workspace already has an active runtime. Wait for it to settle before recovering this run.",
        );
      }
      const detail = await loadDetail({ showLoading: false });
      if (!detail) {
        throw new Error("Failed to refresh task detail after recovery");
      }
      if (result.outcome === "still_open") {
        throw new Error(
          "Recovery did not resolve this run yet. Refresh again shortly.",
        );
      }
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "Failed to recover run";
      failTaskDetail(workspaceId, taskId, message);
    } finally {
      setRecoveringNodeId(undefined);
    }
  }

  return {
    submittingDecision,
    submittingClarification,
    submittingFollowUp,
    worktreeCleanupDialogOpen,
    loadingWorktreeCleanupDialog,
    submittingWorktreeCleanup,
    submittingRetry: Boolean(retryingNodeId),
    submittingContinue: continuingBlocked,
    submittingRecovery: Boolean(recoveringNodeId),
    submitApprove: (feedback: string) => submitDecision(true, feedback),
    submitReject: (feedback: string) => submitDecision(false, feedback),
    submitClarification,
    submitFollowUp,
    openWorktreeCleanupDialog,
    closeWorktreeCleanupDialog: () => setWorktreeCleanupDialogOpen(false),
    confirmWorktreeCleanup,
    retryTask: (force = false) =>
      latestFailedRunId ? retryNode(latestFailedRunId, force) : Promise.resolve(),
    continueBlockedTask: continueBlockedAction,
    recoverRun,
  };
}
