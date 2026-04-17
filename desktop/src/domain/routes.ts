export type TaskRouteParams = {
  workspaceId: string;
  taskId: string;
};

export type CheckoutRouteParams = {
  workspaceId: string;
  checkoutPath: string;
};

export type FileDiffRouteParams = CheckoutRouteParams & {
  fileId: string;
};

export type CommitDiffRouteParams = CheckoutRouteParams & {
  commitHash: string;
};

export const sourceControlRoutePath = "/source-control";

export type TaskSurfaceReturnState = {
  path: string;
  workspaceId?: string;
};

export type TaskDetailLocationState = {
  taskSurfaceReturnContext?: TaskSurfaceReturnState;
};

const taskRoutePattern = /^\/workspaces\/([^/]+)\/tasks\/([^/]+)$/;
const checkoutRoutePattern = /^\/workspaces\/([^/]+)\/checkouts\/([^/]+)\/?$/;
const fileDiffRoutePattern =
  /^\/workspaces\/([^/]+)\/checkouts\/([^/]+)\/files\/([^/]+)\/?$/;
const commitDiffRoutePattern =
  /^\/workspaces\/([^/]+)\/checkouts\/([^/]+)\/commits\/([^/]+)\/?$/;

function encodeCheckoutPath(checkoutPath: string): string {
  return encodeURIComponent(checkoutPath);
}

function decodeCheckoutPath(value: string): string {
  return decodeURIComponent(value);
}

export function buildTaskDetailPath(
  workspaceId: string,
  taskId: string,
): string {
  return `/workspaces/${encodeURIComponent(workspaceId)}/tasks/${encodeURIComponent(
    taskId,
  )}`;
}

export function parseTaskDetailPath(pathname: string): TaskRouteParams | null {
  const match = taskRoutePattern.exec(pathname);
  if (!match) {
    return null;
  }
  return {
    workspaceId: decodeURIComponent(match[1] ?? ""),
    taskId: decodeURIComponent(match[2] ?? ""),
  };
}

export function buildCheckoutPath(
  workspaceId: string,
  checkoutPath: string,
): string {
  return `/workspaces/${encodeURIComponent(workspaceId)}/checkouts/${encodeCheckoutPath(
    checkoutPath,
  )}`;
}

export function buildFileDiffPath(
  workspaceId: string,
  checkoutPath: string,
  fileId: string,
): string {
  return `${buildCheckoutPath(workspaceId, checkoutPath)}/files/${encodeURIComponent(
    fileId,
  )}`;
}

export function buildCommitDiffPath(
  workspaceId: string,
  checkoutPath: string,
  commitHash: string,
): string {
  return `${buildCheckoutPath(workspaceId, checkoutPath)}/commits/${encodeURIComponent(
    commitHash,
  )}`;
}

export function parseCheckoutPath(pathname: string): CheckoutRouteParams | null {
  const match = checkoutRoutePattern.exec(pathname);
  if (!match) {
    return null;
  }
  return {
    workspaceId: decodeURIComponent(match[1] ?? ""),
    checkoutPath: decodeCheckoutPath(match[2] ?? ""),
  };
}

export function parseFileDiffPath(pathname: string): FileDiffRouteParams | null {
  const match = fileDiffRoutePattern.exec(pathname);
  if (!match) {
    return null;
  }
  return {
    workspaceId: decodeURIComponent(match[1] ?? ""),
    checkoutPath: decodeCheckoutPath(match[2] ?? ""),
    fileId: decodeURIComponent(match[3] ?? ""),
  };
}

export function parseCommitDiffPath(
  pathname: string,
): CommitDiffRouteParams | null {
  const match = commitDiffRoutePattern.exec(pathname);
  if (!match) {
    return null;
  }
  return {
    workspaceId: decodeURIComponent(match[1] ?? ""),
    checkoutPath: decodeCheckoutPath(match[2] ?? ""),
    commitHash: decodeURIComponent(match[3] ?? ""),
  };
}

export function isSourceControlPath(pathname: string): boolean {
  return (
    pathname === sourceControlRoutePath ||
    checkoutRoutePattern.test(pathname) ||
    fileDiffRoutePattern.test(pathname) ||
    commitDiffRoutePattern.test(pathname)
  );
}
