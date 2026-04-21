export type TaskRouteParams = {
  workspaceId: string;
  taskId: string;
};

export type TaskBoardScope =
  | { kind: "all" }
  | { kind: "workspace"; workspaceId: string };

export type TaskBoardRoute = {
  scope: TaskBoardScope;
  pathname: string;
  search: string;
  href: string;
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

export type ConfigDetailRouteParams = {
  alias: string;
};

export const sourceControlRoutePath = "/source-control";
export const sourceControlLandingPath = "/source-control-landing";
export const workbenchZeroTabPath = "/workspace";

export type WorkbenchSidebarViewId =
  | "tasks"
  | "source-control"
  | "configs"
  | "settings";

export type WorkbenchTabKind =
  | "task-board"
  | "task-detail"
  | "source-control"
  | "file-diff"
  | "commit-diff"
  | "config-list"
  | "config-detail"
  | "settings";

export type WorkbenchTabId =
  | "task-board"
  | `task-board:${string}`
  | "source-control"
  | "config-list"
  | "settings"
  | `task-detail:${string}`
  | `file-diff:${string}:${string}:${string}`
  | `commit-diff:${string}:${string}:${string}`
  | `config-detail:${string}`;

export type WorkbenchTabDescriptor = {
  id: WorkbenchTabId;
  kind: WorkbenchTabKind;
  title: string;
  href: string;
  closeable?: boolean;
};

export type TaskSurfaceReturnState = {
  path: string;
  workspaceId?: string;
};

export type TaskDetailLocationState = {
  taskSurfaceReturnContext?: TaskSurfaceReturnState;
};

const taskRoutePattern = /^\/workspaces\/([^/]+)\/tasks\/([^/]+)$/;
const taskBoardRoutePattern = /^\/workspaces\/([^/]+)\/tasks\/?$/;
const checkoutRoutePattern = /^\/workspaces\/([^/]+)\/checkouts\/([^/]+)\/?$/;
const fileDiffRoutePattern =
  /^\/workspaces\/([^/]+)\/checkouts\/([^/]+)\/files\/([^/]+)\/?$/;
const commitDiffRoutePattern =
  /^\/workspaces\/([^/]+)\/checkouts\/([^/]+)\/commits\/([^/]+)\/?$/;
const configDetailRoutePattern = /^\/configs\/([^/]+)\/?$/;
const relativeUrlBase = "http://muxagent.local";

function encodeCheckoutPath(checkoutPath: string): string {
  return encodeURIComponent(checkoutPath);
}

function decodeCheckoutPath(value: string): string {
  return decodeURIComponent(value);
}

function lastPathSegment(value: string): string {
  const parts = value.split(/[\\/]/).filter(Boolean);
  return parts.at(-1) ?? value;
}

function trimWorkbenchLabel(value: string, maxLength = 28): string {
  const label = value.trim();
  if (label.length <= maxLength) {
    return label;
  }
  return `${label.slice(0, maxLength - 1).trimEnd()}…`;
}

function buildPathWithSearch(pathname: string, search: string): string {
  const params = new URLSearchParams(search);
  params.delete("newTask");
  params.delete("layout");
  const query = params.toString();
  return query ? `${pathname}?${query}` : pathname;
}

export function buildTaskDetailPath(
  workspaceId: string,
  taskId: string,
): string {
  return `/workspaces/${encodeURIComponent(workspaceId)}/tasks/${encodeURIComponent(
    taskId,
  )}`;
}

export function buildTaskBoardPath(scope: TaskBoardScope): string {
  if (scope.kind === "all") {
    return "/";
  }
  return `/workspaces/${encodeURIComponent(scope.workspaceId)}/tasks`;
}

export function parseTaskBoardPath(pathname: string): TaskBoardScope | null {
  if (pathname === "/") {
    return { kind: "all" };
  }

  const match = taskBoardRoutePattern.exec(pathname);
  if (!match) {
    return null;
  }
  return {
    kind: "workspace",
    workspaceId: decodeURIComponent(match[1] ?? ""),
  };
}

export function buildTaskBoardHref(
  scope: TaskBoardScope,
  search = "",
): string {
  return buildPathWithSearch(buildTaskBoardPath(scope), search);
}

export function parseTaskBoardHref(href: string): TaskBoardRoute | null {
  let url: URL;
  try {
    url = new URL(href, relativeUrlBase);
  } catch {
    return null;
  }
  if (url.origin !== relativeUrlBase) {
    return null;
  }
  const scope = parseTaskBoardPath(url.pathname);
  if (!scope) {
    return null;
  }
  const canonicalHref = buildTaskBoardHref(scope, url.search);
  const queryIndex = canonicalHref.indexOf("?");
  return {
    scope,
    pathname: buildTaskBoardPath(scope),
    search: queryIndex >= 0 ? canonicalHref.slice(queryIndex) : "",
    href: canonicalHref,
  };
}

export function taskBoardTabId(scope: TaskBoardScope): WorkbenchTabId {
  if (scope.kind === "all") {
    return "task-board";
  }
  return `task-board:${scope.workspaceId}`;
}

export function isTaskBoardPath(pathname: string): boolean {
  return parseTaskBoardPath(pathname) != null;
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

export function buildConfigDetailPath(alias: string): string {
  return `/configs/${encodeURIComponent(alias)}`;
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

export function parseConfigDetailPath(
  pathname: string,
): ConfigDetailRouteParams | null {
  const match = configDetailRoutePattern.exec(pathname);
  if (!match) {
    return null;
  }
  return {
    alias: decodeURIComponent(match[1] ?? ""),
  };
}

export function isSourceControlPath(pathname: string): boolean {
  return (
    pathname === sourceControlRoutePath ||
    pathname === sourceControlLandingPath ||
    checkoutRoutePattern.test(pathname) ||
    fileDiffRoutePattern.test(pathname) ||
    commitDiffRoutePattern.test(pathname)
  );
}

export function deriveWorkbenchSidebarView(
  pathname: string,
): WorkbenchSidebarViewId {
  if (pathname.startsWith("/settings")) {
    return "settings";
  }
  if (pathname.startsWith("/configs")) {
    return "configs";
  }
  if (isSourceControlPath(pathname)) {
    return "source-control";
  }
  return "tasks";
}

export function resolveWorkbenchTab(
  pathname: string,
  search = "",
): WorkbenchTabDescriptor | null {
  if (pathname === workbenchZeroTabPath) {
    return null;
  }

  const taskDetailRoute = parseTaskDetailPath(pathname);
  if (taskDetailRoute) {
    const shortTaskId = trimWorkbenchLabel(taskDetailRoute.taskId, 10);
    return {
      id: `task-detail:${taskDetailRoute.taskId}`,
      kind: "task-detail",
      title: `Task ${shortTaskId}`,
      href: buildPathWithSearch(pathname, search),
      closeable: true,
    };
  }

  const taskBoardRoute = parseTaskBoardPath(pathname);
  if (taskBoardRoute) {
    return {
      id: taskBoardTabId(taskBoardRoute),
      kind: "task-board",
      title: "Board",
      href: buildTaskBoardHref(taskBoardRoute, search),
      closeable: true,
    };
  }

  const configDetailRoute = parseConfigDetailPath(pathname);
  if (configDetailRoute) {
    return {
      id: `config-detail:${configDetailRoute.alias}`,
      kind: "config-detail",
      title: trimWorkbenchLabel(configDetailRoute.alias),
      href: buildConfigDetailPath(configDetailRoute.alias),
      closeable: true,
    };
  }

  const commitDiffRoute = parseCommitDiffPath(pathname);
  if (commitDiffRoute) {
    return {
      id: `commit-diff:${commitDiffRoute.workspaceId}:${commitDiffRoute.checkoutPath}:${commitDiffRoute.commitHash}`,
      kind: "commit-diff",
      title: trimWorkbenchLabel(commitDiffRoute.commitHash.slice(0, 10), 14),
      href: buildCommitDiffPath(
        commitDiffRoute.workspaceId,
        commitDiffRoute.checkoutPath,
        commitDiffRoute.commitHash,
      ),
      closeable: true,
    };
  }

  const fileDiffRoute = parseFileDiffPath(pathname);
  if (fileDiffRoute) {
    const filePath =
      fileDiffRoute.fileId.split(":").slice(1).join(":") || fileDiffRoute.fileId;
    return {
      id: `file-diff:${fileDiffRoute.workspaceId}:${fileDiffRoute.checkoutPath}:${fileDiffRoute.fileId}`,
      kind: "file-diff",
      title: trimWorkbenchLabel(lastPathSegment(filePath)),
      href: buildFileDiffPath(
        fileDiffRoute.workspaceId,
        fileDiffRoute.checkoutPath,
        fileDiffRoute.fileId,
      ),
      closeable: true,
    };
  }

  const checkoutRoute = parseCheckoutPath(pathname);
  if (checkoutRoute) {
    return {
      id: "task-board",
      kind: "task-board",
      title: "Board",
      href: buildPathWithSearch("/", search),
      closeable: true,
    };
  }

  if (pathname.startsWith("/settings")) {
    return {
      id: "settings",
      kind: "settings",
      title: "Settings",
      href: pathname === "/settings" ? "/settings/runtimes" : pathname,
      closeable: true,
    };
  }

  if (pathname === "/configs") {
    return {
      id: "config-list",
      kind: "config-list",
      title: "Configs",
      href: "/configs",
      closeable: true,
    };
  }

  if (
    pathname === sourceControlLandingPath ||
    pathname === sourceControlRoutePath
  ) {
    return {
      id: "source-control",
      kind: "source-control",
      title: "Source Control",
      href: sourceControlLandingPath,
      closeable: true,
    };
  }

  return {
    id: "task-board",
    kind: "task-board",
    title: "Board",
    href: buildPathWithSearch("/", search),
    closeable: true,
  };
}
