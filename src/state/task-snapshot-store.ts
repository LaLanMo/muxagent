import { create } from "zustand";
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

type TasksByWorkspace = Record<string, TaskViewDto[]>;
type OutputByWorkspace = Record<string, Record<string, string[]>>;
type TaskDetailsByWorkspace = Record<string, Record<string, TaskDetailCacheEntry>>;

export type TaskDetailCacheEntry = {
  task?: TaskViewDto;
  config?: ConfigViewDto;
  inputRequest?: InputRequestDto;
  artifacts: ArtifactRefDto[];
  loading: boolean;
  stale: boolean;
  error?: string;
};

interface TaskSnapshotState {
  tasksByWorkspaceId: TasksByWorkspace;
  liveOutputByWorkspaceId: OutputByWorkspace;
  taskDetailsByWorkspaceId: TaskDetailsByWorkspace;
  setTasks: (workspaceId: string, tasks: TaskViewDto[]) => void;
  upsertTask: (workspaceId: string, task: TaskViewDto) => void;
  appendLiveOutput: (workspaceId: string, taskId: string, lines: string[]) => void;
  beginTaskDetailLoad: (workspaceId: string, taskId: string) => void;
  resolveTaskDetail: (
    workspaceId: string,
    taskId: string,
    detail: {
      task: TaskViewDto;
      config?: ConfigViewDto;
      inputRequest?: InputRequestDto;
      artifacts: ArtifactRefDto[];
    },
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
  appendLiveOutput: (workspaceId, taskId, lines) =>
    set((state) => {
      if (lines.length === 0) {
        return state;
      }
      const workspaceOutput = state.liveOutputByWorkspaceId[workspaceId] ?? {};
      const existing = workspaceOutput[taskId] ?? [];
      const next = [...existing, ...lines].slice(-120);
      return {
        liveOutputByWorkspaceId: {
          ...state.liveOutputByWorkspaceId,
          [workspaceId]: {
            ...workspaceOutput,
            [taskId]: next,
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
          loading: false,
          stale: false,
          error: undefined,
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
      const { [workspaceId]: _details, ...taskDetailsByWorkspaceId } =
        state.taskDetailsByWorkspaceId;
      return {
        tasksByWorkspaceId,
        liveOutputByWorkspaceId,
        taskDetailsByWorkspaceId,
      };
    }),
  reset: () =>
    set({
      tasksByWorkspaceId: {},
      liveOutputByWorkspaceId: {},
      taskDetailsByWorkspaceId: {},
    }),
}));
