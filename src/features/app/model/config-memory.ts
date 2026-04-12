const lastConfigAliasKey = "muxagent-desktop:last-config-alias";

export function readRememberedConfigAlias(): string | undefined {
  const value = localStorage.getItem(lastConfigAliasKey)?.trim();
  return value || undefined;
}

export function rememberConfigAlias(alias: string): void {
  const trimmed = alias.trim();
  if (!trimmed) {
    return;
  }
  localStorage.setItem(lastConfigAliasKey, trimmed);
}

export function clearRememberedConfigAlias(): void {
  localStorage.removeItem(lastConfigAliasKey);
}
