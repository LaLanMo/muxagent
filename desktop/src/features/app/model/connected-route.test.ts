import assert from "node:assert/strict";
import test from "node:test";
import { connectedPhaseRouteDecision } from "@/features/app/model/connected-route";

test("connected phase routes stay on the requested URL while bootstrap is pending", () => {
  assert.equal(connectedPhaseRouteDecision("idle", true), "pending");
  assert.equal(connectedPhaseRouteDecision("connecting", false), "pending");
});

test("connected phase routes render only after connection succeeds", () => {
  assert.equal(connectedPhaseRouteDecision("connected", false), "ready");
  assert.equal(connectedPhaseRouteDecision("failed", false), "redirect");
  assert.equal(connectedPhaseRouteDecision("idle", false), "redirect");
});
