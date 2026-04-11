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

export type TaskDetailModal =
  | { kind: "none" }
  | { kind: "transcript"; runId: string }
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

function readModalFromSearchParams(
  searchParams: URLSearchParams,
): TaskDetailModal | undefined {
  const modal = searchParams.get("modal");
  if (modal === "transcript") {
    const runId = searchParams.get("run");
    if (runId) {
      return { kind: "transcript", runId };
    }
  }

  if (modal === "artifact") {
    const artifactPath = searchParams.get("artifact");
    if (artifactPath) {
      return { kind: "artifact", artifactPath };
    }
  }

  return undefined;
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

function modalsMatch(
  left: TaskDetailModal | undefined,
  right: TaskDetailModal,
) {
  if (!left || left.kind !== right.kind) {
    return false;
  }
  if (left.kind === "none") {
    return true;
  }
  if (left.kind === "transcript" && right.kind === "transcript") {
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
  const requestedModal = useMemo(
    () => readModalFromSearchParams(searchParams),
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

  const modal = useMemo(() => {
    if (
      requestedModal?.kind === "artifact" &&
      artifacts.some(
        (artifact) => artifact.resolved_path === requestedModal.artifactPath,
      )
    ) {
      return requestedModal;
    }

    if (
      requestedModal?.kind === "transcript" &&
      navigatorRuns.some((run) => run.id === requestedModal.runId)
    ) {
      return requestedModal;
    }

    return { kind: "none" } satisfies TaskDetailModal;
  }, [artifacts, navigatorRuns, requestedModal]);

  useEffect(() => {
    if (!requestedSelection || selectionsMatch(requestedSelection, selection)) {
      return;
    }
    const next = writeSelectionToSearchParams(searchParams, selection);
    next.delete("modal");
    setSearchParams(next, { replace: true });
  }, [requestedSelection, searchParams, selection, setSearchParams]);

  useEffect(() => {
    if (!requestedModal || modalsMatch(requestedModal, modal)) {
      return;
    }
    const next = new URLSearchParams(searchParams);
    next.delete("modal");
    setSearchParams(next, { replace: true });
  }, [modal, requestedModal, searchParams, setSearchParams]);

  const activeArtifactPath =
    selection.kind === "artifact"
      ? selection.artifactPath
      : modal.kind === "artifact"
        ? modal.artifactPath
        : undefined;
  const selectedArtifact = activeArtifactPath
    ? artifacts.find((artifact) => artifact.resolved_path === activeArtifactPath)
    : undefined;
  const selectedRunId =
    selection.kind === "run"
      ? selection.runId
      : selectedArtifact?.node_run_id ??
        (modal.kind === "transcript" ? modal.runId : undefined);
  const selectedRun = selectedRunId
    ? navigatorRuns.find((run) => run.id === selectedRunId)
    : undefined;

  return {
    navigatorRuns,
    selection,
    modal,
    selectedRun,
    selectedArtifact,
    selectOverview: () =>
      setSearchParams(
        (current) => {
          const next = writeSelectionToSearchParams(current, {
            kind: "overview",
          });
          next.delete("modal");
          return next;
        },
        { replace: false },
      ),
    selectRun: (runId: string) =>
      setSearchParams(
        (current) => {
          const next = writeSelectionToSearchParams(current, {
            kind: "run",
            runId,
          });
          next.delete("modal");
          return next;
        },
        { replace: false },
      ),
    selectArtifact: (artifact: ArtifactRefDto) =>
      setSearchParams(
        (current) => {
          const next = writeSelectionToSearchParams(current, {
            kind: "artifact",
            artifactPath: artifact.resolved_path,
          });
          next.delete("modal");
          return next;
        },
        { replace: false },
      ),
    openTranscript: (runId: string) =>
      setSearchParams(
        (current) => {
          const next = writeSelectionToSearchParams(current, {
            kind: "run",
            runId,
          });
          next.set("modal", "transcript");
          return next;
        },
        { replace: false },
      ),
    openArtifact: (artifact: ArtifactRefDto) =>
      setSearchParams(
        (current) => {
          const next = writeSelectionToSearchParams(current, {
            kind: "artifact",
            artifactPath: artifact.resolved_path,
          });
          next.set("modal", "artifact");
          return next;
        },
        { replace: false },
      ),
  };
}
