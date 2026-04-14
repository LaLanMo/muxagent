import { taskBucket } from "@/domain/task-shell";
import type {
  BlockedStepDto,
  InputRequestDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";

export function canShowFollowUpSurface(args: {
  task: TaskViewDto | undefined;
  inputRequest: InputRequestDto | undefined;
  latestBlockedStep: BlockedStepDto | undefined;
  retryRun: NodeRunViewDto | undefined;
}) {
  const { task, inputRequest, latestBlockedStep, retryRun } = args;
  if (!task || inputRequest || latestBlockedStep || retryRun) {
    return false;
  }
  return taskBucket(task) === "done";
}
