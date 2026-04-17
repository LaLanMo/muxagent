import { useEffect, useEffectEvent, useMemo, useState } from "react";
import {
  getWorkspaceCheckoutStatus,
  getWorkspaceGitStatus,
} from "@/application/source-control";
import { getRuntime } from "@/app/runtime";
import { useShellModel } from "@/features/app/model/use-shell-model";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import {
  buildCheckoutSummaryLabel,
  buildCommitSection,
  buildFileSections,
  buildTaskSummaryForCheckout,
  pickPreferredCheckoutPath,
  type SourceControlCommitSection,
  type SourceControlFileSection,
  type SourceControlTaskSummary,
} from "@/features/source-control/model/source-control-presenter";
import { tasksForWorkspace, useTaskSnapshotStore } from "@/state/task-snapshot-store";
import { useWorkspaceStore } from "@/state/workspace-store";
import type {
  GitCheckoutDetailDto,
  GitCheckoutSummaryDto,
  WorkspaceGitStatusResult,
} from "@/rpc/types";

type CheckoutDetailCacheEntry = {
  loading: boolean;
  data?: GitCheckoutDetailDto;
  error?: string;
};

export type SourceControlCheckoutItemModel = {
  path: string;
  label: string;
  role: GitCheckoutSummaryDto["role"];
  summary: string;
  reachable: boolean;
  locked?: boolean;
  prunable?: boolean;
  selected: boolean;
  expanded: boolean;
  taskSummary: SourceControlTaskSummary;
  changeCount: number;
};

export type SourceControlScreenModel = {
  shell: ShellChromeModel;
  phase: "idle" | "connecting" | "connected" | "failed";
  workspaceLabel: string;
  workspacePath?: string;
  workspaceOptions: Array<{
    id: string;
    label: string;
  }>;
  workspacePickerOpen: boolean;
  setWorkspacePickerOpen: (open: boolean) => void;
  onSelectWorkspace: (workspaceId: string) => void;
  onRefresh: () => void;
  loading: boolean;
  error?: string;
  checkoutItems: SourceControlCheckoutItemModel[];
  selectedCheckoutPath?: string;
  onSelectCheckout: (checkoutPath: string) => void;
  selectedCheckout?: GitCheckoutSummaryDto;
  selectedCheckoutDetail?: GitCheckoutDetailDto;
  selectedCheckoutLoading: boolean;
  selectedCheckoutError?: string;
  taskSummary?: SourceControlTaskSummary;
  fileSections: SourceControlFileSection[];
  selectedFileId?: string;
  onSelectFile: (fileId?: string) => void;
  selectedFile?: {
    id: string;
    path: string;
    origPath?: string;
    bucket: string;
    statusCode: string;
  };
  commitSection?: SourceControlCommitSection;
  worktreesTruncated: boolean;
};

