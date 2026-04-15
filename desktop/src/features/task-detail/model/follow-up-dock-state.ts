import { canShowFollowUpSurface } from "@/features/task-detail/model/task-detail-action-surface";
import type {
  BlockedStepDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";
import {
  taskSnapshotKey,
  type TaskDetailCacheEntry,
} from "@/state/task-snapshot-store";

export type FollowUpDockState = "pending" | "basic" | "refine";

export function deriveFollowUpDockState(args: {
  task?: TaskViewDto;
  detailEntry?: TaskDetailCacheEntry;
  inputRequest?: InputRequestDto;
  latestBlockedStep?: BlockedStepDto;
  retryRun?: NodeRunViewDto;
}): FollowUpDockState | undefined {
  const { task, detailEntry, inputRequest, latestBlockedStep, retryRun } = args;
  if (
    !canShowFollowUpSurface({
      task,
      inputRequest,
      latestBlockedStep,
      retryRun,
    })
  ) {
    return undefined;
  }
  const currentSnapshotKey = taskSnapshotKey(task);
  if (!currentSnapshotKey || detailEntry?.lastAppliedSnapshotKey !== currentSnapshotKey) {
    return "pending";
  }
  return detailEntry.followUp ? "refine" : "basic";
}
