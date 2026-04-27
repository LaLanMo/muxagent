import assert from "node:assert/strict";
import test from "node:test";
import {
  buildChatTranscriptMessages,
  useChatStore,
} from "@/state/chat-store";
import type { AgentChatEventDto } from "@/rpc/types";

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

  useChatStore.getState().appendEvent(sessionStatusEvent);
  useChatStore.getState().appendEvent(runEvent);

	assert.equal(useChatStore.getState().sessions.length, 1);
	assert.deepEqual(useChatStore.getState().sessions[0], {
    sessionId: "session-1",
    cwd: "/tmp/workspace",
    title: "Local chat",
    runtime: "codex",
    updatedAt: "2026-04-27T00:00:01.000Z",
    status: "running",
    configOptions: undefined,
	});
	assert.equal(useChatStore.getState().eventsBySessionId["session-1"]?.length, 2);
});

test("chat store keeps request-scoped replay events with zero seq", () => {
  useChatStore.getState().reset();

  useChatStore.getState().appendEvent({
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
  });
  useChatStore.getState().appendEvent({
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
  });

  const events = useChatStore.getState().eventsBySessionId["session-1"] ?? [];
  assert.equal(events.length, 2);
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
