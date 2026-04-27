import assert from "node:assert/strict";
import test from "node:test";
import {
  buildChatTranscriptMessages,
  useChatStore,
} from "@/state/chat-store";
import type { AgentChatEventDto } from "@/rpc/types";

let loadToken = 0;

function appendCommittedEvent(event: AgentChatEventDto) {
  useChatStore.getState().applyCommittedStreamItem({
    kind: "event",
    streamEpoch: 1,
    event,
  });
}

function loadSessionReplay(args: {
  sessionId: string;
  session?: {
    cwd?: string;
    title?: string;
    runtime?: string;
    updatedAt?: string;
    status?: "idle" | "running" | "waiting_approval" | "error" | "done";
  };
  events?: AgentChatEventDto[];
  complete?: boolean;
}) {
  loadToken += 1;
  const currentSession = useChatStore
    .getState()
    .sessions.find((entry) => entry.sessionId === args.sessionId);
  useChatStore.getState().beginSessionLoad(args.sessionId, loadToken);
  useChatStore.getState().applySessionLoadSnapshot({
    sessionId: args.sessionId,
    loadToken,
    session: {
      sessionId: args.sessionId,
      cwd: args.session?.cwd ?? currentSession?.cwd ?? "/tmp/workspace",
      title: args.session?.title ?? currentSession?.title ?? "Local chat",
      runtime: args.session?.runtime ?? currentSession?.runtime ?? "codex",
      updatedAt:
        args.session?.updatedAt ??
        currentSession?.updatedAt ??
        "2026-04-27T00:00:00.000Z",
      status: args.session?.status ?? currentSession?.status ?? "idle",
      configOptions: currentSession?.configOptions,
    },
    replayEvents: args.events ?? [],
    complete: args.complete ?? true,
  });
}

test("buildChatTranscriptMessages folds message deltas by message id", () => {
  const messages = buildChatTranscriptMessages(
    [
      {
        type: "message.delta",
        sessionId: "session-1",
        seq: 1,
        at: "2026-04-27T00:00:00.000Z",
        messagePart: {
          app: {
            partId: "part-1",
            messageId: "message-1",
            role: "agent",
            delta: "hel",
            partType: "text",
            fullText: "",
          },
        },
      },
      {
        type: "message.delta",
        sessionId: "session-1",
        seq: 2,
        at: "2026-04-27T00:00:01.000Z",
        messagePart: {
          app: {
            partId: "part-1",
            messageId: "message-1",
            role: "agent",
            delta: "lo",
            partType: "text",
            fullText: "",
          },
        },
      },
    ],
    [],
  );

  assert.deepEqual(messages, [
    {
      id: "message-1",
      role: "agent",
      text: "hello",
      at: "2026-04-27T00:00:01.000Z",
    },
  ]);
});

test("chat store derives sessions from agentchat events without task state", () => {
  useChatStore.getState().reset();

  const sessionStatusEvent: AgentChatEventDto = {
    type: "session.status",
    sessionId: "session-1",
    seq: 1,
    at: "2026-04-27T00:00:00.000Z",
    sessionStatus: {
      app: {
        id: "session-1",
        title: "Local chat",
        status: "idle",
        runtime: "codex",
        cwd: "/tmp/workspace",
        updatedAt: "2026-04-27T00:00:00.000Z",
      },
    },
  };
  const runEvent: AgentChatEventDto = {
    type: "message.delta",
    sessionId: "session-1",
    seq: 2,
    at: "2026-04-27T00:00:01.000Z",
  };

  appendCommittedEvent(sessionStatusEvent);
  appendCommittedEvent(runEvent);

  assert.equal(useChatStore.getState().sessions.length, 1);
  assert.deepEqual(useChatStore.getState().sessions[0], {
    sessionId: "session-1",
    cwd: "/tmp/workspace",
    title: "Local chat",
    runtime: "codex",
    updatedAt: "2026-04-27T00:00:01.000Z",
    status: "idle",
    configOptions: undefined,
  });
  assert.equal(useChatStore.getState().eventsBySessionId["session-1"]?.length, 2);
});

