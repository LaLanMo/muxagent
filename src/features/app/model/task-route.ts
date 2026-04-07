import { parseTaskDetailPath } from "@/domain/routes";

export function preferredWorkspaceIdsForPath(
  pathname: string,
  ...fallbackIds: Array<string | undefined>
): Array<string | undefined> {
  const routeWorkspaceId = parseTaskDetailPath(pathname)?.workspaceId;
  return [routeWorkspaceId, ...fallbackIds];
}
