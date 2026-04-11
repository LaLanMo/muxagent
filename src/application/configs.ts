import type { DesktopRuntime } from "@/platform/contract";
import type {
  ConfigCatalogResult,
  ConfigDetailDto,
  ConfigDraftDto,
} from "@/rpc/types";

export async function refreshConfigCatalog(
  runtime: DesktopRuntime,
): Promise<ConfigCatalogResult> {
  return runtime.backend.configCatalog();
}

export async function loadConfigDetail(
  runtime: DesktopRuntime,
  alias: string,
): Promise<ConfigDetailDto> {
  const trimmedAlias = alias.trim();
  if (!trimmedAlias) {
    throw new Error("Config alias is required");
  }
  const result = await runtime.backend.configGet(trimmedAlias);
  return result.entry;
}

export async function cloneConfig(
  runtime: DesktopRuntime,
  sourceAlias: string,
  newAlias: string,
): Promise<ConfigDetailDto> {
  const result = await runtime.backend.configClone({
    source_alias: sourceAlias.trim(),
    new_alias: newAlias.trim(),
  });
  return result.entry;
}

export async function deleteConfig(
  runtime: DesktopRuntime,
  alias: string,
): Promise<void> {
  await runtime.backend.configDelete({ alias: alias.trim() });
}

export async function setDefaultConfig(
  runtime: DesktopRuntime,
  alias: string,
): Promise<ConfigDetailDto> {
  const result = await runtime.backend.configSetDefault({ alias: alias.trim() });
  return result.entry;
}

export async function validateConfigDraft(
  runtime: DesktopRuntime,
  config: ConfigDraftDto,
) {
  return runtime.backend.configValidate({ config });
}

export function createEditableDraft(entry: ConfigDetailDto): ConfigDraftDto | undefined {
  if (!entry.config) {
    return undefined;
  }
  return {
    ...entry.config,
    runtime: entry.runtime_explicit ? entry.config.runtime : "",
    clarification: {
      ...entry.config.clarification,
    },
    topology: {
      ...entry.config.topology,
      nodes: entry.config.topology.nodes.map((node) => ({ ...node })),
      edges: entry.config.topology.edges.map((edge) => ({
        ...edge,
        when: edge.when ? { ...edge.when } : undefined,
      })),
    },
    node_definitions: Object.fromEntries(
      Object.entries(entry.config.node_definitions).map(([name, definition]) => [
        name,
        {
          ...definition,
          result_schema: structuredClone(definition.result_schema),
        },
      ]),
    ),
  };
}

export function suggestConfigAlias(
  sourceAlias: string,
  existingAliases: string[],
): string {
  const baseAlias = `${sourceAlias.trim() || "config"}-copy`;
  const existing = new Set(existingAliases.map((alias) => alias.trim()));
  if (!existing.has(baseAlias)) {
    return baseAlias;
  }
  for (let suffix = 2; ; suffix += 1) {
    const candidate = `${baseAlias}-${suffix}`;
    if (!existing.has(candidate)) {
      return candidate;
    }
  }
}