test("chat store keeps request-scoped replay events with zero seq", () => {
  useChatStore.getState().reset();

  loadSessionReplay({
    sessionId: "session-1",
    events: [
      {
        type: "message.delta",
        sessionId: "session-1",
        seq: 0,
        at: "2026-04-27T00:00:00.000Z",
        messagePart: {
          app: {
            partId: "user-part",
            messageId: "user-message",
            role: "user",
            delta: "hello",
            partType: "text",
            fullText: "",
          },
        },
      },
      {
        type: "message.delta",
        sessionId: "session-1",
        seq: 0,
        at: "2026-04-27T00:00:01.000Z",
        messagePart: {
          app: {
            partId: "agent-part",
            messageId: "agent-message",
            role: "agent",
            delta: "hi",
            partType: "text",
            fullText: "",
          },
        },
      },
    ],
  });

  const events = useChatStore.getState().eventsBySessionId["session-1"] ?? [];
  assert.equal(events.length, 2);
  assert.equal(useChatStore.getState().sessions.length, 1);
  assert.deepEqual(buildChatTranscriptMessages(events, []), [
    {
      id: "user-message",
      role: "user",
      text: "hello",
      at: "2026-04-27T00:00:00.000Z",
    },
    {
      id: "agent-message",
      role: "agent",
      text: "hi",
      at: "2026-04-27T00:00:01.000Z",
    },
  ]);
});

test("chat store marks session load complete from load snapshot", () => {
  useChatStore.getState().reset();

  loadSessionReplay({ sessionId: "session-1" });

  assert.equal(useChatStore.getState().loadedSessionIds["session-1"], true);
  assert.equal(useChatStore.getState().loadingSessionIds["session-1"], undefined);
  assert.equal(
    useChatStore.getState().eventsBySessionId["session-1"]?.length ?? 0,
    0,
  );
});

test("chat store ignores stale load snapshots by token", () => {
  useChatStore.getState().reset();
  useChatStore.getState().beginSessionLoad("session-1", 1);

  useChatStore.getState().applySessionLoadSnapshot({
    sessionId: "session-1",
    loadToken: 2,
    session: {
      sessionId: "session-1",
      cwd: "/tmp/workspace",
      title: "Local chat",
      runtime: "codex",
      updatedAt: "2026-04-27T00:00:00.000Z",
      status: "idle",
    },
    replayEvents: [],
    complete: true,
  });

  assert.equal(useChatStore.getState().loadedSessionIds["session-1"], undefined);
  assert.equal(useChatStore.getState().loadingSessionIds["session-1"], 1);
});

test("chat store ignores request-scoped replay status as run truth", () => {
  useChatStore.getState().reset();
  useChatStore.getState().mergeCreatedSession({
    sessionId: "session-1",
    cwd: "/tmp/workspace",
    title: "Local chat",
    runtime: "codex",
    updatedAt: "2026-04-27T00:00:00.000Z",
    status: "running",
    configOptions: [
      {
        id: "mode",
        name: "Mode",
        category: "mode",
        type: "select",
        currentValue: "read-only",
        options: [],
      },
    ],
  });

  loadSessionReplay({
    sessionId: "session-1",
    session: {
      status: "running",
      updatedAt: "2026-04-27T00:00:00.000Z",
    },
    events: [
      {
        type: "session.status",
        sessionId: "session-1",
        seq: 0,
        at: "2026-04-27T00:00:01.000Z",
        sessionStatus: {
          app: {
            id: "session-1",
            status: "idle",
            updatedAt: "2026-04-27T00:00:01.000Z",
          },
        },
      },
      {
        type: "mode.changed",
        sessionId: "session-1",
        seq: 0,
        at: "2026-04-27T00:00:02.000Z",
        modeChanged: {
          app: {
            currentModeId: "full-access",
          },
        },
      },
    ],
  });

  const session = useChatStore.getState().sessions[0];
  assert.equal(session?.status, "running");
  assert.equal(session?.updatedAt, "2026-04-27T00:00:00.000Z");
  assert.equal(session?.configOptions?.[0]?.currentValue, "read-only");
  assert.equal(useChatStore.getState().eventsBySessionId["session-1"]?.length, 2);
});

