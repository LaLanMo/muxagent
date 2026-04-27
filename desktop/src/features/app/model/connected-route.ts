export type AppConnectionPhase = "idle" | "connecting" | "connected" | "failed";

export type ConnectedPhaseRouteDecision = "ready" | "pending" | "redirect";

export function connectedPhaseRouteDecision(
  phase: AppConnectionPhase,
  bootstrapPending: boolean,
): ConnectedPhaseRouteDecision {
  if (phase === "connected") {
    return "ready";
  }
  if (bootstrapPending || phase === "connecting") {
    return "pending";
  }
  return "redirect";
}
