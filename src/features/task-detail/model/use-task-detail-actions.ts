import { useEffect, useState } from "react";
import {
  continueBlockedUntilResumed,
  retryTaskNodeAction,
  startFollowUpAndReloadTaskList,
  submitTaskApproval,
  submitTaskClarification,
} from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import type { LoadTaskDetailFn } from "@/features/task-detail/model/use-task-detail-data";
import type {
  InputRequestDto,
  TaskViewDto,
} from "@/rpc/types";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";

type UseTaskDetailActionsArgs = {
  workspaceId: string;
  taskId: string;
  task: TaskViewDto | undefined;
  inputRequest: InputRequestDto | undefined;
  latestFailedRunId: string | undefined;
  loadDetail: LoadTaskDetailFn;
};

export function useTaskDetailActions({
  workspaceId,
  taskId,
  task,
  inputRequest,
  latestFailedRunId,
  loadDetail,
}: UseTaskDetailActionsArgs) {
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
  const [submittingFollowUp, setSubmittingFollowUp] = useState(false);
  const [retryingNodeId, setRetryingNodeId] = useState<string | undefined>();
  const [continuingBlocked, setContinuingBlocked] = useState(false);

  useEffect(() => {
    setFeedback("");
    setFollowUpDescription("");
    setClarificationAnswers(
      (inputRequest?.questions ?? []).map((question) =>
        question.multi_select ? [] : "",
      ),
    );
  }, [inputRequest?.node_run_id, inputRequest?.questions, taskId]);

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
        setTasks(
          workspaceId,
          await startFollowUpAndReloadTaskList(getRuntime(), {
            workspaceId,
            taskId,
            task,
            description: trimmed,
            configAliasOverride: followUpConfigAlias,
          }),
        );
        setFollowUpDescription("");
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
        await retryTaskNodeAction(getRuntime(), {
          workspaceId,
          taskId,
          nodeRunId,
          force,
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
    submittingFollowUp,
    submittingRetry: Boolean(retryingNodeId),
    submittingContinue: continuingBlocked,
    submitApprove: () => submitDecision(true),
    submitReject: () => submitDecision(false),
    submitClarification,
    submitFollowUp,
    retryTask: (force = false) =>
      latestFailedRunId ? retryNode(latestFailedRunId, force) : Promise.resolve(),
    continueBlockedTask: continueBlockedAction,
  };
}
