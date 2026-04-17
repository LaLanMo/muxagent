import { buildTaskDetailPath } from "@/domain/routes";
import { taskBucket } from "@/domain/task-shell";
import type {
  GitCommitDto,
  GitCheckoutDetailDto,
  GitCheckoutSummaryDto,
  GitFileBucketDto,
  GitFileChangeDto,
  TaskViewDto,
} from "@/rpc/types";

export type SourceControlTaskTone = "running" | "awaiting" | "failed" | "done";

export type SourceControlTaskSummary = {
  total: number;
  runningCount: number;
  attentionCount: number;
  rows: Array<{
    id: string;
    title: string;
    href: string;
    tone: SourceControlTaskTone;
  }>;
};

export type SourceControlFileRow = {
  id: string;
  path: string;
  origPath?: string;
  bucket: GitFileBucketDto;
  statusCode: string;
  tone: "default" | "warning" | "success" | "danger";
};

export type SourceControlFileSection = {
  id: "changes" | "staged";
  label: string;
  count: number;
  rows: SourceControlFileRow[];
};

export type SourceControlCommitSection = {
  label: string;
  rows: Array<{
    id: string;
    shortHash: string;
    subject: string;
  }>;
};

function normalizePath(value: string | undefined): string {
  return (value ?? "").replaceAll("\\", "/").replace(/\/+$/, "");
}

function isPathWithinCheckout(candidatePath: string, checkoutPath: string): boolean {
  const candidate = normalizePath(candidatePath);
  const checkout = normalizePath(checkoutPath);
  if (!candidate || !checkout) {
    return false;
  }
  return candidate === checkout || candidate.startsWith(`${checkout}/`);
}

function fileStatusCode(file: GitFileChangeDto): string {
  if (file.bucket === "untracked") {
    return "A";
  }
  if (file.bucket === "conflicted") {
    return "U";
  }
  const [indexStatus = ".", worktreeStatus = "."] = file.xy.padEnd(2, ".").split("");
  const code = file.bucket === "staged" ? indexStatus : worktreeStatus;
  const resolved = code === "." ? indexStatus || worktreeStatus : code;
  return resolved === "." ? "M" : resolved.toUpperCase();
}

function fileStatusTone(
  statusCode: string,
): SourceControlFileRow["tone"] {
  switch (statusCode) {
    case "A":
      return "success";
    case "D":
    case "U":
      return "danger";
    case "R":
    case "C":
    case "M":
    default:
      return "warning";
  }
}

function sortTasksByUpdatedAtDesc(left: TaskViewDto, right: TaskViewDto): number {
  return right.task.updated_at.localeCompare(left.task.updated_at);
}

function taskTone(task: TaskViewDto): SourceControlTaskTone {
  switch (taskBucket(task)) {
    case "awaiting":
      return "awaiting";
    case "failed":
      return "failed";
    case "done":
      return "done";
    case "running":
    default:
      return "running";
  }
}

export function pickPreferredCheckoutPath(
  main: GitCheckoutSummaryDto,
  worktrees: GitCheckoutSummaryDto[],
): string {
  const dirtyWorktree = worktrees.find(
    (checkout) => checkout.reachable && checkout.total_change_count > 0,
  );
  if (dirtyWorktree) {
    return dirtyWorktree.path;
  }
  if (main.reachable && main.total_change_count > 0) {
    return main.path;
  }
  return worktrees[0]?.path ?? main.path;
}

export function buildCheckoutSummaryLabel(checkout: GitCheckoutSummaryDto): string {
  if (!checkout.reachable) {
    switch (checkout.unreachable_reason) {
      case "not_a_git_repo":
        return "not a git repo";
      case "path_missing":
        return "path missing";
      case "safe_directory":
        return "unsafe";
      case "timeout":
        return "timeout";
      case "output_too_big":
        return "too large";
      default:
        return "unreachable";
    }
  }

  const parts: string[] = [];
  const unstagedLikeCount =
    checkout.unstaged_count + checkout.untracked_count + checkout.conflicted_count;
  if (unstagedLikeCount > 0) {
    parts.push(`${unstagedLikeCount}u`);
  }
  if (checkout.staged_count > 0) {
    parts.push(`${checkout.staged_count}s`);
  }
  return parts.join(" ") || "clean";
}

export function buildTaskSummaryForCheckout(
  workspaceId: string,
  checkoutPath: string,
  tasks: TaskViewDto[],
): SourceControlTaskSummary {
  const matchingTasks = tasks
    .filter((task) => isPathWithinCheckout(task.task.execution_dir, checkoutPath))
    .sort(sortTasksByUpdatedAtDesc);

  return {
    total: matchingTasks.length,
    runningCount: matchingTasks.filter((task) => taskTone(task) === "running").length,
    attentionCount: matchingTasks.filter((task) => {
      const tone = taskTone(task);
      return tone === "awaiting" || tone === "failed";
    }).length,
    rows: matchingTasks.slice(0, 3).map((task) => ({
      id: task.task.id,
      title: task.task.description,
      href: buildTaskDetailPath(workspaceId, task.task.id),
      tone: taskTone(task),
    })),
  };
}

function mapFiles(files: GitFileChangeDto[]): SourceControlFileRow[] {
  return files.map((file) => {
    const statusCode = fileStatusCode(file);
    return {
      id: `${file.bucket}:${file.path}`,
      path: file.path,
      origPath: file.orig_path,
      bucket: file.bucket,
      statusCode,
      tone: fileStatusTone(statusCode),
    };
  });
}

export function buildFileSections(detail: GitCheckoutDetailDto): SourceControlFileSection[] {
  const stagedFiles = detail.files.filter((file) => file.bucket === "staged");
  const changeFiles = detail.files.filter((file) => file.bucket !== "staged");

  return [
    {
      id: "changes",
      label: "Changes",
      count:
        detail.unstaged_count + detail.untracked_count + detail.conflicted_count,
      rows: mapFiles(changeFiles),
    },
    {
      id: "staged",
      label: "Staged",
      count: detail.staged_count,
      rows: mapFiles(stagedFiles),
    },
  ];
}

export function buildCommitSection(
  checkout: GitCheckoutSummaryDto,
  commits: GitCommitDto[] = [],
): SourceControlCommitSection | undefined {
  if (commits.length === 0 && (!checkout.head_commit || !checkout.head_subject)) {
    return undefined;
  }
  const upstreamLabel = checkout.upstream?.split("/").at(-1) ?? "upstream";
  const label =
    checkout.ahead_count > 0
      ? `ahead of ${upstreamLabel} · ${checkout.ahead_count}`
      : checkout.behind_count > 0
        ? `behind ${upstreamLabel} · ${checkout.behind_count}`
        : "latest HEAD";

  return {
    label,
    rows: [
      ...(commits.length > 0
        ? commits.map((commit) => ({
            id: `${commit.short_hash}-${commit.subject}`,
            shortHash: commit.short_hash,
            subject: commit.subject,
          }))
        : [
            {
              id: checkout.head_commit ?? "head",
              shortHash: checkout.head_commit?.slice(0, 7) ?? "HEAD",
              subject: checkout.head_subject ?? "Latest commit",
            },
          ]),
    ],
  };
}
