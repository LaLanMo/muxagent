# Agentchat Ownership Contract

This document defines the ownership boundary for Agent Chat across daemon, app-server,
desktop, relay, and mobile. It is intentionally close to `cli/internal/agentchat`
because this package owns the transport-neutral chat semantics. Surfaces may adapt
the protocol, but they must not create a second source of truth.

## Canonical Contract

- `cli/internal/appwire` is the canonical wire contract.
- `cli/internal/agentchat.Service` is the canonical owner of agent chat session
  lifecycle and event semantics.
- Daemon/app-server own session metadata, run status, config, stream cursor, and
  committed transcript events.
- Desktop owns draft text, local request pending state, local request errors, and
  local optimistic echo only.
- Relay/mobile consume the same appwire methods and event semantics. Local desktop
  transport must preserve the same replay/cursor meaning that relay/mobile get from
  `events.head`, `events.resync`, and `events.resyncPage`.

## Source Of Truth

| Source | May update session truth? | May update transcript? | May clear pending? | Notes |
| --- | --- | --- | --- | --- |
| `session.create` result | Yes, create metadata only | Empty session is loaded | Create pending only | `app.sessionId` is canonical; `acp.sessionId` must be empty-or-equal and normalized by the adapter. |
| `session.list` included row | Yes | No | Can reconcile stop/config/mode if row is authoritative | Omission is not delete, idle, or terminal. |
| `session.load` result | Yes, loaded metadata/config snapshot | Opens scoped replay gate | Load enters `acceptingReplay` | The result does not by itself mark transcript replay complete. |
| Positive `seq > 0` event | Yes | Yes | Yes, if event is post-baseline evidence | Duplicate positive seq must be dropped before any mutation. |
| Scoped replay `seq <= 0` event | No | Staged transcript only | No | Only the active load scope can accept it. |
| `history.complete` | No | Commits active replay snapshot | Load pending only | Unscoped or stale completion markers are ignored. |
| `session.prompt` acknowledgement | No | No | `submitting -> awaitingLiveEvidence` only | RPC failure must preserve draft and must not add a committed user message. |
| `session.cancel` acknowledgement | No | No | `canceling -> reconciling` only | Send stays disabled until terminal truth or authoritative reconciliation. |
| `session.setMode` / `session.setConfigOption` acknowledgement | No | No | `submitting -> awaitingTruth` only | Matching authoritative truth clears pending; acknowledgement does not write current value. |

## Event Semantics

Events are classified before they mutate any state:

- Positive `seq > 0` events are live authoritative events.
- Duplicate positive seq events are ignored before transcript, session, or config
  mutation.
- `seq <= 0` events are request-scoped replay events. They can hydrate a transcript
  snapshot for the active `session.load`, but they must not update current session
  status, metadata, config, or request pending state.
- `history.complete` is the completion barrier for a scoped replay. A load without
  `history.complete` is partial and must be discardable or retryable without
  accumulating duplicate transcript items.

`appwire.Event` must round-trip through JSON. Any custom `MarshalJSON` envelope must
have a matching `UnmarshalJSON`, and tests must cover every event type that the
daemon/app-server local stream decodes.

## Stream Cursor Semantics

Local desktop event streaming must carry the same replay state that remote clients
already receive through appwire replay methods.

The local event stream should expose stream items with explicit replay status and
cursor state:

```ts
type AgentChatStreamItem =
  | {
      kind: "replay";
      status: "ok" | "gap" | "reset";
      streamEpoch: number;
      replayedThroughSeq: number;
      events: AgentChatEventDto[];
    }
  | {
      kind: "event";
      streamEpoch: number;
      event: AgentChatEventDto;
    };
```

`events.head` returns the current `streamEpoch` and the latest positive event seq as
`replayedThroughSeq`.

- A subscriber that wants only new events starts with `afterSeq =
  replayedThroughSeq`.
- A subscriber that wants replay starts with `afterSeq = 0` and handles the returned
  replay `status`.
- Epoch mismatch, an unreplayable old cursor, or a future cursor must be surfaced as
  `gap` or `reset`. App-server must not silently treat that stream as continuous.

## Session Id Authority

The app session id is the only id that desktop, mobile, relay, daemon, and app-server
use for later RPCs.

- `session.create` returns `app.sessionId`.
- `acp.sessionId` may be present for ACP compatibility, but it must be empty or equal
  to `app.sessionId` after adapter normalization.
- A non-empty mismatched `acp.sessionId` is a protocol error unless a future design
  explicitly introduces an app-id to acp-id mapping layer.
- UI and store code must not choose `acp.sessionId` as the canonical id.

## Desktop State Boundary

Desktop state should keep these concepts separate:

- `sessionTruth`: daemon-owned session metadata, status, cwd/runtime/title, and
  committed config options.
- `transcriptTruth`: committed scoped replay snapshot plus positive live events.
- `loadReplayStage`: active load request token, phase, and staged replay events.
- `sessionPending`: prompt, stop, load, mode, model, and config pending state
  machines.

Mutation acknowledgements are not session truth. Desktop may use them only to move a
pending request to the next pending phase. Current status/config is updated only by
authoritative sources listed in the source-of-truth table.

Local optimistic echo is a view artifact. It is removed only by positive live user
echo after the prompt baseline seq, never by replay text or event array length.

## Fixture Obligation

Desktop fixture runtime is a contract mirror, not a convenience mock.

- `session.load` replay uses `seq: 0`, does not advance `events.head`, does not
  persist durable events, and emits `history.complete` only when replay is complete.
- `session.cancel` returns acknowledgement only. It must not immediately emit idle,
  `run.finished`, or another terminal event.
- `session.create` requires the same required fields as appwire and returns the same
  config option shape as the real service.
- `configChanged.app.values` is flat `[]SessionConfigValue`; grouped display options
  are preserved in session config options, not in the config changed event payload.
- Test scenarios should cover prompt failure, partial load failure, delayed prompt,
  cancel acknowledgement before terminal truth, and failed mode/config mutation.

## Verification Gates

Contract changes should be verified in this order:

1. `cd cli && go test ./internal/appwire ./internal/agentchat ./internal/appserver ./internal/daemon`
2. `cd desktop && pnpm typecheck`
3. `cd desktop && pnpm test:unit`
4. Fixture Playwright for load, create, prompt, config, and cancel ack-only behavior.
5. Real Playwright for create, prompt, reload/session.load replay, stop/cancel
   reconciliation, and repeated prompt text after history.

Do not mark an agentchat boundary change complete if it passes fixture tests but has
not been checked against the real daemon/app-server path relevant to that change.
