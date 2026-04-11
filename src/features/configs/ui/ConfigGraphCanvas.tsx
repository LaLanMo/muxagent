import "@xyflow/react/dist/style.css";
import {
  BaseEdge,
  Handle,
  MarkerType,
  Position,
  ReactFlow,
  type Edge,
  type EdgeProps,
  type Node,
  type NodeProps,
  type NodeTypes,
  type EdgeTypes,
} from "@xyflow/react";
import { useMemo } from "react";
import type { ConfigGraphLayout } from "@/features/configs/model/config-graph";

type ConfigGraphCanvasProps = {
  graph: ConfigGraphLayout;
  selectedNodeName?: string;
  onSelectNode: (nodeName: string) => void;
};

type ConfigGraphNodeData = {
  name: string;
  typeLabel: string;
  isEntry: boolean;
  selected: boolean;
};

type ConfigGraphEdgeData = {
  path: string;
  label?: string;
  labelX?: number;
  labelY?: number;
};

const nodeTypes: NodeTypes = {
  configNode: ConfigNodeView,
};

const edgeTypes: EdgeTypes = {
  configEdge: ConfigEdgeView,
};

type ConfigGraphPalette = {
  edgeStroke: string;
  edgeText: string;
  edgeBgFill: string;
  edgeBgStroke: string;
};

const defaultGraphPalette: ConfigGraphPalette = {
  edgeStroke: "#b9afa8",
  edgeText: "#7a6f68",
  edgeBgFill: "#fffdfb",
  edgeBgStroke: "#d1c8c2",
};

function resolveGraphPalette(): ConfigGraphPalette {
  if (typeof window === "undefined") {
    return defaultGraphPalette;
  }
  const styles = getComputedStyle(document.documentElement);
  const read = (name: string, fallback: string) =>
    styles.getPropertyValue(name).trim() || fallback;
  return {
    edgeStroke: read("--color-border-strong", defaultGraphPalette.edgeStroke),
    edgeText: read("--color-text-tertiary", defaultGraphPalette.edgeText),
    edgeBgFill: read("--color-surface-0", defaultGraphPalette.edgeBgFill),
    edgeBgStroke: read("--color-border", defaultGraphPalette.edgeBgStroke),
  };
}

export function ConfigGraphCanvas({
  graph,
  selectedNodeName,
  onSelectNode,
}: ConfigGraphCanvasProps) {
  const palette = useMemo(resolveGraphPalette, []);
  const nodes = useMemo<Node<ConfigGraphNodeData>[]>(
    () =>
      graph.nodes.map((node) => ({
        id: node.id,
        type: "configNode",
        position: node.position,
        draggable: false,
        selectable: false,
        data: {
          name: node.name,
          typeLabel: node.typeLabel,
          isEntry: node.isEntry,
          selected: node.name === selectedNodeName,
        },
        style: {
          width: node.width,
          height: node.height,
        },
      })),
    [graph.nodes, selectedNodeName],
  );

  const edges = useMemo<Edge<ConfigGraphEdgeData>[]>(
    () =>
      graph.edges.map((edge) => ({
        id: edge.id,
        type: "configEdge",
        source: edge.source,
        target: edge.target,
        selectable: false,
        data: {
          path: edge.path,
          label: edge.label,
          labelX: edge.labelX,
          labelY: edge.labelY,
        },
        markerEnd: {
          type: MarkerType.ArrowClosed,
          color: palette.edgeStroke,
          width: 20,
          height: 20,
        },
      })),
    [graph.edges, palette.edgeStroke],
  );

  return (
    <div
      className="config-graph-flow"
      style={{
        width: `${graph.width}px`,
        height: `${graph.height}px`,
        minWidth: "100%",
        minHeight: "100%",
      }}
    >
      <ReactFlow
        edges={edges}
        edgeTypes={edgeTypes}
        elementsSelectable={false}
        nodeTypes={nodeTypes}
        nodes={nodes}
        nodesConnectable={false}
        nodesDraggable={false}
        onlyRenderVisibleElements={false}
        defaultViewport={{ x: 0, y: 0, zoom: 1 }}
        onNodeClick={(_, node) => onSelectNode(node.id)}
        panOnDrag={false}
        preventScrolling={false}
        proOptions={{ hideAttribution: true }}
        zoomOnDoubleClick={false}
        zoomOnPinch={false}
        zoomOnScroll={false}
      />
    </div>
  );
}

function ConfigNodeView({
  data,
}: NodeProps<Node<ConfigGraphNodeData, "configNode">>) {
  return (
    <div
      className={`config-flow-node${data.selected ? " is-selected" : ""}${
        data.isEntry ? " is-entry" : ""
      }`}
      data-node-type={data.typeLabel}
      data-testid={`config-graph-node-${data.name}`}
    >
      <Handle
        className="config-flow-node__handle"
        isConnectable={false}
        position={Position.Top}
        type="target"
      />
      <Handle
        className="config-flow-node__handle"
        isConnectable={false}
        position={Position.Bottom}
        type="source"
      />
      {data.isEntry ? (
        <span
          className="config-flow-node__entry-chip"
          data-testid={`config-graph-node-entry-${data.name}`}
        >
          ENTRY
        </span>
      ) : null}
      <div className="config-flow-node__card">
        <div className="config-flow-node__body">
          <span className="config-flow-node__type-dot" aria-hidden="true" />
          <span
            className="config-flow-node__name"
            data-testid={`config-graph-node-name-${data.name}`}
          >
            {data.name}
          </span>
        </div>
      </div>
    </div>
  );
}

function ConfigEdgeView({
  id,
  markerEnd,
  data,
}: EdgeProps<Edge<ConfigGraphEdgeData, "configEdge">>) {
  if (!data?.path) {
    return null;
  }
  const palette = resolveGraphPalette();
  return (
    <BaseEdge
      className="config-flow-edge"
      id={id}
      label={data.label}
      labelBgBorderRadius={6}
      labelBgPadding={[3, 6]}
      labelBgStyle={{
        fill: palette.edgeBgFill,
        stroke: palette.edgeBgStroke,
        strokeWidth: 1,
      }}
      labelShowBg={Boolean(data.label)}
      labelStyle={{
        fill: palette.edgeText,
        fontFamily: "var(--font-ui)",
        fontSize: "11px",
        fontWeight: 500,
      }}
      labelX={data.labelX}
      labelY={data.labelY}
      markerEnd={markerEnd}
      path={data.path}
      style={{
        stroke: palette.edgeStroke,
        strokeLinecap: "square",
        strokeLinejoin: "miter",
        strokeWidth: 1.2,
      }}
    />
  );
}
