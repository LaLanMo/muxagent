import { parseTaskBoardPath, parseTaskDetailPath } from "@/domain/routes";

export function preferredWorkspaceIdsForPath(
  pathname: string,
  ...fallbackIds: Array<string | undefined>
): Array<string | undefined> {
  const taskBoardRoute = parseTaskBoardPath(pathname);
  const routeWorkspaceId =
    parseTaskDetailPath(pathname)?.workspaceId ??
    (taskBoardRoute?.kind === "workspace"
      ? taskBoardRoute.workspaceId
      : undefined);
  return [routeWorkspaceId, ...fallbackIds];
}