test("chat store replaces scoped replay snapshot when load completes", () => {
  useChatStore.getState().reset();
  useChatStore.getState().mergeCreatedSession({
    sessionId: "session-1",
    cwd: "/tmp/workspace",
    title: "Local chat",
    runtime: "codex",
    updatedAt: "2026-04-27T00:00:00.000Z",
    status: "idle",
  });
  appendCommittedEvent({
    type: "message.delta",
    sessionId: "session-1",
    seq: 10,
    at: "2026-04-27T00:00:00.500Z",
  });
  appendCommittedEvent({
    type: "message.delta",
    sessionId: "session-1",
    seq: 0,
    at: "2026-04-27T00:00:01.000Z",
    messagePart: {
      app: {
        partId: "old-part",
        messageId: "old-replay",
        role: "user",
        delta: "old replay",
        partType: "text",
        fullText: "",
      },
    },
  });

  loadSessionReplay({
    sessionId: "session-1",
    events: [
      {
        type: "message.delta",
        sessionId: "session-1",
        seq: 0,
        at: "2026-04-27T00:00:02.000Z",
        messagePart: {
          app: {
            partId: "new-part",
            messageId: "new-replay",
            role: "user",
            delta: "new replay",
            partType: "text",
            fullText: "",
          },
        },
      },
    ],
  });

  const events = useChatStore.getState().eventsBySessionId["session-1"] ?? [];
  assert.deepEqual(
    events.map((event) => event.messagePart?.app.messageId).filter(Boolean),
    ["new-replay"],
  );
  assert.deepEqual(
    events.map((event) => event.seq),
    [10, 0],
  );
  assert.equal(useChatStore.getState().loadedSessionIds["session-1"], true);
});

test("chat store clears load token when load fails", () => {
  useChatStore.getState().reset();
  useChatStore.getState().mergeCreatedSession({
    sessionId: "session-1",
    cwd: "/tmp/workspace",
    title: "Local chat",
    runtime: "codex",
    updatedAt: "2026-04-27T00:00:00.000Z",
    status: "idle",
  });
  appendCommittedEvent({
    type: "message.delta",
    sessionId: "session-1",
    seq: 1,
    at: "2026-04-27T00:00:00.500Z",
  });

  useChatStore.getState().beginSessionLoad("session-1", 1);
  appendCommittedEvent({
    type: "message.delta",
    sessionId: "session-1",
    seq: 2,
    at: "2026-04-27T00:00:02.500Z",
  });
  useChatStore.getState().failSessionLoad("session-1", 1);

  const events = useChatStore.getState().eventsBySessionId["session-1"] ?? [];
  assert.deepEqual(
    events.map((event) => event.seq),
    [1, 2],
  );
  assert.equal(useChatStore.getState().loadedSessionIds["session-1"], undefined);
  assert.equal(useChatStore.getState().loadingSessionIds["session-1"], undefined);
});

test("chat transcript includes run failed events", () => {
  const messages = buildChatTranscriptMessages(
    [
      {
        type: "run.failed",
        sessionId: "session-1",
        seq: 7,
        at: "2026-04-27T00:00:02.000Z",
        runFailed: {
          app: {
            error: {
              code: "prompt_error",
              message: "The agent stopped unexpectedly",
            },
          },
        },
      },
    ],
    [],
  );

  assert.deepEqual(messages, [
    {
      id: "run-failed-7",
      role: "system",
      text: "The agent stopped unexpectedly",
      at: "2026-04-27T00:00:02.000Z",
    },
  ]);
});

test("chat transcript gives replayed run failed events unique ids", () => {
  const messages = buildChatTranscriptMessages(
    [
      {
        type: "run.failed",
        sessionId: "session-1",
        seq: 0,
        at: "2026-04-27T00:00:02.000Z",
        runFailed: {
          app: {
            error: {
              code: "prompt_error",
              message: "First failure",
            },
          },
        },
      },
      {
        type: "run.failed",
        sessionId: "session-1",
        seq: 0,
        at: "2026-04-27T00:00:02.000Z",
        runFailed: {
          app: {
            error: {
              code: "prompt_error",
              message: "Second failure",
            },
          },
        },
      },
    ],
    [],
  );

  assert.deepEqual(
    messages.map((message) => message.id),
    [
      "run-failed-2026-04-27T00:00:02.000Z-0",
      "run-failed-2026-04-27T00:00:02.000Z-1",
    ],
  );
});

