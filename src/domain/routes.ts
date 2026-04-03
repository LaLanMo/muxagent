export type TaskRouteParams = {
  workspaceId: string;
  taskId: string;
};

const taskRoutePattern = /^\/workspaces\/([^/]+)\/tasks\/([^/]+)$/;

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
