import ELK, {
  type ElkExtendedEdge,
  type ElkLabel,
  type ElkNode,
  type ElkPoint,
} from "elkjs/lib/elk.bundled.js";
import type { ConfigDraftDto } from "@/rpc/types";

export type ConfigGraphNode = {
  id: string;
  name: string;
  position: {
    x: number;
    y: number;
  };
  width: number;
  height: number;
  typeLabel: string;
  isEntry: boolean;
  outgoingCount: number;
};

export type ConfigGraphEdge = {
  id: string;
  source: string;
  target: string;
  path: string;
  label?: string;
  labelX?: number;
  labelY?: number;
};

export type ConfigGraphLayout = {
  nodes: ConfigGraphNode[];
  edges: ConfigGraphEdge[];
  width: number;
  height: number;
};

const elk = new ELK();
const graphNodeWidth = 164;
const graphNodeHeight = 60;
const graphPadding = 48;
const labelOffset = 18;

export async function buildConfigGraphLayout(
  config: ConfigDraftDto,
): Promise<ConfigGraphLayout> {
  const outgoingByName = new Map(
    config.topology.nodes.map((node) => [
      node.name,
      config.topology.edges.filter((edge) => edge.from === node.name).length,
    ]),
  );

  const graph: ElkNode = {
    id: "config-root",
    layoutOptions: {
      "elk.algorithm": "layered",
      "elk.direction": "DOWN",
      "elk.edgeRouting": "POLYLINE",
      "elk.padding": `[top=${graphPadding},left=${graphPadding},bottom=${graphPadding},right=${graphPadding}]`,
      "elk.spacing.nodeNode": "96",
      "elk.layered.spacing.nodeNodeBetweenLayers": "120",
      "elk.layered.spacing.edgeNodeBetweenLayers": "52",
      "elk.layered.nodePlacement.strategy": "NETWORK_SIMPLEX",
      "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
      "elk.layered.cycleBreaking.strategy": "GREEDY_MODEL_ORDER",
      "elk.layered.crossingMinimization.strategy": "LAYER_SWEEP",
      "elk.layered.edgeRouting.polyline.slopedEdgeZoneWidth": "12",
      "elk.edgeLabels.inline": "false",
      "elk.edgeLabels.placement": "CENTER",
    },
    children: config.topology.nodes.map((node) => ({
      id: node.name,
      width: graphNodeWidth,
      height: graphNodeHeight,
      layoutOptions: {
        "elk.layered.layering.layerConstraint":
          node.name === config.topology.entry
            ? "FIRST"
            : (config.node_definitions[node.name]?.type ?? "agent") === "terminal" ||
                (outgoingByName.get(node.name) ?? 0) === 0
              ? "LAST"
              : "NONE",
      },
    })),
    edges: config.topology.edges.map((edge, index) => {
      const label = formatEdgeLabel(edge);
      return {
        id: `${edge.from}-${edge.to}-${index}`,
        sources: [edge.from],
        targets: [edge.to],
        labels: label ? [createEdgeLabel(label)] : undefined,
      };
    }),
  };

  const layout = await elk.layout(graph);
  const children = layout.children ?? [];
  const nodes = children.map((node) => ({
    id: node.id,
    name: node.id,
    position: {
      x: node.x ?? 0,
      y: node.y ?? 0,
    },
    width: node.width ?? graphNodeWidth,
    height: node.height ?? graphNodeHeight,
    typeLabel: config.node_definitions[node.id]?.type ?? "agent",
    isEntry: node.id === config.topology.entry,
    outgoingCount: config.topology.edges.filter((edge) => edge.from === node.id).length,
  }));

  const edges = (layout.edges ?? []).flatMap((edge) => {
    const section = edge.sections?.[0];
    if (!section) {
      return [];
    }
    const label = edge.labels?.[0];
    const labelPosition = getLabelPosition(label, section);
    return [
      {
        id: edge.id ?? `${edge.sources?.[0]}-${edge.targets?.[0]}`,
        source: edge.sources?.[0] ?? "",
        target: edge.targets?.[0] ?? "",
        path: buildSectionPath(section),
        label: label?.text,
        labelX: labelPosition?.x,
        labelY: labelPosition?.y,
      },
    ];
  });

  const nodeMaxX = nodes.reduce(
    (max, node) => Math.max(max, node.position.x + node.width),
    0,
  );
  const nodeMaxY = nodes.reduce(
    (max, node) => Math.max(max, node.position.y + node.height),
    0,
  );
  const labelMaxX = edges.reduce(
    (max, edge) => Math.max(max, (edge.labelX ?? 0) + (edge.label ? estimateLabelWidth(edge.label) / 2 : 0)),
    0,
  );
  const labelMaxY = edges.reduce(
    (max, edge) => Math.max(max, (edge.labelY ?? 0) + 14),
    0,
  );

  return {
    nodes,
    edges,
    width: Math.max(420, Math.ceil(Math.max(nodeMaxX, labelMaxX) + graphPadding)),
    height: Math.max(260, Math.ceil(Math.max(nodeMaxY, labelMaxY) + graphPadding)),
  };
}

