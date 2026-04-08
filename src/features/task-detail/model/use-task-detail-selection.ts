import { useEffect, useMemo } from "react";
import { useSearchParams } from "react-router-dom";
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

function readSelectionFromSearchParams(
  searchParams: URLSearchParams,
): TaskDetailSelection | undefined {
  const artifactPath = searchParams.get("artifact");
  if (artifactPath) {
    return { kind: "artifact", artifactPath };
  }

  const runId = searchParams.get("run");
  if (runId) {
    return { kind: "run", runId };
  }

  if (searchParams.get("view") === "overview") {
    return { kind: "overview" };
  }

  return undefined;
}

function writeSelectionToSearchParams(
  current: URLSearchParams,
  selection?: TaskDetailSelection,
): URLSearchParams {
  const next = new URLSearchParams(current);
  next.delete("view");
  next.delete("run");
  next.delete("artifact");

  if (!selection) {
    return next;
  }

  if (selection.kind === "overview") {
    next.set("view", "overview");
  } else if (selection.kind === "run") {
    next.set("run", selection.runId);
  } else {
    next.set("artifact", selection.artifactPath);
  }

  return next;
}

function selectionsMatch(
  left: TaskDetailSelection | undefined,
  right: TaskDetailSelection,
) {
  if (!left || left.kind !== right.kind) {
    return false;
  }
  if (left.kind === "overview") {
    return true;
  }
  if (left.kind === "run" && right.kind === "run") {
    return left.runId === right.runId;
  }
  if (left.kind === "artifact" && right.kind === "artifact") {
    return left.artifactPath === right.artifactPath;
  }
  return false;
}

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
  const [searchParams, setSearchParams] = useSearchParams();
  const navigatorRuns = useMemo(
    () => (task?.node_runs ?? []).filter((run) => !isMarkerOnlyRun(run)),
    [task],
  );
  const requestedSelection = useMemo(
    () => readSelectionFromSearchParams(searchParams),
    [searchParams],
  );
  const selection = useMemo(() => {
    if (!taskId) {
      return { kind: "overview" } satisfies TaskDetailSelection;
    }

    if (
      requestedSelection?.kind === "run" &&
      navigatorRuns.some((run) => run.id === requestedSelection.runId)
    ) {
      return requestedSelection;
    }

    if (
      requestedSelection?.kind === "artifact" &&
      artifacts.some(
        (artifact) => artifact.resolved_path === requestedSelection.artifactPath,
      )
    ) {
      return requestedSelection;
    }

    if (requestedSelection?.kind === "overview") {
      return requestedSelection;
    }

    return buildDefaultSelection({
      runs: navigatorRuns,
      inputRequest,
      blockedStep,
    });
  }, [artifacts, blockedStep, inputRequest, navigatorRuns, requestedSelection, taskId]);

  useEffect(() => {
    if (!requestedSelection || selectionsMatch(requestedSelection, selection)) {
      return;
    }
    setSearchParams(writeSelectionToSearchParams(searchParams), { replace: true });
  }, [requestedSelection, searchParams, selection, setSearchParams]);

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
    selectOverview: () =>
      setSearchParams(
        (current) =>
          writeSelectionToSearchParams(current, {
            kind: "overview",
          }),
        { replace: false },
      ),
    selectRun: (runId: string) =>
      setSearchParams(
        (current) =>
          writeSelectionToSearchParams(current, {
            kind: "run",
            runId,
          }),
        { replace: false },
      ),
    selectArtifact: (artifact: ArtifactRefDto) =>
      setSearchParams(
        (current) =>
          writeSelectionToSearchParams(current, {
            kind: "artifact",
            artifactPath: artifact.resolved_path,
          }),
        { replace: false },
      ),
  };
}
