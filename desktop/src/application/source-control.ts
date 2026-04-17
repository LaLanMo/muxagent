import type { DesktopRuntime } from "@/platform/contract";
import type {
  WorkspaceCheckoutStatusParams,
  WorkspaceCheckoutStatusResult,
  WorkspaceCommitDiffParams,
  WorkspaceCommitDiffResult,
  WorkspaceFileDiffParams,
  WorkspaceFileDiffResult,
  WorkspaceGitStatusParams,
  WorkspaceGitStatusResult,
} from "@/rpc/types";

export async function loadWorkspaceGitStatus(
  runtime: DesktopRuntime,
  workspaceId: string,
): Promise<WorkspaceGitStatusResult> {
  const trimmedWorkspaceId = workspaceId.trim();
  if (!trimmedWorkspaceId) {
    throw new Error("Workspace id is required");
  }
  const params: WorkspaceGitStatusParams = {
    workspace_id: trimmedWorkspaceId,
  };
  return runtime.backend.workspaceGitStatus(params);
}

export const getWorkspaceGitStatus = loadWorkspaceGitStatus;

export async function loadWorkspaceCheckoutStatus(
  runtime: DesktopRuntime,
  args: {
    workspaceId: string;
    checkoutPath: string;
    fileCursor?: string;
    fileLimit?: number;
  },
): Promise<WorkspaceCheckoutStatusResult> {
  const trimmedWorkspaceId = args.workspaceId.trim();
  const trimmedCheckoutPath = args.checkoutPath.trim();
  if (!trimmedWorkspaceId) {
    throw new Error("Workspace id is required");
  }
  if (!trimmedCheckoutPath) {
    throw new Error("Checkout path is required");
  }
  const params: WorkspaceCheckoutStatusParams = {
    workspace_id: trimmedWorkspaceId,
    checkout_path: trimmedCheckoutPath,
    ...(args.fileCursor ? { file_cursor: args.fileCursor } : {}),
    ...(typeof args.fileLimit === "number" ? { file_limit: args.fileLimit } : {}),
  };
  return runtime.backend.workspaceCheckoutStatus(params);
}

export const getWorkspaceCheckoutStatus = (args: {
  runtime: DesktopRuntime;
  workspaceId: string;
  checkoutPath: string;
  fileCursor?: string;
  fileLimit?: number;
}) =>
  loadWorkspaceCheckoutStatus(args.runtime, {
    workspaceId: args.workspaceId,
    checkoutPath: args.checkoutPath,
    fileCursor: args.fileCursor,
    fileLimit: args.fileLimit,
  });

export async function getFileDiff(args: {
  runtime: DesktopRuntime;
  workspaceId: string;
  checkoutPath: string;
  filePath: string;
  bucket?: WorkspaceFileDiffParams["bucket"];
}): Promise<WorkspaceFileDiffResult> {
  const params: WorkspaceFileDiffParams = {
    workspace_id: args.workspaceId.trim(),
    checkout_path: args.checkoutPath.trim(),
    file_path: args.filePath.trim(),
    ...(args.bucket ? { bucket: args.bucket } : {}),
  };
  if (!params.workspace_id) {
    throw new Error("Workspace id is required");
  }
  if (!params.checkout_path) {
    throw new Error("Checkout path is required");
  }
  if (!params.file_path) {
    throw new Error("File path is required");
  }
  return args.runtime.backend.workspaceFileDiff(params);
}

export async function getCommitDiff(args: {
  runtime: DesktopRuntime;
  workspaceId: string;
  checkoutPath: string;
  commitHash: string;
}): Promise<WorkspaceCommitDiffResult> {
  const params: WorkspaceCommitDiffParams = {
    workspace_id: args.workspaceId.trim(),
    checkout_path: args.checkoutPath.trim(),
    commit_hash: args.commitHash.trim(),
  };
  if (!params.workspace_id) {
    throw new Error("Workspace id is required");
  }
  if (!params.checkout_path) {
    throw new Error("Checkout path is required");
  }
  if (!params.commit_hash) {
    throw new Error("Commit hash is required");
  }
  return args.runtime.backend.workspaceCommitDiff(params);
}
