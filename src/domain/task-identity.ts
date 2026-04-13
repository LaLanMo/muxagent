export function taskEntityId(workspaceId: string, taskId: string): string {
  return `${workspaceId}:${taskId}`;
}