test("chat transcript only dedupes one local message for each matching user echo", () => {
  const messages = buildChatTranscriptMessages(
    [
      {
        type: "message.delta",
        sessionId: "session-1",
        seq: 1,
        at: "2026-04-27T00:00:01.000Z",
        messagePart: {
          app: {
            partId: "echo-part",
            messageId: "echo-message",
            role: "user",
            delta: "same prompt",
            partType: "text",
            fullText: "",
          },
        },
      },
    ],
    [
      {
        id: "local-1",
        role: "user",
        text: "same prompt",
        at: "2026-04-27T00:00:00.000Z",
        local: true,
      },
      {
        id: "local-2",
        role: "user",
        text: "same prompt",
        at: "2026-04-27T00:00:02.000Z",
        local: true,
      },
    ],
  );

  assert.deepEqual(
    messages.map((message) => message.id),
    ["echo-message", "local-2"],
  );
});

test("chat transcript keeps repeated local prompt when only historical text matches", () => {
  const historicalEvent: AgentChatEventDto = {
    type: "message.delta",
    sessionId: "session-1",
    seq: 1,
    at: "2026-04-27T00:00:00.000Z",
    messagePart: {
      app: {
        partId: "history-part",
        messageId: "history-message",
        role: "user",
        delta: "repeat prompt",
        partType: "text",
        fullText: "",
      },
    },
  };
  const submittedLocal = {
    id: "local-new",
    role: "user",
    text: "repeat prompt",
    at: "2026-04-27T00:00:01.000Z",
    local: true,
    submitEventBaseline: 1,
  };

  assert.deepEqual(
    buildChatTranscriptMessages([historicalEvent], [submittedLocal]).map(
      (message) => message.id,
    ),
    ["history-message", "local-new"],
  );

  assert.deepEqual(
    buildChatTranscriptMessages(
      [
        historicalEvent,
        {
          type: "message.delta",
          sessionId: "session-1",
          seq: 2,
          at: "2026-04-27T00:00:02.000Z",
          messagePart: {
            app: {
              partId: "echo-part",
              messageId: "echo-message",
              role: "user",
              delta: "repeat prompt",
              partType: "text",
              fullText: "",
            },
          },
        },
      ],
      [submittedLocal],
    ).map((message) => message.id),
    ["history-message", "echo-message"],
  );
});

test("chat transcript does not dedupe submitted local prompt against scoped replay", () => {
  const replayEvent: AgentChatEventDto = {
    type: "message.delta",
    sessionId: "session-1",
    seq: 0,
    at: "2026-04-27T00:00:01.000Z",
    messagePart: {
      app: {
        partId: "replay-part",
        messageId: "replay-message",
        role: "user",
        delta: "repeat prompt",
        partType: "text",
        fullText: "",
      },
    },
  };
  const submittedLocal = {
    id: "local-new",
    role: "user",
    text: "repeat prompt",
    at: "2026-04-27T00:00:02.000Z",
    local: true,
    submitEventBaseline: 0,
  };

  assert.deepEqual(
    buildChatTranscriptMessages([replayEvent], [submittedLocal]).map(
      (message) => message.id,
    ),
    ["replay-message", "local-new"],
  );
});

test("chat store ignores duplicate seq events before mutating session state", () => {
  useChatStore.getState().reset();
  useChatStore.getState().mergeCreatedSession({
    sessionId: "session-1",
    cwd: "/tmp/workspace",
    title: "Local chat",
    runtime: "codex",
    updatedAt: "2026-04-27T00:00:00.000Z",
    status: "idle",
    configOptions: [
      {
        id: "model",
        name: "Model",
        category: "model",
        type: "select",
        currentValue: "sonnet",
        options: [
          { value: "sonnet", name: "Sonnet" },
          { value: "opus", name: "Opus" },
        ],
      },
      {
        id: "mode",
        name: "Mode",
        category: "mode",
        type: "select",
        currentValue: "default",
        options: [],
      },
    ],
  });

  appendCommittedEvent({
    type: "message.delta",
    sessionId: "session-1",
    seq: 7,
    at: "2026-04-27T00:00:01.000Z",
  });
  appendCommittedEvent({
    type: "run.finished",
    sessionId: "session-1",
    seq: 7,
    at: "2026-04-27T00:00:02.000Z",
    runFinished: {
      app: {
        stopReason: "end_turn",
      },
    },
  });
  appendCommittedEvent({
    type: "mode.changed",
    sessionId: "session-1",
    seq: 8,
    at: "2026-04-27T00:00:03.000Z",
    modeChanged: {
      app: {
        currentModeId: "read-only",
      },
    },
  });
  appendCommittedEvent({
    type: "mode.changed",
    sessionId: "session-1",
    seq: 8,
    at: "2026-04-27T00:00:04.000Z",
    modeChanged: {
      app: {
        currentModeId: "default",
      },
    },
  });

  const session = useChatStore.getState().sessions[0];
  assert.equal(session.status, "idle");
  assert.equal(session.configOptions?.[1]?.currentValue, "read-only");
  assert.equal(useChatStore.getState().eventsBySessionId["session-1"]?.length, 2);
});

