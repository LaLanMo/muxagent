import { create } from "zustand";
import {
  mergeSessionHistoryEvents,
  type NormalizedTaskRunHistoryResult,
  type SessionHistoryEvent,
} from "@/domain/session-history";
import { taskEntityId } from "@/domain/task-identity";
import type {
  ArtifactRefDto,
  ConfigViewDto,
  InputRequestDto,
  TaskViewDto,
} from "@/rpc/types";

type TasksById = Record<string, TaskViewDto>;
type TaskIdsByWorkspace = Record<string, string[]>;
type LiveEventsByWorkspace = Record<string, Record<string, SessionHistoryEvent[]>>;
type LiveEventRunIdsByWorkspace = Record<string, Record<string, string | undefined>>;
type TaskDetailsByWorkspace = Record<string, Record<string, TaskDetailCacheEntry>>;

function compareTaskSnapshots(left: TaskViewDto, right: TaskViewDto): number {
  return left.task.updated_at.localeCompare(right.task.updated_at);
}

export function shouldReplaceTask(
  current: TaskViewDto | undefined,
  incoming: TaskViewDto,
): boolean {
  if (!current) {
    return true;
  }
  return compareTaskSnapshots(incoming, current) >= 0;
}

function sortTaskIds(
  workspaceId: string,
  taskIds: string[],
  tasksById: TasksById,
): string[] {
  return [...new Set(taskIds)].filter(Boolean).sort((left, right) => {
    const leftTask = tasksById[taskEntityId(workspaceId, left)];
    const rightTask = tasksById[taskEntityId(workspaceId, right)];
    if (!leftTask && !rightTask) {
      return 0;
    }
    if (!leftTask) {
      return 1;
    }
    if (!rightTask) {
      return -1;
    }
    return rightTask.task.updated_at.localeCompare(leftTask.task.updated_at);
  });
}

export function taskForWorkspace(
  tasksById: TasksById,
  workspaceId: string,
  taskId: string,
): TaskViewDto | undefined {
  return tasksById[taskEntityId(workspaceId, taskId)];
}

export function tasksForWorkspace(
  taskIdsByWorkspaceId: TaskIdsByWorkspace,
  tasksById: TasksById,
  workspaceId: string,
): TaskViewDto[] {
  return (taskIdsByWorkspaceId[workspaceId] ?? [])
    .map((taskId) => taskForWorkspace(tasksById, workspaceId, taskId))
    .filter((task): task is TaskViewDto => Boolean(task));
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

export type RunHistoryCacheEntry = {
  loading: boolean;
  signature?: string;
  result?: NormalizedTaskRunHistoryResult;
  error?: string;
};

export type TaskDetailCacheEntry = {
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
  tasksById: TasksById;
  taskIdsByWorkspaceId: TaskIdsByWorkspace;
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
  tasksById: {},
  taskIdsByWorkspaceId: {},
  liveEventsByWorkspaceId: {},
  liveEventRunIdsByWorkspaceId: {},
  taskDetailsByWorkspaceId: {},
  setTasks: (workspaceId, tasks) =>
    set((state) => {
      const nextTasksById = { ...state.tasksById };
      const nextTaskIds = tasks.map((task) => task.task.id);
      const nextTaskIdSet = new Set(nextTaskIds);
      for (const taskId of state.taskIdsByWorkspaceId[workspaceId] ?? []) {
        if (!nextTaskIdSet.has(taskId)) {
          delete nextTasksById[taskEntityId(workspaceId, taskId)];
        }
      }
      for (const task of tasks) {
        const entityId = taskEntityId(workspaceId, task.task.id);
        if (shouldReplaceTask(nextTasksById[entityId], task)) {
          nextTasksById[entityId] = task;
        }
      }
      return {
        tasksById: nextTasksById,
        taskIdsByWorkspaceId: {
          ...state.taskIdsByWorkspaceId,
          [workspaceId]: sortTaskIds(workspaceId, nextTaskIds, nextTasksById),
        },
      };
    }),
  upsertTask: (workspaceId, task) =>
    set((state) => {
      const entityId = taskEntityId(workspaceId, task.task.id);
      const nextTasksById = {
        ...state.tasksById,
        ...(shouldReplaceTask(state.tasksById[entityId], task)
          ? { [entityId]: task }
          : {}),
      };
      const nextTaskIds = sortTaskIds(
        workspaceId,
        [...(state.taskIdsByWorkspaceId[workspaceId] ?? []), task.task.id],
        nextTasksById,
      );
      return {
        tasksById: nextTasksById,
        taskIdsByWorkspaceId: {
          ...state.taskIdsByWorkspaceId,
          [workspaceId]: nextTaskIds,
        },
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
      const taskIds = state.taskIdsByWorkspaceId[workspaceId] ?? [];
      const tasksById = { ...state.tasksById };
      for (const taskId of taskIds) {
        delete tasksById[taskEntityId(workspaceId, taskId)];
      }
      const { [workspaceId]: _taskIds, ...taskIdsByWorkspaceId } =
        state.taskIdsByWorkspaceId;
      const { [workspaceId]: _output, ...liveEventsByWorkspaceId } =
        state.liveEventsByWorkspaceId;
      const { [workspaceId]: _outputRunIds, ...liveEventRunIdsByWorkspaceId } =
        state.liveEventRunIdsByWorkspaceId;
      const { [workspaceId]: _details, ...taskDetailsByWorkspaceId } =
        state.taskDetailsByWorkspaceId;
      return {
        tasksById,
        taskIdsByWorkspaceId,
        liveEventsByWorkspaceId,
        liveEventRunIdsByWorkspaceId,
        taskDetailsByWorkspaceId,
      };
    }),
  reset: () =>
    set({
      tasksById: {},
      taskIdsByWorkspaceId: {},
      liveEventsByWorkspaceId: {},
      liveEventRunIdsByWorkspaceId: {},
      taskDetailsByWorkspaceId: {},
    }),
}));