function createEdgeLabel(text: string): ElkLabel {
  return {
    text,
    width: estimateLabelWidth(text),
    height: 22,
  };
}

function estimateLabelWidth(text: string): number {
  return Math.min(168, Math.max(44, text.length * 7 + 18));
}

function buildSectionPath(section: NonNullable<ElkExtendedEdge["sections"]>[number]): string {
  const points = [section.startPoint, ...(section.bendPoints ?? []), section.endPoint];
  return points
    .map((point, index) =>
      index === 0 ? `M ${point.x} ${point.y}` : `L ${point.x} ${point.y}`,
    )
    .join(" ");
}

function getLabelPosition(
  label: ElkLabel | undefined,
  section: NonNullable<ElkExtendedEdge["sections"]>[number],
) {
  if (label?.x != null && label?.y != null && label.width != null && label.height != null) {
    return {
      x: label.x + label.width / 2,
      y: label.y + label.height / 2,
    };
  }
  const points = [section.startPoint, ...(section.bendPoints ?? []), section.endPoint];
  const midpoint = findPolylineMidpointWithSegment(points);
  if (!midpoint) {
    return undefined;
  }
  const isMostlyVertical = Math.abs(midpoint.dy) >= Math.abs(midpoint.dx);
  return {
    x: midpoint.x + (isMostlyVertical ? labelOffset : 0),
    y: midpoint.y + (isMostlyVertical ? 0 : -labelOffset),
  };
}

type PolylineMidpoint = {
  x: number;
  y: number;
  dx: number;
  dy: number;
};

function findPolylineMidpointWithSegment(
  points: ElkPoint[],
): PolylineMidpoint | undefined {
  if (points.length < 2) {
    return undefined;
  }
  const segments = points.slice(0, -1).map((point, index) => {
    const next = points[index + 1];
    const length = Math.hypot(next.x - point.x, next.y - point.y);
    return { start: point, end: next, length };
  });
  const total = segments.reduce((sum, segment) => sum + segment.length, 0);
  if (total === 0) {
    return {
      x: points[0].x,
      y: points[0].y,
      dx: 0,
      dy: 0,
    };
  }
  let traversed = 0;
  const halfway = total / 2;
  for (const segment of segments) {
    if (traversed + segment.length >= halfway) {
      const offset = (halfway - traversed) / segment.length;
      return {
        x: segment.start.x + (segment.end.x - segment.start.x) * offset,
        y: segment.start.y + (segment.end.y - segment.start.y) * offset,
        dx: segment.end.x - segment.start.x,
        dy: segment.end.y - segment.start.y,
      };
    }
    traversed += segment.length;
  }
  const last = segments[segments.length - 1];
  return {
    x: last.end.x,
    y: last.end.y,
    dx: last.end.x - last.start.x,
    dy: last.end.y - last.start.y,
  };
}

function formatEdgeLabel(edge: ConfigDraftDto["topology"]["edges"][number]): string | undefined {
  const kind = edge.when?.kind?.trim();
  if (!kind) {
    return undefined;
  }
  if (kind === "else") {
    return "else";
  }
  if (kind === "when") {
    const field = String(edge.when?.field ?? "").trim();
    const equals = edge.when?.equals;
    if (!field) {
      return "when";
    }
    if (equals == null || equals === "") {
      return field;
    }
    const formattedEquals =
      typeof equals === "string" ? equals : JSON.stringify(equals);
    return `${field} = ${formattedEquals}`;
  }
  return kind;
}
