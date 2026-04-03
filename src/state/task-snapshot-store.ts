import { create } from "zustand";
import type { ArtifactRefDto, TaskViewDto } from "@/rpc/types";

function sortTasks(tasks: TaskViewDto[]): TaskViewDto[] {
  return [...tasks].sort((left, right) =>
    right.task.updated_at.localeCompare(left.task.updated_at),
  );
}

type SelectedTaskByWorkspace = Record<string, string | undefined>;
type TasksByWorkspace = Record<string, TaskViewDto[]>;
type ArtifactsByWorkspace = Record<string, Record<string, ArtifactRefDto[]>>;
type OutputByWorkspace = Record<string, Record<string, string[]>>;

interface TaskSnapshotState {
  tasksByWorkspaceId: TasksByWorkspace;
  selectedTaskIdByWorkspaceId: SelectedTaskByWorkspace;
  artifactsByWorkspaceId: ArtifactsByWorkspace;
  liveOutputByWorkspaceId: OutputByWorkspace;
  setTasks: (workspaceId: string, tasks: TaskViewDto[]) => void;
  upsertTask: (workspaceId: string, task: TaskViewDto) => void;
  selectTask: (workspaceId: string, taskId?: string) => void;
  setArtifacts: (
    workspaceId: string,
    taskId: string,
    artifacts: ArtifactRefDto[],
  ) => void;
  appendLiveOutput: (workspaceId: string, taskId: string, lines: string[]) => void;
  resetWorkspace: (workspaceId: string) => void;
  reset: () => void;
}

export const useTaskSnapshotStore = create<TaskSnapshotState>((set) => ({
  tasksByWorkspaceId: {},
  selectedTaskIdByWorkspaceId: {},
  artifactsByWorkspaceId: {},
  liveOutputByWorkspaceId: {},
  setTasks: (workspaceId, tasks) =>
    set((state) => ({
      tasksByWorkspaceId: {
        ...state.tasksByWorkspaceId,
        [workspaceId]: sortTasks(tasks),
      },
      selectedTaskIdByWorkspaceId: {
        ...state.selectedTaskIdByWorkspaceId,
        [workspaceId]:
          state.selectedTaskIdByWorkspaceId[workspaceId] &&
          tasks.some(
            (task) =>
              task.task.id === state.selectedTaskIdByWorkspaceId[workspaceId],
          )
            ? state.selectedTaskIdByWorkspaceId[workspaceId]
            : undefined,
      },
    })),
  upsertTask: (workspaceId, task) =>
    set((state) => {
      const existing = state.tasksByWorkspaceId[workspaceId] ?? [];
      const nextTasks = existing.some((entry) => entry.task.id === task.task.id)
        ? existing.map((entry) => (entry.task.id === task.task.id ? task : entry))
        : [...existing, task];
      return {
        tasksByWorkspaceId: {
          ...state.tasksByWorkspaceId,
          [workspaceId]: sortTasks(nextTasks),
        },
      };
    }),
  selectTask: (workspaceId, taskId) =>
    set((state) => ({
      selectedTaskIdByWorkspaceId: {
        ...state.selectedTaskIdByWorkspaceId,
        [workspaceId]: taskId,
      },
    })),
  setArtifacts: (workspaceId, taskId, artifacts) =>
    set((state) => ({
      artifactsByWorkspaceId: {
        ...state.artifactsByWorkspaceId,
        [workspaceId]: {
          ...(state.artifactsByWorkspaceId[workspaceId] ?? {}),
          [taskId]: artifacts,
        },
      },
    })),
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
  resetWorkspace: (workspaceId) =>
    set((state) => {
      const { [workspaceId]: _tasks, ...tasksByWorkspaceId } =
        state.tasksByWorkspaceId;
      const { [workspaceId]: _selected, ...selectedTaskIdByWorkspaceId } =
        state.selectedTaskIdByWorkspaceId;
      const { [workspaceId]: _artifacts, ...artifactsByWorkspaceId } =
        state.artifactsByWorkspaceId;
      const { [workspaceId]: _output, ...liveOutputByWorkspaceId } =
        state.liveOutputByWorkspaceId;
      return {
        tasksByWorkspaceId,
        selectedTaskIdByWorkspaceId,
        artifactsByWorkspaceId,
        liveOutputByWorkspaceId,
      };
    }),
  reset: () =>
    set({
      tasksByWorkspaceId: {},
      selectedTaskIdByWorkspaceId: {},
      artifactsByWorkspaceId: {},
      liveOutputByWorkspaceId: {},
    }),
}));
