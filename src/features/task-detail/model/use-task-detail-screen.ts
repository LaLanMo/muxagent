import { useEffect, useEffectEvent, useState } from "react";
import { useParams } from "react-router-dom";
import {
  continueBlockedTask,
  hydrateTaskDetail,
  readArtifactPreview,
  retryTaskNode,
  startFollowUpTask,
  submitTaskInput,
} from "@/application/tasks";
import { getRuntime } from "@/app/runtime";
import {
  buildStageNodes,
  detailModeForTask,
  latestRun,
  stageStatusForNode,
  statusTone,
} from "@/domain/task-shell";
import { useShellChrome } from "@/features/app/model/use-shell-chrome";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  InputRequestDto,
  TaskViewDto,
} from "@/rpc/types";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";

const emptyTasks: never[] = [];
const emptyLiveOutput: string[] = [];

export function useTaskDetailScreen() {
  const shell = useShellChrome();
  const { taskId = "", workspaceId = "" } = useParams();
  const tasks = useTaskSnapshotStore(
    (state) =>
      (workspaceId
        ? state.tasksByWorkspaceId[workspaceId]
        : undefined) ?? emptyTasks,
  );
  const upsertTask = useTaskSnapshotStore((state) => state.upsertTask);
  const setTasks = useTaskSnapshotStore((state) => state.setTasks);
  const liveOutput = useTaskSnapshotStore(
    (state) =>
      (workspaceId
        ? state.liveOutputByWorkspaceId[workspaceId]?.[taskId]
        : undefined) ?? emptyLiveOutput,
  );
  const selectedTask = tasks.find((task) => task.task.id === taskId);

  const [task, setTask] = useState<TaskViewDto | undefined>(selectedTask);
  const [artifacts, setArtifacts] = useState<ArtifactRefDto[]>([]);
  const [inputRequest, setInputRequest] = useState<InputRequestDto | undefined>();
  const [detailError, setDetailError] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [selectedArtifact, setSelectedArtifact] = useState<ArtifactRefDto | undefined>();
  const [artifactContent, setArtifactContent] = useState<string | undefined>();
  const [artifactError, setArtifactError] = useState<string | undefined>();
  const [feedback, setFeedback] = useState("");
  const [submittingDecision, setSubmittingDecision] = useState(false);
  const [followUpDescription, setFollowUpDescription] = useState("");
  const [submittingFollowUp, setSubmittingFollowUp] = useState(false);
  const [retryingNodeId, setRetryingNodeId] = useState<string | undefined>();
  const [continuingBlocked, setContinuingBlocked] = useState(false);

  const hydrate = useEffectEvent(async () => {
    if (!taskId || shell.phase !== "connected" || !workspaceId) {
      return;
    }
    setLoading(true);
    setDetailError(undefined);
    try {
      const detail = await hydrateTaskDetail(getRuntime(), workspaceId, taskId);
      upsertTask(workspaceId, detail.task);
      setTask(detail.task);
      setArtifacts(detail.artifacts);
      setInputRequest(detail.inputRequest);
    } catch (error) {
      setDetailError(
        error instanceof Error ? error.message : "Failed to load task detail",
      );
    } finally {
      setLoading(false);
    }
  });

  useEffect(() => {
    if (!taskId || shell.phase !== "connected") {
      setTask(undefined);
      setArtifacts([]);
      setInputRequest(undefined);
      return;
    }
    void hydrate();
  }, [hydrate, shell.phase, taskId, workspaceId]);

  useEffect(() => {
    setTask(selectedTask);
  }, [selectedTask]);

  useEffect(() => {
    setFeedback("");
    setFollowUpDescription("");
    setSelectedArtifact(undefined);
  }, [taskId]);

  useEffect(() => {
    if (!selectedArtifact) {
      setArtifactContent(undefined);
      setArtifactError(undefined);
      return;
    }
    let cancelled = false;
    setArtifactError(undefined);
    void readArtifactPreview(getRuntime(), selectedArtifact)
      .then((content) => {
        if (!cancelled) {
          setArtifactContent(content);
        }
      })
      .catch((error) => {
        if (!cancelled) {
          setArtifactError(
            error instanceof Error ? error.message : "Failed to read artifact",
          );
        }
      });
    return () => {
      cancelled = true;
    };
  }, [selectedArtifact]);

  useEffect(() => {
    const runtime = getRuntime();
    return runtime.backend.subscribe((notification) => {
      const taskPayload = notification.payload as
        | {
            event?: {
              type?: string;
              task_id?: string;
              task_view?: { task: { id: string } };
            };
          }
        | undefined;
      if (notification.workspace_id !== workspaceId) {
        return;
      }
      const event = taskPayload?.event;
      if (!event) {
        return;
      }
      if (event.task_id !== taskId && event.task_view?.task.id !== taskId) {
        return;
      }
      if (event.type === "node.progress") {
        return;
      }
      void hydrate();
    });
  }, [hydrate, taskId, workspaceId]);

  async function submitDecision(approved: boolean): Promise<void> {
    if (!inputRequest || !taskId || !workspaceId) {
      return;
    }
    setSubmittingDecision(true);
    setDetailError(undefined);
    try {
      await submitTaskInput(getRuntime(), {
        workspace_id: workspaceId,
        client_command_id: globalThis.crypto?.randomUUID?.() ?? String(Date.now()),
        task_id: taskId,
        node_run_id: inputRequest.node_run_id,
        payload: {
          approved,
          ...(feedback.trim() ? { feedback: feedback.trim() } : {}),
        },
      });
      setFeedback("");
      await hydrate();
    } catch (error) {
      setDetailError(
        error instanceof Error ? error.message : "Failed to submit approval",
      );
    } finally {
      setSubmittingDecision(false);
    }
  }

  async function submitFollowUp(): Promise<void> {
    if (!resolvedTask || !workspaceId || !taskId) {
      return;
    }
    const trimmed = followUpDescription.trim();
    if (!trimmed) {
      setDetailError("Follow-up description is required");
      return;
    }
    setSubmittingFollowUp(true);
    setDetailError(undefined);
    try {
      await startFollowUpTask(getRuntime(), {
        workspace_id: workspaceId,
        client_command_id: globalThis.crypto?.randomUUID?.() ?? String(Date.now()),
        parent_task_id: taskId,
        description: trimmed,
        config_alias: resolvedTask.task.config_alias,
        config_path: resolvedTask.task.config_path,
      });
      const taskList = await getRuntime().backend.taskList(workspaceId);
      setTasks(workspaceId, taskList.tasks);
      setFollowUpDescription("");
    } catch (error) {
      setDetailError(
        error instanceof Error ? error.message : "Failed to start follow-up task",
      );
    } finally {
      setSubmittingFollowUp(false);
    }
  }

  async function retryNode(nodeRunId: string, force: boolean): Promise<void> {
    if (!workspaceId || !taskId || !nodeRunId) {
      return;
    }
    setRetryingNodeId(nodeRunId);
    setDetailError(undefined);
    try {
      await retryTaskNode(getRuntime(), {
        workspace_id: workspaceId,
        client_command_id: globalThis.crypto?.randomUUID?.() ?? String(Date.now()),
        task_id: taskId,
        node_run_id: nodeRunId,
        force,
      });
      await hydrate();
    } catch (error) {
      setDetailError(
        error instanceof Error ? error.message : "Failed to retry node",
      );
    } finally {
      setRetryingNodeId(undefined);
    }
  }

  async function continueBlocked(): Promise<void> {
    if (!workspaceId || !taskId) {
      return;
    }
    setContinuingBlocked(true);
    setDetailError(undefined);
    try {
      await continueBlockedTask(getRuntime(), {
        workspace_id: workspaceId,
        client_command_id: globalThis.crypto?.randomUUID?.() ?? String(Date.now()),
        task_id: taskId,
      });
      await hydrate();
    } catch (error) {
      setDetailError(
        error instanceof Error ? error.message : "Failed to continue blocked task",
      );
    } finally {
      setContinuingBlocked(false);
    }
  }

  const resolvedTask = task ?? selectedTask;
  const detailMode = resolvedTask
    ? detailModeForTask({
        task: resolvedTask,
        inputRequest,
        selectedArtifact,
      })
    : "live";

  const stageNodes = resolvedTask ? buildStageNodes(resolvedTask) : [];
  const latest = resolvedTask ? latestRun(resolvedTask) : undefined;
  const latestFailedRun = resolvedTask
    ? [...(resolvedTask.node_runs ?? [])]
        .reverse()
        .find((run) => run.status.toLowerCase().includes("fail"))
    : undefined;
  const latestBlockedStep = resolvedTask?.blocked_steps?.at(-1) as
    | BlockedStepDto
    | undefined;
  const failureReason =
    latestFailedRun?.failure_reason || resolvedTask?.current_issue?.reason || undefined;

  return {
    shell,
    workspaceId,
    taskId,
    task: resolvedTask,
    loading,
    detailError,
    selectedArtifact,
    artifactContent,
    artifactError,
    artifacts,
    inputRequest,
    liveOutput,
    feedback,
    setFeedback,
    submittingDecision,
    followUpDescription,
    setFollowUpDescription,
    submittingFollowUp,
    submittingRetry: Boolean(retryingNodeId),
    submittingContinue: continuingBlocked,
    blockedStep: latestBlockedStep,
    failureReason,
    detailMode,
    stageNodes: resolvedTask
      ? stageNodes.map((node) => ({
          name: node,
          status: stageStatusForNode(resolvedTask, node),
        }))
      : [],
    title: resolvedTask?.task.description || resolvedTask?.task.id || "Task detail",
    statusLabel: resolvedTask?.status || "running",
    statusTone: resolvedTask ? statusTone(resolvedTask.status) : "neutral",
    configLabel: resolvedTask?.task.config_alias || "default",
    elapsedLabel: latest?.started_at ? latest.started_at : "",
    timelineRuns: resolvedTask?.node_runs ?? [],
    latestRun: latest,
    selectArtifact: (artifact: ArtifactRefDto) => setSelectedArtifact(artifact),
    clearArtifact: () => setSelectedArtifact(undefined),
    submitApprove: () => submitDecision(true),
    submitReject: () => submitDecision(false),
    submitFollowUp,
    retryTask: (force = false) =>
      latestFailedRun ? retryNode(latestFailedRun.id, force) : Promise.resolve(),
    continueBlockedTask: continueBlocked,
  };
}
