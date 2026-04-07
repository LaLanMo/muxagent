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
  outgoingCount: number;
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

export function ConfigGraphCanvas({
  graph,
  selectedNodeName,
  onSelectNode,
}: ConfigGraphCanvasProps) {
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
          outgoingCount: node.outgoingCount,
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
          color: "#aeb8c4",
          width: 20,
          height: 20,
        },
      })),
    [graph.edges],
  );

  return (
    <div className="config-graph-flow" style={{ width: graph.width, height: graph.height }}>
      <ReactFlow
        edges={edges}
        edgeTypes={edgeTypes}
        elementsSelectable={false}
        fitView
        fitViewOptions={{ duration: 0, maxZoom: 1, minZoom: 0.55, padding: 0.2 }}
        nodeTypes={nodeTypes}
        nodes={nodes}
        nodesConnectable={false}
        nodesDraggable={false}
        onlyRenderVisibleElements={false}
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
    <div className={`config-flow-node${data.selected ? " is-selected" : ""}`}>
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
      <div className="config-flow-node__topline">
        <span className="config-flow-node__name">{data.name}</span>
        {data.isEntry ? <span className="config-flow-node__badge">entry</span> : null}
      </div>
      <span className="config-flow-node__meta">
        {data.typeLabel}
        {data.outgoingCount > 0
          ? ` · ${data.outgoingCount} edge${data.outgoingCount === 1 ? "" : "s"}`
          : ""}
      </span>
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
  return (
    <BaseEdge
      className="config-flow-edge"
      id={id}
      label={data.label}
      labelBgBorderRadius={999}
      labelBgPadding={[4, 8]}
      labelBgStyle={{
        fill: "rgba(255, 255, 255, 0.98)",
        stroke: "rgba(220, 225, 231, 0.98)",
        strokeWidth: 1,
      }}
      labelShowBg={Boolean(data.label)}
      labelStyle={{
        fill: "#7f8894",
        fontFamily: '"JetBrains Mono", ui-monospace, monospace',
        fontSize: 10,
        fontWeight: 650,
      }}
      labelX={data.labelX}
      labelY={data.labelY}
      markerEnd={markerEnd}
      path={data.path}
      style={{
        stroke: "#b6c0cb",
        strokeLinecap: "round",
        strokeLinejoin: "round",
        strokeWidth: 2.25,
      }}
    />
  );
}
