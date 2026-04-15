import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import {
  continueBlockedUntilResumed,
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
  TaskFollowUpDto,
  TaskViewDto,
} from "@/rpc/types";
import { tasksForWorkspace, useTaskSnapshotStore } from "@/state/task-snapshot-store";

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
  followUp: TaskFollowUpDto | undefined;
  configEntries: ConfigCatalogEntryDto[];
  inputRequest: InputRequestDto | undefined;
  latestFailedRunId: string | undefined;
  loadDetail: LoadTaskDetailFn;
};

export function useTaskDetailActions({
  workspaceId,
  taskId,
  task,
  followUp,
  configEntries,
  inputRequest,
  latestFailedRunId,
  loadDetail,
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
  const [feedback, setFeedback] = useState("");
  const [clarificationAnswers, setClarificationAnswers] = useState<
    Array<string | string[]>
  >([]);
  const [submittingDecision, setSubmittingDecision] = useState(false);
  const [submittingClarification, setSubmittingClarification] = useState(false);
  const [followUpDescription, setFollowUpDescription] = useState("");
  const [followUpConfigAlias, setFollowUpConfigAlias] = useState<string | undefined>();
  const [followUpMode, setFollowUpMode] = useState<FollowUpModeDto | undefined>();
  const [submittingFollowUp, setSubmittingFollowUp] = useState(false);
  const [retryingNodeId, setRetryingNodeId] = useState<string | undefined>();
  const [continuingBlocked, setContinuingBlocked] = useState(false);
  const [recoveringNodeId, setRecoveringNodeId] = useState<string | undefined>();
  const tasks = tasksForWorkspace(taskIdsByWorkspaceId, tasksById, workspaceId);

  useEffect(() => {
    setFeedback("");
    setFollowUpDescription("");
    setClarificationAnswers(
      (inputRequest?.questions ?? []).map((question) =>
        question.multi_select ? [] : "",
      ),
    );
  }, [inputRequest?.node_run_id, inputRequest?.questions, taskId]);

  useEffect(() => {
    setFollowUpConfigAlias(undefined);
  }, [taskId, task?.task.config_alias, task?.task.config_path]);

  useEffect(() => {
    if (!followUp) {
      setFollowUpMode(undefined);
      return;
    }
    setFollowUpMode((current) =>
      current && followUp.available_modes.includes(current)
        ? current
        : followUp.default_mode,
    );
  }, [taskId, followUp]);

  async function runTaskAction(
    fallbackMessage: string,
    action: () => Promise<void>,
  ): Promise<void> {
    clearTaskDetailIssue(workspaceId, taskId);
    try {
      await action();
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
    }
  }

  async function submitDecision(approved: boolean): Promise<void> {
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
        setFeedback("");
        invalidateTaskDetail(workspaceId, taskId);
      });
    } finally {
      setSubmittingDecision(false);
    }
  }

  async function submitClarification(): Promise<void> {
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
        setClarificationAnswers(
          questions.map((question) => (question.multi_select ? [] : "")),
        );
        invalidateTaskDetail(workspaceId, taskId);
      });
    } finally {
      setSubmittingClarification(false);
    }
  }

  async function submitFollowUp(): Promise<void> {
    if (!task || !workspaceId || !taskId) {
      return;
    }
    const selectedConfig = resolveFollowUpConfigEntry({
      configEntries,
      task,
      followUpConfigAlias,
    });
    const trimmed = followUpDescription.trim();
    if (!trimmed) {
      failTaskDetail(
        workspaceId,
        taskId,
        "Follow-up description is required",
      );
      return;
    }
    setSubmittingFollowUp(true);
    try {
      await runTaskAction("Failed to start follow-up task", async () => {
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
        setFollowUpDescription("");
        if (followUpTaskId) {
          navigate(buildTaskDetailPath(workspaceId, followUpTaskId));
        }
      });
    } finally {
      setSubmittingFollowUp(false);
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
    feedback,
    setFeedback,
    clarificationAnswers,
    setClarificationAnswer: (index: number, value: string | string[]) =>
      setClarificationAnswers((current) =>
        current.map((entry, entryIndex) =>
          entryIndex === index ? value : entry,
        ),
      ),
    submittingDecision,
    submittingClarification,
    followUpDescription,
    setFollowUpDescription,
    followUpConfigAlias,
    setFollowUpConfigAlias,
    followUpMode,
    setFollowUpMode,
    submittingFollowUp,
    submittingRetry: Boolean(retryingNodeId),
    submittingContinue: continuingBlocked,
    submittingRecovery: Boolean(recoveringNodeId),
    submitApprove: () => submitDecision(true),
    submitReject: () => submitDecision(false),
    submitClarification,
    submitFollowUp,
    retryTask: (force = false) =>
      latestFailedRunId ? retryNode(latestFailedRunId, force) : Promise.resolve(),
    continueBlockedTask: continueBlockedAction,
    recoverRun,
  };
}