test("chat store treats session list as a catalog page, not full replacement", () => {
  useChatStore.getState().reset();
  useChatStore.getState().mergeCreatedSession({
    sessionId: "session-1",
    cwd: "/tmp/workspace",
    title: "Existing chat",
    runtime: "codex",
    updatedAt: "2026-04-27T00:00:00.000Z",
    status: "idle",
  });

  useChatStore.getState().mergeSessionCatalogPage([]);

  assert.equal(useChatStore.getState().sessions[0]?.sessionId, "session-1");
});

test("chat store accepts catalog truth even when metadata updatedAt is older", () => {
  useChatStore.getState().reset();
  appendCommittedEvent({
    type: "message.delta",
    sessionId: "session-1",
    seq: 1,
    at: "2026-04-27T00:00:02.000Z",
  });

  useChatStore.getState().mergeSessionCatalogPage([
    {
      sessionId: "session-1",
      cwd: "/tmp/workspace",
      title: "Stale list title",
      runtime: "codex",
      updatedAt: "2026-04-27T00:00:01.000Z",
      status: "idle",
      configOptions: [
        {
          id: "mode",
          name: "Mode",
          category: "mode",
          type: "select",
          currentValue: "read-only",
          options: [],
        },
      ],
    },
  ]);

  const session = useChatStore.getState().sessions[0];
  assert.equal(session.status, "idle");
  assert.equal(session.updatedAt, "2026-04-27T00:00:02.000Z");
  assert.equal(session.configOptions?.[0]?.currentValue, "read-only");
});

test("chat store applies config change events from agentchat", () => {
  useChatStore.getState().reset();
  useChatStore.getState().mergeCreatedSession({
    sessionId: "session-1",
    cwd: "/tmp/workspace",
    title: "Local chat",
    runtime: "codex",
    updatedAt: "2026-04-27T00:00:00.000Z",
    status: "idle",
    configOptions: [
      {
        id: "mode",
        name: "Mode",
        category: "mode",
        type: "select",
        currentValue: "default",
        options: [],
      },
      {
        id: "model",
        name: "Model",
        category: "model",
        type: "select",
        currentValue: "sonnet",
        options: [],
      },
    ],
  });

  appendCommittedEvent({
    type: "mode.changed",
    sessionId: "session-1",
    seq: 2,
    at: "2026-04-27T00:00:02.000Z",
    modeChanged: {
      app: {
        currentModeId: "read-only",
      },
    },
  });
  appendCommittedEvent({
    type: "model.changed",
    sessionId: "session-1",
    seq: 3,
    at: "2026-04-27T00:00:03.000Z",
    configChanged: {
      app: {
        configId: "model",
        category: "model",
        currentValue: "opus",
        values: [
          { value: "sonnet", name: "Sonnet" },
          { value: "opus", name: "Opus" },
        ],
      },
    },
  });

  const session = useChatStore.getState().sessions[0];
  assert.equal(session.configOptions?.[0]?.currentValue, "read-only");
  assert.equal(session.configOptions?.[1]?.currentValue, "opus");
  assert.deepEqual(session.configOptions?.[1]?.options, [
    { value: "sonnet", name: "Sonnet" },
    { value: "opus", name: "Opus" },
  ]);
});

test("chat store creates a mode config stub from mode changed events", () => {
  useChatStore.getState().reset();
  appendCommittedEvent({
    type: "mode.changed",
    sessionId: "session-1",
    seq: 1,
    at: "2026-04-27T00:00:00.000Z",
    modeChanged: {
      app: {
        currentModeId: "read-only",
      },
    },
  });

  assert.deepEqual(useChatStore.getState().sessions[0]?.configOptions, [
    {
      id: "mode",
      name: "Mode",
      category: "mode",
      type: "select",
      currentValue: "read-only",
      options: [],
    },
  ]);
});
