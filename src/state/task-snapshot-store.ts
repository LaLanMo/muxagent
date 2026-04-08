import { create } from "zustand";
import {
  mergeSessionHistoryEvents,
  type NormalizedTaskRunHistoryResult,
  type SessionHistoryEvent,
} from "@/domain/session-history";
import type {
  ArtifactRefDto,
  ConfigViewDto,
  InputRequestDto,
  TaskViewDto,
} from "@/rpc/types";

function sortTasks(tasks: TaskViewDto[]): TaskViewDto[] {
  return [...tasks].sort((left, right) =>
    right.task.updated_at.localeCompare(left.task.updated_at),
  );
}

function reconcileHydratedLiveEvents(
  existingEvents: SessionHistoryEvent[],
  hydratedEvents: SessionHistoryEvent[],
): SessionHistoryEvent[] {
  if (hydratedEvents.length === 0) {
    return [...existingEvents];
  }
  if (existingEvents.length === 0) {
    return [...hydratedEvents];
  }
  return mergeSessionHistoryEvents(existingEvents, hydratedEvents);
}

type TasksByWorkspace = Record<string, TaskViewDto[]>;
type LiveEventsByWorkspace = Record<string, Record<string, SessionHistoryEvent[]>>;
type LiveEventRunIdsByWorkspace = Record<string, Record<string, string | undefined>>;
type TaskDetailsByWorkspace = Record<string, Record<string, TaskDetailCacheEntry>>;

export type RunHistoryCacheEntry = {
  loading: boolean;
  signature?: string;
  result?: NormalizedTaskRunHistoryResult;
  error?: string;
};

export type TaskDetailCacheEntry = {
  task?: TaskViewDto;
  config?: ConfigViewDto;
  inputRequest?: InputRequestDto;
  artifacts: ArtifactRefDto[];
  liveEventsRunId?: string;
  runHistoryByRunId: Record<string, RunHistoryCacheEntry>;
  loading: boolean;
  stale: boolean;
  error?: string;
};

interface TaskSnapshotState {
  tasksByWorkspaceId: TasksByWorkspace;
  liveEventsByWorkspaceId: LiveEventsByWorkspace;
  liveEventRunIdsByWorkspaceId: LiveEventRunIdsByWorkspace;
  taskDetailsByWorkspaceId: TaskDetailsByWorkspace;
  setTasks: (workspaceId: string, tasks: TaskViewDto[]) => void;
  upsertTask: (workspaceId: string, task: TaskViewDto) => void;
  hydrateLiveEvents: (
    workspaceId: string,
    taskId: string,
    taskStatus: string,
    runId: string | undefined,
    events: SessionHistoryEvent[],
  ) => void;
  appendLiveEvents: (
    workspaceId: string,
    taskId: string,
    runId: string | undefined,
    events: SessionHistoryEvent[],
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
      liveEventsRunId?: string;
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
    result: NormalizedTaskRunHistoryResult,
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
  liveEventsByWorkspaceId: {},
  liveEventRunIdsByWorkspaceId: {},
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
  hydrateLiveEvents: (workspaceId, taskId, taskStatus, runId, events) =>
    set((state) => {
      const workspaceOutput = state.liveEventsByWorkspaceId[workspaceId] ?? {};
      const workspaceRunIds = state.liveEventRunIdsByWorkspaceId[workspaceId] ?? {};
      const existingRunId = workspaceRunIds[taskId];
      const existingEvents = workspaceOutput[taskId] ?? [];
      const nextEvents =
        taskStatus === "running" && runId && existingRunId === runId
          ? reconcileHydratedLiveEvents(existingEvents, events).slice(-200)
          : [...events].slice(-200);
      return {
        liveEventsByWorkspaceId: {
          ...state.liveEventsByWorkspaceId,
          [workspaceId]: {
            ...workspaceOutput,
            [taskId]: nextEvents,
          },
        },
        liveEventRunIdsByWorkspaceId: {
          ...state.liveEventRunIdsByWorkspaceId,
          [workspaceId]: {
            ...workspaceRunIds,
            [taskId]: runId,
          },
        },
      };
    }),
  appendLiveEvents: (workspaceId, taskId, runId, events) =>
    set((state) => {
      const workspaceOutput = state.liveEventsByWorkspaceId[workspaceId] ?? {};
      const workspaceRunIds = state.liveEventRunIdsByWorkspaceId[workspaceId] ?? {};
      const existingRunId = workspaceRunIds[taskId];
      const reset = Boolean(runId) && runId !== existingRunId;
      const existing = reset ? [] : workspaceOutput[taskId] ?? [];
      const next =
        events.length > 0
          ? mergeSessionHistoryEvents(existing, events).slice(-200)
          : existing;
      return {
        liveEventsByWorkspaceId: {
          ...state.liveEventsByWorkspaceId,
          [workspaceId]: {
            ...workspaceOutput,
            [taskId]: next,
          },
        },
        liveEventRunIdsByWorkspaceId: {
          ...state.liveEventRunIdsByWorkspaceId,
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
          liveEventsRunId: current?.liveEventsRunId,
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
          liveEventsRunId: detail.liveEventsRunId,
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
          liveEventsRunId: current?.liveEventsRunId,
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
          liveEventsRunId: current?.liveEventsRunId,
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
          liveEventsRunId: current?.liveEventsRunId,
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
          liveEventsRunId: current?.liveEventsRunId,
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
          liveEventsRunId: current?.liveEventsRunId,
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
          liveEventsRunId: current?.liveEventsRunId,
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
      const { [workspaceId]: _output, ...liveEventsByWorkspaceId } =
        state.liveEventsByWorkspaceId;
      const { [workspaceId]: _outputRunIds, ...liveEventRunIdsByWorkspaceId } =
        state.liveEventRunIdsByWorkspaceId;
      const { [workspaceId]: _details, ...taskDetailsByWorkspaceId } =
        state.taskDetailsByWorkspaceId;
      return {
        tasksByWorkspaceId,
        liveEventsByWorkspaceId,
        liveEventRunIdsByWorkspaceId,
        taskDetailsByWorkspaceId,
      };
    }),
  reset: () =>
    set({
      tasksByWorkspaceId: {},
      liveEventsByWorkspaceId: {},
      liveEventRunIdsByWorkspaceId: {},
      taskDetailsByWorkspaceId: {},
    }),
}));
