import type { ConfigDraftDto } from "@/rpc/types";

export function createEditableNodeName(config: ConfigDraftDto): string {
  const existing = new Set(config.topology.nodes.map((node) => node.name));
  for (let index = 1; ; index += 1) {
    const candidate = `node_${index}`;
    if (!existing.has(candidate)) {
      return candidate;
    }
  }
}

export function renameNodeInDraft(
  config: ConfigDraftDto,
  currentName: string,
  nextName: string,
): ConfigDraftDto {
  if (!currentName || !nextName || currentName === nextName) {
    return config;
  }
  const nodeDefinitions = Object.fromEntries(
    Object.entries(config.node_definitions).map(([name, definition]) => [
      name === currentName ? nextName : name,
      definition,
    ]),
  );
  return {
    ...config,
    topology: {
      ...config.topology,
      entry: config.topology.entry === currentName ? nextName : config.topology.entry,
      nodes: config.topology.nodes.map((node) =>
        node.name === currentName ? { ...node, name: nextName } : node,
      ),
      edges: config.topology.edges.map((edge) => ({
        ...edge,
        from: edge.from === currentName ? nextName : edge.from,
        to: edge.to === currentName ? nextName : edge.to,
      })),
    },
    node_definitions: nodeDefinitions,
  };
}

export function addNodeToDraft(config: ConfigDraftDto, nodeName: string): ConfigDraftDto {
  if (!nodeName.trim()) {
    return config;
  }
  if (config.topology.nodes.some((node) => node.name === nodeName)) {
    return config;
  }
  return {
    ...config,
    topology: {
      ...config.topology,
      nodes: [...config.topology.nodes, { name: nodeName }],
    },
    node_definitions: {
      ...config.node_definitions,
      [nodeName]: {
        type: "agent",
        system_prompt: "",
        max_clarification_rounds: 0,
        result_schema: {
          type: "object",
          additionalProperties: false,
          properties: {},
        },
      },
    },
  };
}

export function removeNodeFromDraft(config: ConfigDraftDto, nodeName: string): ConfigDraftDto {
  const remainingNodes = config.topology.nodes.filter((node) => node.name !== nodeName);
  const { [nodeName]: _, ...remainingDefinitions } = config.node_definitions;
  const nextEntry =
    config.topology.entry === nodeName
      ? remainingNodes[0]?.name ?? ""
      : config.topology.entry;
  return {
    ...config,
    topology: {
      ...config.topology,
      entry: nextEntry,
      nodes: remainingNodes,
      edges: config.topology.edges.filter(
        (edge) => edge.from !== nodeName && edge.to !== nodeName,
      ),
    },
    node_definitions: remainingDefinitions,
  };
}

export function updateNodeDefinition(
  config: ConfigDraftDto,
  nodeName: string,
  updater: (definition: ConfigDraftDto["node_definitions"][string]) => ConfigDraftDto["node_definitions"][string],
): ConfigDraftDto {
  const definition = config.node_definitions[nodeName];
  if (!definition) {
    return config;
  }
  return {
    ...config,
    node_definitions: {
      ...config.node_definitions,
      [nodeName]: updater(definition),
    },
  };
}

export function updateNodeRef(
  config: ConfigDraftDto,
  nodeName: string,
  updater: (node: ConfigDraftDto["topology"]["nodes"][number]) => ConfigDraftDto["topology"]["nodes"][number],
): ConfigDraftDto {
  return {
    ...config,
    topology: {
      ...config.topology,
      nodes: config.topology.nodes.map((node) =>
        node.name === nodeName ? updater(node) : node,
      ),
    },
  };
}

export function addEdgeToDraft(config: ConfigDraftDto, from: string): ConfigDraftDto {
  return {
    ...config,
    topology: {
      ...config.topology,
      edges: [
        ...config.topology.edges,
        {
          from,
          to: config.topology.nodes.find((node) => node.name !== from)?.name ?? from,
          when: { kind: "" },
        },
      ],
    },
  };
}

export function updateEdgeInDraft(
  config: ConfigDraftDto,
  edgeIndex: number,
  updater: (edge: ConfigDraftDto["topology"]["edges"][number]) => ConfigDraftDto["topology"]["edges"][number],
): ConfigDraftDto {
  return {
    ...config,
    topology: {
      ...config.topology,
      edges: config.topology.edges.map((edge, index) =>
        index === edgeIndex ? updater(edge) : edge,
      ),
    },
  };
}

export function removeEdgeFromDraft(config: ConfigDraftDto, edgeIndex: number): ConfigDraftDto {
  return {
    ...config,
    topology: {
      ...config.topology,
      edges: config.topology.edges.filter((_, index) => index !== edgeIndex),
    },
  };
}
