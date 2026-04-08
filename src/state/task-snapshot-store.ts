import { create } from "zustand";
import { mergeStreamLines } from "@/application/tasks";
import type {
  ArtifactRefDto,
  ConfigViewDto,
  InputRequestDto,
  TaskRunHistoryResult,
  TaskViewDto,
} from "@/rpc/types";

function sortTasks(tasks: TaskViewDto[]): TaskViewDto[] {
  return [...tasks].sort((left, right) =>
    right.task.updated_at.localeCompare(left.task.updated_at),
  );
}

function reconcileHydratedLiveOutput(
  existingLines: string[],
  hydratedLines: string[],
): string[] {
  if (hydratedLines.length === 0) {
    return [...existingLines];
  }
  if (existingLines.length === 0) {
    return [...hydratedLines];
  }

  const merged = mergeStreamLines(existingLines, hydratedLines);
  if (merged.length < existingLines.length + hydratedLines.length) {
    return merged;
  }
  return [...existingLines];
}

type TasksByWorkspace = Record<string, TaskViewDto[]>;
type OutputByWorkspace = Record<string, Record<string, string[]>>;
type OutputRunIdsByWorkspace = Record<string, Record<string, string | undefined>>;
type TaskDetailsByWorkspace = Record<string, Record<string, TaskDetailCacheEntry>>;

export type RunHistoryCacheEntry = {
  loading: boolean;
  signature?: string;
  result?: TaskRunHistoryResult;
  error?: string;
};

export type TaskDetailCacheEntry = {
  task?: TaskViewDto;
  config?: ConfigViewDto;
  inputRequest?: InputRequestDto;
  artifacts: ArtifactRefDto[];
  liveOutputRunId?: string;
  runHistoryByRunId: Record<string, RunHistoryCacheEntry>;
  loading: boolean;
  stale: boolean;
  error?: string;
};

interface TaskSnapshotState {
  tasksByWorkspaceId: TasksByWorkspace;
  liveOutputByWorkspaceId: OutputByWorkspace;
  liveOutputRunIdsByWorkspaceId: OutputRunIdsByWorkspace;
  taskDetailsByWorkspaceId: TaskDetailsByWorkspace;
  setTasks: (workspaceId: string, tasks: TaskViewDto[]) => void;
  upsertTask: (workspaceId: string, task: TaskViewDto) => void;
  hydrateLiveOutput: (
    workspaceId: string,
    taskId: string,
    taskStatus: string,
    runId: string | undefined,
    lines: string[],
  ) => void;
  appendLiveOutput: (
    workspaceId: string,
    taskId: string,
    runId: string | undefined,
    lines: string[],
  ) => void;
  beginTaskDetailLoad: (workspaceId: string, taskId: string) => void;
  resolveTaskDetail: (
    workspaceId: string,
    taskId: string,
    detail: {
      task: TaskViewDto;
      config?: ConfigViewDto;
      inputRequest?: InputRequestDto;
      artifacts: ArtifactRefDto[];
      liveOutputRunId?: string;
    },
  ) => void;
  beginRunHistoryLoad: (
    workspaceId: string,
    taskId: string,
    nodeRunId: string,
    signature: string,
  ) => void;
  resolveRunHistory: (
    workspaceId: string,
    taskId: string,
    nodeRunId: string,
    signature: string,
    result: TaskRunHistoryResult,
  ) => void;
  failRunHistory: (
    workspaceId: string,
    taskId: string,
    nodeRunId: string,
    signature: string,
    error: string,
  ) => void;
  failTaskDetail: (
    workspaceId: string,
    taskId: string,
    error: string,
  ) => void;
  clearTaskDetailIssue: (workspaceId: string, taskId: string) => void;
  invalidateTaskDetail: (workspaceId: string, taskId: string) => void;
  resetWorkspace: (workspaceId: string) => void;
  reset: () => void;
}

function updateTaskDetailEntry(
  state: TaskSnapshotState,
  workspaceId: string,
  taskId: string,
  updater: (current?: TaskDetailCacheEntry) => TaskDetailCacheEntry,
): TaskDetailsByWorkspace {
  const workspaceDetails = state.taskDetailsByWorkspaceId[workspaceId] ?? {};
  return {
    ...state.taskDetailsByWorkspaceId,
    [workspaceId]: {
      ...workspaceDetails,
      [taskId]: updater(workspaceDetails[taskId]),
    },
  };
}

