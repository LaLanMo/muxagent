const lastWorkspaceIdKey = "muxagent-desktop:last-workspace-id";

export function readRememberedWorkspaceId(): string | undefined {
  const value = localStorage.getItem(lastWorkspaceIdKey)?.trim();
  return value || undefined;
}

export function rememberWorkspaceId(workspaceId: string): void {
  localStorage.setItem(lastWorkspaceIdKey, workspaceId);
}

export function clearRememberedWorkspaceId(): void {
  localStorage.removeItem(lastWorkspaceIdKey);
}
