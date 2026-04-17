import { useCallback, useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { addWorkspace } from "@/application/workspace";
import { startTask } from "@/application/tasks";
import { rememberConfigAlias } from "@/features/app/model/config-memory";
import { rememberWorkspaceId } from "@/features/app/model/workspace-memory";
import { markOnboardingCompleted } from "@/features/onboarding/model/onboarding-memory";
import { getRuntime } from "@/app/runtime";
import { useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";
import type {
  ConfigCatalogEntryDto,
  RuntimeStatusEntryDto,
  WorkspaceSummaryDto,
} from "@/rpc/types";

export type OnboardingStep = 1 | 2 | 3;

export interface OnboardingRuntimeOption {
  runtimeId: string;
  label: string;
  launcher?: string;
  available: boolean;
}

export interface UseOnboardingResult {
  step: OnboardingStep;
  back: () => void;
  workspacePath: string;
  workspaceName: string;
  setWorkspacePath: (value: string) => void;
  setWorkspaceName: (value: string) => void;
  pickWorkspaceDirectory: () => Promise<void>;
  workspaceAdded?: WorkspaceSummaryDto;
  submitWorkspace: () => Promise<void>;
  runtimeOptions: OnboardingRuntimeOption[];
  selectedRuntimeId?: string;
  setSelectedRuntimeId: (runtimeId: string) => void;
  applyRuntime: () => Promise<void>;
  taskDescription: string;
  setTaskDescription: (value: string) => void;
  startFirstTask: () => Promise<void>;
  finishWithoutTask: () => void;
  skipOnboarding: () => void;
  defaultLaunchableEntry?: ConfigCatalogEntryDto;
  submitting: boolean;
  error?: string;
}

function deriveWorkspaceNameFromPath(path: string): string {
  const trimmed = path.trim().replace(/[/\\]+$/, "");
  if (!trimmed) {
    return "";
  }
  const parts = trimmed.split(/[/\\]/);
  return parts[parts.length - 1] ?? "";
}

function buildRuntimeOptions(
  entries: RuntimeStatusEntryDto[] | undefined,
): OnboardingRuntimeOption[] {
  if (!entries) {
    return [];
  }
  return entries.map((entry) => ({
    runtimeId: entry.runtime_id,
    label: entry.runtime_name || entry.runtime_id,
    launcher: entry.launcher,
    available: entry.available,
  }));
}

function pickInitialRuntime(
  options: OnboardingRuntimeOption[],
  catalogDefaultRuntimeId: string | undefined,
): string | undefined {
  if (options.length === 0) {
    return undefined;
  }
  if (catalogDefaultRuntimeId) {
    const matched = options.find(
      (option) => option.runtimeId === catalogDefaultRuntimeId,
    );
    if (matched) {
      return matched.runtimeId;
    }
  }
  const firstAvailable = options.find((option) => option.available);
  return (firstAvailable ?? options[0])?.runtimeId;
}

function pickFirstLaunchableEntry(
  entries: ConfigCatalogEntryDto[] | undefined,
  defaultAlias: string | undefined,
): ConfigCatalogEntryDto | undefined {
  if (!entries || entries.length === 0) {
    return undefined;
  }
  const launchable = entries.filter((entry) => entry.launchable);
  if (launchable.length === 0) {
    return undefined;
  }
  if (defaultAlias) {
    const matched = launchable.find((entry) => entry.alias === defaultAlias);
    if (matched) {
      return matched;
    }
  }
  return launchable[0];
}

export function useOnboarding(): UseOnboardingResult {
  const navigate = useNavigate();
  const runtimeStatus = useWorkspaceStore((state) => state.runtimeStatus);
  const catalog = useWorkspaceStore((state) => state.catalog);
  const upsertWorkspaceInStore = useWorkspaceStore(
    (state) => state.upsertWorkspace,
  );
  const setSelectedWorkspace = useWorkspaceStore(
    (state) => state.setSelectedWorkspace,
  );
  const setCatalog = useWorkspaceStore((state) => state.setCatalog);
  const setTasks = useTaskSnapshotStore((state) => state.setTasks);

  const runtimeOptions = useMemo(
    () => buildRuntimeOptions(runtimeStatus?.runtimes),
    [runtimeStatus],
  );

  const [step, setStep] = useState<OnboardingStep>(1);
  const [workspacePath, setWorkspacePath] = useState("");
  const [workspaceName, setWorkspaceName] = useState("");
  const [workspaceAdded, setWorkspaceAdded] = useState<
    WorkspaceSummaryDto | undefined
  >(undefined);
  const [selectedRuntimeId, setSelectedRuntimeIdState] = useState<
    string | undefined
  >(() => pickInitialRuntime(runtimeOptions, catalog?.entries?.[0]?.runtime_id));
  const [taskDescription, setTaskDescription] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | undefined>(undefined);

  const setSelectedRuntimeId = useCallback((runtimeId: string) => {
    setSelectedRuntimeIdState(runtimeId);
  }, []);

  useEffect(() => {
    setSelectedRuntimeIdState((current) => {
      if (current && runtimeOptions.some((option) => option.runtimeId === current)) {
        return current;
      }
      return pickInitialRuntime(runtimeOptions, catalog?.entries?.[0]?.runtime_id);
    });
  }, [runtimeOptions, catalog]);

  const updateWorkspacePath = useCallback(
    (value: string) => {
      setWorkspacePath(value);
      const derived = deriveWorkspaceNameFromPath(value);
      setWorkspaceName((current) => (current.trim() ? current : derived));
    },
    [],
  );

  const pickWorkspaceDirectory = useCallback(async () => {
    setError(undefined);
    try {
      const picked = await getRuntime().shell.pickDirectory();
      if (!picked) {
        return;
      }
      updateWorkspacePath(picked);
    } catch (pickError) {
      setError(
        pickError instanceof Error ? pickError.message : "Failed to pick directory",
      );
    }
  }, [updateWorkspacePath]);

  const submitWorkspace = useCallback(async () => {
    const trimmedPath = workspacePath.trim();
    if (!trimmedPath) {
      setError("Workspace path is required");
      return;
    }
    setSubmitting(true);
    setError(undefined);
    try {
      const workspace = await addWorkspace(
        getRuntime(),
        trimmedPath,
        workspaceName.trim() || undefined,
      );
      upsertWorkspaceInStore(workspace);
      setWorkspaceAdded(workspace);
      setStep(2);
    } catch (addError) {
      setError(
        addError instanceof Error ? addError.message : "Failed to add workspace",
      );
    } finally {
      setSubmitting(false);
    }
  }, [workspacePath, workspaceName, upsertWorkspaceInStore]);

  const applyRuntime = useCallback(async () => {
    const runtimeId = selectedRuntimeId?.trim();
    if (!runtimeId) {
      setError("Please choose a runtime");
      return;
    }
    setSubmitting(true);
    setError(undefined);
    try {
      const nextCatalog = await getRuntime().backend.configSetBuiltinRuntimes({
        runtime_id: runtimeId,
      });
      setCatalog(nextCatalog);
      setStep(3);
    } catch (runtimeError) {
      setError(
        runtimeError instanceof Error
          ? runtimeError.message
          : "Failed to update runtime",
      );
    } finally {
      setSubmitting(false);
    }
  }, [selectedRuntimeId, setCatalog]);

  const defaultLaunchableEntry = useMemo(
    () => pickFirstLaunchableEntry(catalog?.entries, catalog?.default_alias),
    [catalog],
  );

  const completeAndNavigate = useCallback(
    (target: string) => {
      markOnboardingCompleted();
      if (workspaceAdded) {
        rememberWorkspaceId(workspaceAdded.workspace_id);
        setSelectedWorkspace(workspaceAdded.workspace_id);
      }
      navigate(target, { replace: true });
    },
    [workspaceAdded, setSelectedWorkspace, navigate],
  );

  const startFirstTask = useCallback(async () => {
    const trimmedDescription = taskDescription.trim();
    if (!trimmedDescription) {
      setError("Please describe your first task");
      return;
    }
    if (!workspaceAdded) {
      setError("Workspace is missing");
      return;
    }
    if (!defaultLaunchableEntry) {
      setError("No launchable config available");
      return;
    }
    setSubmitting(true);
    setError(undefined);
    try {
      await startTask(getRuntime(), {
        workspace_id: workspaceAdded.workspace_id,
        client_command_id: globalThis.crypto?.randomUUID?.() ?? String(Date.now()),
        description: trimmedDescription,
        config_alias: defaultLaunchableEntry.alias,
        config_path: defaultLaunchableEntry.config_path,
        use_worktree: Boolean(
          workspaceAdded.worktree_available && catalog?.default_use_worktree,
        ),
      });
      rememberConfigAlias(defaultLaunchableEntry.alias);
      void getRuntime()
        .backend.taskList(workspaceAdded.workspace_id)
        .then((taskList) => {
          setTasks(workspaceAdded.workspace_id, taskList.tasks);
        })
        .catch(() => undefined);
      completeAndNavigate("/");
    } catch (taskError) {
      setError(
        taskError instanceof Error ? taskError.message : "Failed to start task",
      );
    } finally {
      setSubmitting(false);
    }
  }, [
    taskDescription,
    workspaceAdded,
    defaultLaunchableEntry,
    catalog?.default_use_worktree,
    setTasks,
    completeAndNavigate,
  ]);

  const finishWithoutTask = useCallback(() => {
    completeAndNavigate("/");
  }, [completeAndNavigate]);

  const skipOnboarding = useCallback(() => {
    markOnboardingCompleted();
    navigate("/", { replace: true });
  }, [navigate]);

  const back = useCallback(() => {
    setError(undefined);
    setStep((current) => (current === 1 ? 1 : ((current - 1) as OnboardingStep)));
  }, []);

  return {
    step,
    back,
    workspacePath,
    workspaceName,
    setWorkspacePath: updateWorkspacePath,
    setWorkspaceName,
    pickWorkspaceDirectory,
    workspaceAdded,
    submitWorkspace,
    runtimeOptions,
    selectedRuntimeId,
    setSelectedRuntimeId,
    applyRuntime,
    taskDescription,
    setTaskDescription,
    startFirstTask,
    finishWithoutTask,
    skipOnboarding,
    defaultLaunchableEntry,
    submitting,
    error,
  };
}