export const useTaskSnapshotStore = create<TaskSnapshotState>((set) => ({
  tasksByWorkspaceId: {},
  liveOutputByWorkspaceId: {},
  liveOutputRunIdsByWorkspaceId: {},
  taskDetailsByWorkspaceId: {},
  setTasks: (workspaceId, tasks) =>
    set((state) => ({
      tasksByWorkspaceId: {
        ...state.tasksByWorkspaceId,
        [workspaceId]: sortTasks(tasks),
      },
    })),
  upsertTask: (workspaceId, task) =>
    set((state) => {
      const existing = state.tasksByWorkspaceId[workspaceId] ?? [];
      const nextTasks = existing.some((entry) => entry.task.id === task.task.id)
        ? existing.map((entry) => (entry.task.id === task.task.id ? task : entry))
        : [...existing, task];
      const workspaceDetails = state.taskDetailsByWorkspaceId[workspaceId];
      return {
        tasksByWorkspaceId: {
          ...state.tasksByWorkspaceId,
          [workspaceId]: sortTasks(nextTasks),
        },
        taskDetailsByWorkspaceId: workspaceDetails?.[task.task.id]
          ? {
              ...state.taskDetailsByWorkspaceId,
              [workspaceId]: {
                ...workspaceDetails,
                [task.task.id]: {
                  ...workspaceDetails[task.task.id],
                  task,
                },
              },
            }
          : state.taskDetailsByWorkspaceId,
      };
    }),
  hydrateLiveOutput: (workspaceId, taskId, taskStatus, runId, lines) =>
    set((state) => {
      const workspaceOutput = state.liveOutputByWorkspaceId[workspaceId] ?? {};
      const workspaceRunIds = state.liveOutputRunIdsByWorkspaceId[workspaceId] ?? {};
      const existingRunId = workspaceRunIds[taskId];
      const existingLines = workspaceOutput[taskId] ?? [];
      const nextLines =
        taskStatus === "running" && runId && existingRunId === runId
          ? reconcileHydratedLiveOutput(existingLines, lines).slice(-120)
          : [...lines].slice(-120);
      return {
        liveOutputByWorkspaceId: {
          ...state.liveOutputByWorkspaceId,
          [workspaceId]: {
            ...workspaceOutput,
            [taskId]: nextLines,
          },
        },
        liveOutputRunIdsByWorkspaceId: {
          ...state.liveOutputRunIdsByWorkspaceId,
          [workspaceId]: {
            ...workspaceRunIds,
            [taskId]: runId,
          },
        },
      };
    }),
  appendLiveOutput: (workspaceId, taskId, runId, lines) =>
    set((state) => {
      const workspaceOutput = state.liveOutputByWorkspaceId[workspaceId] ?? {};
      const workspaceRunIds = state.liveOutputRunIdsByWorkspaceId[workspaceId] ?? {};
      const existingRunId = workspaceRunIds[taskId];
      const reset = Boolean(runId) && runId !== existingRunId;
      const existing = reset ? [] : workspaceOutput[taskId] ?? [];
      const next = lines.length > 0 ? [...existing, ...lines].slice(-120) : existing;
      return {
        liveOutputByWorkspaceId: {
          ...state.liveOutputByWorkspaceId,
          [workspaceId]: {
            ...workspaceOutput,
            [taskId]: next,
          },
        },
        liveOutputRunIdsByWorkspaceId: {
          ...state.liveOutputRunIdsByWorkspaceId,
          [workspaceId]: {
            ...workspaceRunIds,
            [taskId]: runId,
          },
        },
      };
    }),
  beginTaskDetailLoad: (workspaceId, taskId) =>
    set((state) => ({
      taskDetailsByWorkspaceId: updateTaskDetailEntry(
        state,
        workspaceId,
        taskId,
        (current) => ({
          task: current?.task,
          config: current?.config,
          inputRequest: current?.inputRequest,
          artifacts: current?.artifacts ?? [],
          liveOutputRunId: current?.liveOutputRunId,
          runHistoryByRunId: current?.runHistoryByRunId ?? {},
          loading: true,
          stale: false,
          error: undefined,
        }),
      ),
    })),
  resolveTaskDetail: (workspaceId, taskId, detail) =>
    set((state) => ({
      taskDetailsByWorkspaceId: updateTaskDetailEntry(
        state,
        workspaceId,
        taskId,
        () => ({
          task: detail.task,
          config: detail.config,
          inputRequest: detail.inputRequest,
          artifacts: detail.artifacts,
          liveOutputRunId: detail.liveOutputRunId,
          runHistoryByRunId: state.taskDetailsByWorkspaceId[workspaceId]?.[taskId]
            ?.runHistoryByRunId ?? {},
          loading: false,
          stale: false,
          error: undefined,
        }),
      ),
    })),
  beginRunHistoryLoad: (workspaceId, taskId, nodeRunId, signature) =>
    set((state) => ({
      taskDetailsByWorkspaceId: updateTaskDetailEntry(
        state,
        workspaceId,
        taskId,
        (current) => ({
          task: current?.task,
          config: current?.config,
          inputRequest: current?.inputRequest,
          artifacts: current?.artifacts ?? [],
          liveOutputRunId: current?.liveOutputRunId,
          runHistoryByRunId: {
            ...(current?.runHistoryByRunId ?? {}),
            [nodeRunId]: {
              loading: true,
              signature,
              result: current?.runHistoryByRunId?.[nodeRunId]?.result,
              error: undefined,
            },
          },
          loading: current?.loading ?? false,
          stale: current?.stale ?? false,
          error: current?.error,
        }),
      ),
    })),
  resolveRunHistory: (workspaceId, taskId, nodeRunId, signature, result) =>
    set((state) => ({
      taskDetailsByWorkspaceId: updateTaskDetailEntry(
        state,
        workspaceId,
        taskId,
        (current) => ({
          task: current?.task,
          config: current?.config,
          inputRequest: current?.inputRequest,
          artifacts: current?.artifacts ?? [],
          liveOutputRunId: current?.liveOutputRunId,
          runHistoryByRunId: {
            ...(current?.runHistoryByRunId ?? {}),
            [nodeRunId]: {
              loading: false,
              signature,
              result,
              error: undefined,
            },
          },
          loading: current?.loading ?? false,
          stale: current?.stale ?? false,
          error: current?.error,
        }),
      ),
    })),
  failRunHistory: (workspaceId, taskId, nodeRunId, signature, error) =>
    set((state) => ({
      taskDetailsByWorkspaceId: updateTaskDetailEntry(
        state,
        workspaceId,
        taskId,
        (current) => ({
          task: current?.task,
          config: current?.config,
          inputRequest: current?.inputRequest,
          artifacts: current?.artifacts ?? [],
          liveOutputRunId: current?.liveOutputRunId,
          runHistoryByRunId: {
            ...(current?.runHistoryByRunId ?? {}),
            [nodeRunId]: {
              loading: false,
              signature,
              result: current?.runHistoryByRunId?.[nodeRunId]?.result,
              error,
            },
          },
          loading: current?.loading ?? false,
          stale: current?.stale ?? false,
          error: current?.error,
        }),
      ),
    })),
  failTaskDetail: (workspaceId, taskId, error) =>
    set((state) => ({
      taskDetailsByWorkspaceId: updateTaskDetailEntry(
        state,
        workspaceId,
        taskId,
        (current) => ({
          task: current?.task,
          config: current?.config,
          inputRequest: current?.inputRequest,
          artifacts: current?.artifacts ?? [],
          liveOutputRunId: current?.liveOutputRunId,
          runHistoryByRunId: current?.runHistoryByRunId ?? {},
          loading: false,
          stale: false,
          error,
        }),
      ),
    })),
  clearTaskDetailIssue: (workspaceId, taskId) =>
    set((state) => ({
      taskDetailsByWorkspaceId: updateTaskDetailEntry(
        state,
        workspaceId,
        taskId,
        (current) => ({
          task: current?.task,
          config: current?.config,
          inputRequest: current?.inputRequest,
          artifacts: current?.artifacts ?? [],
          liveOutputRunId: current?.liveOutputRunId,
          runHistoryByRunId: current?.runHistoryByRunId ?? {},
          loading: current?.loading ?? false,
          stale: current?.stale ?? false,
          error: undefined,
        }),
      ),
    })),
  invalidateTaskDetail: (workspaceId, taskId) =>
    set((state) => ({
      taskDetailsByWorkspaceId: updateTaskDetailEntry(
        state,
        workspaceId,
        taskId,
        (current) => ({
          task: current?.task,
          config: current?.config,
          inputRequest: current?.inputRequest,
          artifacts: current?.artifacts ?? [],
          liveOutputRunId: current?.liveOutputRunId,
          runHistoryByRunId: current?.runHistoryByRunId ?? {},
          loading: current?.loading ?? false,
          stale: true,
          error: undefined,
        }),
      ),
    })),
  resetWorkspace: (workspaceId) =>
    set((state) => {
      const { [workspaceId]: _tasks, ...tasksByWorkspaceId } =
        state.tasksByWorkspaceId;
      const { [workspaceId]: _output, ...liveOutputByWorkspaceId } =
        state.liveOutputByWorkspaceId;
      const { [workspaceId]: _outputRunIds, ...liveOutputRunIdsByWorkspaceId } =
        state.liveOutputRunIdsByWorkspaceId;
      const { [workspaceId]: _details, ...taskDetailsByWorkspaceId } =
        state.taskDetailsByWorkspaceId;
      return {
        tasksByWorkspaceId,
        liveOutputByWorkspaceId,
        liveOutputRunIdsByWorkspaceId,
        taskDetailsByWorkspaceId,
      };
    }),
  reset: () =>
    set({
      tasksByWorkspaceId: {},
      liveOutputByWorkspaceId: {},
      liveOutputRunIdsByWorkspaceId: {},
      taskDetailsByWorkspaceId: {},
    }),
}));
