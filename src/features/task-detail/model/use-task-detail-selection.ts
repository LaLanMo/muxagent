import { useEffect, useMemo, useState } from "react";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";

export type TaskDetailSelection =
  | { kind: "overview" }
  | { kind: "run"; runId: string }
  | { kind: "artifact"; artifactPath: string };

function isMarkerOnlyRun(run: NodeRunViewDto) {
  const name = run.node_name.trim().toLowerCase();
  return (
    name === "done" &&
    !run.failure_reason &&
    !run.session_id &&
    !run.clarifications?.length &&
    !run.artifact_paths?.length &&
    (!run.result || Object.keys(run.result).length === 0)
  );
}

function findBlockedRun(
  runs: NodeRunViewDto[],
  blockedStep?: BlockedStepDto,
): NodeRunViewDto | undefined {
  if (!blockedStep) {
    return undefined;
  }
  return [...runs]
    .reverse()
    .find((run) => run.node_name === blockedStep.node_name);
}

function isActiveRunStatus(status: string) {
  const normalized = status.toLowerCase();
  return normalized.includes("await") || normalized.includes("run");
}

function buildDefaultSelection(args: {
  runs: NodeRunViewDto[];
  inputRequest?: InputRequestDto;
  blockedStep?: BlockedStepDto;
}): TaskDetailSelection {
  const { runs, inputRequest, blockedStep } = args;
  const actionableRunId = inputRequest?.node_run_id;
  if (actionableRunId && runs.some((run) => run.id === actionableRunId)) {
    return { kind: "run", runId: actionableRunId };
  }

  const blockedRun = findBlockedRun(runs, blockedStep);
  if (blockedRun) {
    return { kind: "run", runId: blockedRun.id };
  }

  const activeRun = [...runs].reverse().find((run) => isActiveRunStatus(run.status));
  if (activeRun) {
    return { kind: "run", runId: activeRun.id };
  }

  const failedRun = [...runs]
    .reverse()
    .find((run) => run.status.toLowerCase().includes("fail"));
  if (failedRun) {
    return { kind: "run", runId: failedRun.id };
  }

  const latestCompleted = [...runs].reverse()[0];
  if (latestCompleted) {
    return { kind: "run", runId: latestCompleted.id };
  }

  return { kind: "overview" };
}

export function useTaskDetailSelection({
  taskId,
  task,
  artifacts,
  inputRequest,
  blockedStep,
}: {
  taskId: string;
  task?: TaskViewDto;
  artifacts: ArtifactRefDto[];
  inputRequest?: InputRequestDto;
  blockedStep?: BlockedStepDto;
}) {
  const navigatorRuns = useMemo(
    () => (task?.node_runs ?? []).filter((run) => !isMarkerOnlyRun(run)),
    [task],
  );
  const [selection, setSelection] = useState<TaskDetailSelection>({
    kind: "overview",
  });

  useEffect(() => {
    setSelection((current) => {
      if (!taskId) {
        return { kind: "overview" };
      }
      if (
        current.kind === "run" &&
        navigatorRuns.some((run) => run.id === current.runId)
      ) {
        return current;
      }
      if (
        current.kind === "artifact" &&
        artifacts.some((artifact) => artifact.resolved_path === current.artifactPath)
      ) {
        return current;
      }
      return buildDefaultSelection({
        runs: navigatorRuns,
        inputRequest,
        blockedStep,
      });
    });
  }, [artifacts, blockedStep, inputRequest, navigatorRuns, taskId]);

  const selectedArtifact =
    selection.kind === "artifact"
      ? artifacts.find(
          (artifact) => artifact.resolved_path === selection.artifactPath,
        )
      : undefined;
  const selectedRunId =
    selection.kind === "run"
      ? selection.runId
      : selectedArtifact?.node_run_id;
  const selectedRun = selectedRunId
    ? navigatorRuns.find((run) => run.id === selectedRunId)
    : undefined;

  return {
    navigatorRuns,
    selection,
    selectedRun,
    selectedArtifact,
    selectOverview: () => setSelection({ kind: "overview" }),
    selectRun: (runId: string) => setSelection({ kind: "run", runId }),
    selectArtifact: (artifact: ArtifactRefDto) =>
      setSelection({
        kind: "artifact",
        artifactPath: artifact.resolved_path,
      }),
  };
}