export function useSourceControlScreen(): SourceControlScreenModel {
  const shell = useShellModel();
  const { selectWorkspaceById } = useWorkspaceSelection();

  const phase = useWorkspaceStore((state) => state.phase);
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const selectedWorkspaceId = useWorkspaceStore((state) => state.selectedWorkspaceId);
  const shellError = useWorkspaceStore((state) => state.error);
  const tasksById = useTaskSnapshotStore((state) => state.tasksById);
  const taskIdsByWorkspaceId = useTaskSnapshotStore((state) => state.taskIdsByWorkspaceId);

  const activeWorkspace =
    workspaces.find((workspace) => workspace.workspace_id === selectedWorkspaceId) ??
    workspaces[0];
  const activeWorkspaceId = activeWorkspace?.workspace_id;
  const workspaceTasks = activeWorkspaceId
    ? tasksForWorkspace(taskIdsByWorkspaceId, tasksById, activeWorkspaceId)
    : [];

  const [workspacePickerOpen, setWorkspacePickerOpen] = useState(false);
  const [statusResult, setStatusResult] = useState<WorkspaceGitStatusResult>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string>();
  const [selectedCheckoutPath, setSelectedCheckoutPath] = useState<string>();
  const [detailByPath, setDetailByPath] = useState<Record<string, CheckoutDetailCacheEntry>>({});
  const [selectedFileId, setSelectedFileId] = useState<string>();
  const [refreshNonce, setRefreshNonce] = useState(0);

  const checkouts = useMemo(() => {
    if (!statusResult) {
      return [];
    }
    return [statusResult.main, ...statusResult.worktrees];
  }, [statusResult]);

  const selectedCheckout = useMemo(
    () => checkouts.find((checkout) => checkout.path === selectedCheckoutPath),
    [checkouts, selectedCheckoutPath],
  );

  const selectedCheckoutDetail = selectedCheckoutPath
    ? detailByPath[selectedCheckoutPath]?.data
    : undefined;
  const selectedCheckoutLoading = selectedCheckoutPath
    ? (detailByPath[selectedCheckoutPath]?.loading ?? false)
    : false;
  const selectedCheckoutError = selectedCheckoutPath
    ? detailByPath[selectedCheckoutPath]?.error
    : undefined;

  const fileSections = useMemo(
    () => (selectedCheckoutDetail ? buildFileSections(selectedCheckoutDetail) : []),
    [selectedCheckoutDetail],
  );

  const selectedFile = useMemo(() => {
    if (!selectedFileId) {
      return undefined;
    }
    return fileSections
      .flatMap((section) => section.rows)
      .find((row) => row.id === selectedFileId);
  }, [fileSections, selectedFileId]);

  const commitSection = useMemo(
    () =>
      selectedCheckout
        ? buildCommitSection(selectedCheckout, selectedCheckoutDetail?.commits ?? [])
        : undefined,
    [selectedCheckout, selectedCheckoutDetail],
  );

  const taskSummary = useMemo(() => {
    if (!activeWorkspaceId || !selectedCheckoutPath) {
      return undefined;
    }
    return buildTaskSummaryForCheckout(
      activeWorkspaceId,
      selectedCheckoutPath,
      workspaceTasks,
    );
  }, [activeWorkspaceId, selectedCheckoutPath, workspaceTasks]);

  useEffect(() => {
    if (selectedFileId && !selectedFile) {
      setSelectedFileId(undefined);
    }
  }, [selectedFile, selectedFileId]);

  const loadStatus = useEffectEvent(async (workspaceId: string) => {
    setLoading(true);
    setError(undefined);
    try {
      const nextStatus = await getWorkspaceGitStatus(getRuntime(), workspaceId);
      setStatusResult(nextStatus);
      setDetailByPath({});
      setSelectedFileId(undefined);
      setSelectedCheckoutPath((current) => {
        if (
          current &&
          [nextStatus.main, ...nextStatus.worktrees].some(
            (checkout) => checkout.path === current,
          )
        ) {
          return current;
        }
        return pickPreferredCheckoutPath(nextStatus.main, nextStatus.worktrees);
      });
    } catch (loadError) {
      setStatusResult(undefined);
      setSelectedCheckoutPath(undefined);
      setDetailByPath({});
      setSelectedFileId(undefined);
      setError(
        loadError instanceof Error ? loadError.message : "Failed to load source control",
      );
    } finally {
      setLoading(false);
    }
  });

  const loadCheckoutDetail = useEffectEvent(
    async (workspaceId: string, checkoutPath: string) => {
      setDetailByPath((current) => ({
        ...current,
        [checkoutPath]: {
          loading: true,
          data: current[checkoutPath]?.data,
        },
      }));

      try {
        const detail = await getWorkspaceCheckoutStatus({
          runtime: getRuntime(),
          workspaceId,
          checkoutPath,
          fileLimit: 200,
        });
        setDetailByPath((current) => ({
          ...current,
          [checkoutPath]: {
            loading: false,
            data: detail.checkout,
          },
        }));
      } catch (loadError) {
        setDetailByPath((current) => ({
          ...current,
          [checkoutPath]: {
            loading: false,
            error:
              loadError instanceof Error
                ? loadError.message
                : "Failed to load checkout details",
          },
        }));
      }
    },
  );

  useEffect(() => {
    if (phase !== "connected" || !activeWorkspaceId) {
      setStatusResult(undefined);
      setDetailByPath({});
      setSelectedCheckoutPath(undefined);
      setSelectedFileId(undefined);
      setLoading(false);
      setError(undefined);
      return;
    }
    void loadStatus(activeWorkspaceId);
  }, [activeWorkspaceId, loadStatus, phase, refreshNonce]);

  useEffect(() => {
    if (!activeWorkspaceId || !selectedCheckoutPath) {
      return;
    }
    const current = detailByPath[selectedCheckoutPath];
    if (current?.loading || current?.data) {
      return;
    }
    void loadCheckoutDetail(activeWorkspaceId, selectedCheckoutPath);
  }, [activeWorkspaceId, detailByPath, loadCheckoutDetail, selectedCheckoutPath]);

  const checkoutItems = useMemo(() => {
    if (!activeWorkspaceId) {
      return [];
    }
    return checkouts.map((checkout) => {
      const summary = buildTaskSummaryForCheckout(
        activeWorkspaceId,
        checkout.path,
        workspaceTasks,
      );
      return {
        path: checkout.path,
        label: checkout.branch || checkout.path.split(/[\\/]/).at(-1) || checkout.path,
        role: checkout.role,
        summary: buildCheckoutSummaryLabel(checkout),
        reachable: checkout.reachable,
        locked: checkout.locked,
        prunable: checkout.prunable,
        selected: checkout.path === selectedCheckoutPath,
        expanded: checkout.path === selectedCheckoutPath,
        taskSummary: summary,
        changeCount: checkout.total_change_count,
      } satisfies SourceControlCheckoutItemModel;
    });
  }, [activeWorkspaceId, checkouts, selectedCheckoutPath, workspaceTasks]);

  const onSelectWorkspace = useEffectEvent((workspaceId: string) => {
    setWorkspacePickerOpen(false);
    if (!workspaceId || workspaceId === activeWorkspaceId) {
      return;
    }
    void selectWorkspaceById(workspaceId);
  });

  return {
    shell,
    phase,
    workspaceLabel: activeWorkspace?.display_name ?? "Select workspace",
    workspacePath: activeWorkspace?.path,
    workspaceOptions: workspaces.map((workspace) => ({
      id: workspace.workspace_id,
      label: workspace.display_name,
    })),
    workspacePickerOpen,
    setWorkspacePickerOpen,
    onSelectWorkspace,
    onRefresh: () => {
      setRefreshNonce((current) => current + 1);
    },
    loading,
    error: error ?? shellError,
    checkoutItems,
    selectedCheckoutPath,
    onSelectCheckout: (checkoutPath) => {
      setSelectedCheckoutPath(checkoutPath);
      setSelectedFileId(undefined);
    },
    selectedCheckout,
    selectedCheckoutDetail,
    selectedCheckoutLoading,
    selectedCheckoutError,
    taskSummary,
    fileSections,
    selectedFileId,
    onSelectFile: setSelectedFileId,
    selectedFile,
    commitSection,
    worktreesTruncated: Boolean(statusResult?.worktrees_truncated),
  };
}
