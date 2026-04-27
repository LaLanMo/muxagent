import { create } from "zustand";
import {
  eventSeq,
  eventSessionId,
  isCommittedAgentChatEvent,
} from "@/domain/agent-chat-events";
import type {
  AgentChatEventDto,
  AgentChatRuntimeDto,
  AgentChatSessionDto,
  AgentChatSessionStatusDto,
  AgentChatStreamItemDto,
} from "@/rpc/types";

export type ChatTranscriptMessage = {
  id: string;
  role: string;
  text: string;
  at?: string;
  local?: boolean;
  submitEventBaseline?: number;
};

type ChatSessionLoadSnapshot = {
  sessionId: string;
  loadToken: number;
  session: Pick<AgentChatSessionDto, "sessionId"> & Partial<AgentChatSessionDto>;
  replayEvents: AgentChatEventDto[];
  complete: boolean;
};

type ChatStoreState = {
  runtimes: AgentChatRuntimeDto[];
  sessions: AgentChatSessionDto[];
  activeSessionId?: string;
  eventsBySessionId: Record<string, AgentChatEventDto[]>;
  committedEventKeysBySessionId: Record<string, Record<string, true>>;
  localMessagesBySessionId: Record<string, ChatTranscriptMessage[]>;
  loadedSessionIds: Record<string, boolean>;
  loadingSessionIds: Record<string, number>;
  loadingRuntimes: boolean;
  loadingSessions: boolean;
  loadingSessionId?: string;
  sendingSessionIds: Record<string, boolean>;
  streamEpoch?: number;
  error?: string;
  setRuntimes: (runtimes: AgentChatRuntimeDto[]) => void;
  mergeSessionCatalogPage: (sessions: AgentChatSessionDto[]) => void;
  mergeCreatedSession: (session: AgentChatSessionDto) => void;
  setActiveSession: (sessionId?: string) => void;
  applyCommittedStreamItem: (item: AgentChatStreamItemDto) => void;
  applySessionLoadSnapshot: (snapshot: ChatSessionLoadSnapshot) => void;
  appendLocalMessage: (
    sessionId: string,
    text: string,
    submitEventBaseline?: number,
  ) => void;
  beginSessionLoad: (sessionId: string, loadToken: number) => void;
  failSessionLoad: (sessionId: string, loadToken: number) => void;
  setLoadingRuntimes: (loading: boolean) => void;
  setLoadingSessions: (loading: boolean) => void;
  setLoadingSession: (sessionId?: string) => void;
  setSendingSession: (sessionId: string, sending: boolean) => void;
  setError: (message?: string) => void;
  reset: () => void;
};

function sortSessions(sessions: AgentChatSessionDto[]): AgentChatSessionDto[] {
  return [...sessions].sort((left, right) =>
    (right.updatedAt || "").localeCompare(left.updatedAt || ""),
  );
}

function shortSessionLabel(sessionId: string): string {
  return sessionId.length > 8 ? sessionId.slice(0, 8) : sessionId;
}

function normalizeTitle(title: string | undefined, sessionId: string): string {
  return title?.trim() || `Session ${shortSessionLabel(sessionId)}`;
}

function latestTimestamp(
  left: string | undefined,
  right: string | undefined,
): string | undefined {
  if (!left) {
    return right;
  }
  if (!right) {
    return left;
  }
  const leftAt = Date.parse(left);
  const rightAt = Date.parse(right);
  if (Number.isFinite(leftAt) && Number.isFinite(rightAt)) {
    return leftAt >= rightAt ? left : right;
  }
  return left >= right ? left : right;
}

function statusFromEvent(
  event: AgentChatEventDto,
): AgentChatSessionStatusDto | undefined {
  if (event.sessionStatus?.app.status) {
    return isCommittedAgentChatEvent(event) ? event.sessionStatus.app.status : undefined;
  }
  return undefined;
}

function mergeSession(
  existing: AgentChatSessionDto | undefined,
  patch: Partial<AgentChatSessionDto> & { sessionId: string },
): AgentChatSessionDto {
  const updatedAt =
    latestTimestamp(patch.updatedAt, existing?.updatedAt) ??
    new Date().toISOString();
  return {
    sessionId: patch.sessionId,
    cwd: patch.cwd ?? existing?.cwd ?? "",
    title: normalizeTitle(patch.title ?? existing?.title, patch.sessionId),
    runtime: patch.runtime ?? existing?.runtime,
    updatedAt,
    status: patch.status ?? existing?.status ?? "idle",
    configOptions: patch.configOptions ?? existing?.configOptions,
  };
}

function mergeSessionCatalogPage(
  existingSessions: AgentChatSessionDto[],
  incomingSessions: AgentChatSessionDto[],
): AgentChatSessionDto[] {
  const bySessionId = new Map<string, AgentChatSessionDto>();
  for (const session of existingSessions) {
    bySessionId.set(session.sessionId, session);
  }
  for (const session of incomingSessions) {
    bySessionId.set(
      session.sessionId,
      mergeSession(bySessionId.get(session.sessionId), session),
    );
  }
  return sortSessions([...bySessionId.values()]);
}

function eventPatch(event: AgentChatEventDto): Partial<AgentChatSessionDto> & {
  sessionId: string;
} | null {
  const sessionId = eventSessionId(event);
  if (!sessionId) {
    return null;
  }
  const sessionStatus = event.sessionStatus?.app;
  return {
    sessionId,
    cwd: sessionStatus?.cwd,
    title: sessionStatus?.title,
    runtime: sessionStatus?.runtime,
    updatedAt: sessionStatus?.updatedAt ?? event.at,
    status: statusFromEvent(event),
  };
}

function configOptionName(category: string | undefined, configId: string): string {
  if (category === "model") {
    return "Model";
  }
  if (category === "mode") {
    return "Mode";
  }
  return configId;
}

function updateConfigOptionValue(
  options: AgentChatSessionDto["configOptions"],
  args: {
    category?: string;
    configId?: string;
    currentValue: string;
    values?: NonNullable<AgentChatEventDto["configChanged"]>["app"]["values"];
  },
): AgentChatSessionDto["configOptions"] | undefined {
  const configId = args.configId?.trim();
  const category = args.category?.trim();
  const currentValue = args.currentValue.trim();
  if (!currentValue) {
    return options;
  }
  const existing = options ?? [];
  let matched = false;
  const next = existing.map((option) => {
    const optionMatches =
      (configId && option.id === configId) ||
      (category && option.category === category);
    if (!optionMatches) {
      return option;
    }
    matched = true;
    return {
      ...option,
      currentValue,
      ...(args.values ? { options: args.values } : {}),
    };
  });
  if (matched || !configId) {
    return matched ? next : options;
  }
  return [
    ...next,
    {
      id: configId,
      name: configOptionName(category, configId),
      category,
      type: "select",
      currentValue,
      options: args.values ?? [],
    },
  ];
}

function configOptionsFromEvent(
  event: AgentChatEventDto,
  existing: AgentChatSessionDto | undefined,
): AgentChatSessionDto["configOptions"] | undefined {
  const modeId = event.modeChanged?.app.currentModeId?.trim();
  if (modeId) {
    return updateConfigOptionValue(existing?.configOptions, {
      category: "mode",
      configId: "mode",
      currentValue: modeId,
    });
  }
  const configChange = event.configChanged?.app;
  if (configChange?.currentValue?.trim()) {
    return updateConfigOptionValue(existing?.configOptions, {
      category: configChange.category,
      configId: configChange.configId,
      currentValue: configChange.currentValue,
      values: configChange.values,
    });
  }
  return undefined;
}

function eventAlreadyPresent(
  eventKeys: Record<string, true> | undefined,
  event: AgentChatEventDto,
  streamEpoch: number | undefined,
): boolean {
  const seq = eventSeq(event);
  if (seq == null || seq <= 0) {
    return false;
  }
  const eventKey = committedEventKey(streamEpoch, seq);
  return Boolean(eventKeys?.[eventKey]);
}

function committedEventKey(
  streamEpoch: number | undefined,
  seq: number,
): string {
  return `${streamEpoch ?? 0}:${seq}`;
}

function nextLocalMessageId(): string {
  return globalThis.crypto?.randomUUID?.() ?? `local-${Date.now()}`;
}

function runFailedMessage(
  event: AgentChatEventDto,
  fallbackIndex: number,
): ChatTranscriptMessage | null {
  const message = event.runFailed?.app.error.message?.trim();
  if (!message) {
    return null;
  }
  const eventSuffix =
    event.seq != null && event.seq > 0
      ? String(event.seq)
      : `${event.at ?? "replay"}-${fallbackIndex}`;
  return {
    id: `run-failed-${eventSuffix}`,
    role: "system",
    text: message,
    at: event.at,
  };
}

function normalizeReplayEvents(
  sessionId: string,
  events: AgentChatEventDto[],
): AgentChatEventDto[] {
  return events
    .filter((event) => {
      const eventSession = eventSessionId(event);
      return !eventSession || eventSession === sessionId;
    })
    .map((event) => ({
      ...event,
      sessionId: event.sessionId || sessionId,
      seq: 0,
    }));
}

function replaceScopedReplayEvents(
  existingEvents: AgentChatEventDto[],
  replayEvents: AgentChatEventDto[],
): AgentChatEventDto[] {
  return [
    ...existingEvents.filter(isCommittedAgentChatEvent),
    ...replayEvents,
  ];
}

function stripCommittedEventsBySession(
  eventsBySessionId: Record<string, AgentChatEventDto[]>,
): Record<string, AgentChatEventDto[]> {
  const next: Record<string, AgentChatEventDto[]> = {};
  for (const [sessionId, events] of Object.entries(eventsBySessionId)) {
    const replayEvents = events.filter((event) => !isCommittedAgentChatEvent(event));
    if (replayEvents.length > 0) {
      next[sessionId] = replayEvents;
    }
  }
  return next;
}

function applyCommittedEventsToState(
  state: ChatStoreState,
  incomingEvents: AgentChatEventDto[],
  options: { resetCommittedEvents?: boolean; streamEpoch?: number } = {},
): Partial<ChatStoreState> {
  let eventsBySessionId = options.resetCommittedEvents
    ? stripCommittedEventsBySession(state.eventsBySessionId)
    : state.eventsBySessionId;
  let committedEventKeysBySessionId = options.resetCommittedEvents
    ? {}
    : state.committedEventKeysBySessionId;
  let sessions = state.sessions;
  let eventsChanged = Boolean(options.resetCommittedEvents);
  let eventKeysChanged = Boolean(options.resetCommittedEvents);
  let sessionsChanged = false;
  const streamEpoch = options.streamEpoch ?? state.streamEpoch;

  for (const event of incomingEvents) {
    if (!isCommittedAgentChatEvent(event)) {
      continue;
    }
    const eventSession = eventSessionId(event);
    if (!eventSession) {
      continue;
    }
    const existingEvents = eventsBySessionId[eventSession] ?? [];
    const existingEventKeys = committedEventKeysBySessionId[eventSession];
    if (eventAlreadyPresent(existingEventKeys, event, streamEpoch)) {
      continue;
    }
    if (eventsBySessionId === state.eventsBySessionId) {
      eventsBySessionId = { ...eventsBySessionId };
    }
    eventsBySessionId[eventSession] = [...existingEvents, event];
    eventsChanged = true;
    if (committedEventKeysBySessionId === state.committedEventKeysBySessionId) {
      committedEventKeysBySessionId = { ...committedEventKeysBySessionId };
    }
    committedEventKeysBySessionId[eventSession] = {
      ...(existingEventKeys ?? {}),
      [committedEventKey(streamEpoch, eventSeq(event) ?? 0)]: true,
    };
    eventKeysChanged = true;

    const patch = eventPatch(event);
    if (!patch) {
      continue;
    }
    const existingSession = sessions.find(
      (entry) => entry.sessionId === eventSession,
    );
    const nextSession = mergeSession(existingSession, {
      ...patch,
      configOptions: configOptionsFromEvent(event, existingSession),
    });
    sessions = existingSession
      ? sessions.map((entry) =>
          entry.sessionId === eventSession ? nextSession : entry,
        )
      : [nextSession, ...sessions];
    sessionsChanged = true;
  }

  return {
    ...(eventsChanged ? { eventsBySessionId } : {}),
    ...(eventKeysChanged ? { committedEventKeysBySessionId } : {}),
    ...(sessionsChanged ? { sessions: sortSessions(sessions) } : {}),
  };
}

export function buildChatTranscriptMessages(
  events: AgentChatEventDto[],
  localMessages: ChatTranscriptMessage[],
): ChatTranscriptMessage[] {
  const messages: Array<
    ChatTranscriptMessage & { eventIndex?: number; eventSeq?: number }
  > = [];
  const byMessageId = new Map<
    string,
    ChatTranscriptMessage & { eventIndex?: number; eventSeq?: number }
  >();

  events.forEach((event, index) => {
    const failureMessage = runFailedMessage(event, index);
    if (failureMessage) {
      messages.push(failureMessage);
      return;
    }
    const part = event.messagePart?.app;
    if (!part?.messageId) {
      return;
    }
    const messageId = part.messageId;
    const existing = byMessageId.get(messageId);
    const nextText = part.fullText || `${existing?.text ?? ""}${part.delta ?? ""}`;
    const nextMessage: ChatTranscriptMessage & {
      eventIndex?: number;
      eventSeq?: number;
    } = {
      id: messageId,
      role: part.role ?? "agent",
      text: nextText,
      at: event.at ?? existing?.at,
      eventIndex: existing?.eventIndex ?? index,
      eventSeq: existing?.eventSeq ?? event.seq,
    };
    if (existing) {
      Object.assign(existing, nextMessage);
    } else {
      byMessageId.set(messageId, nextMessage);
      messages.push(nextMessage);
    }
  });

  const consumedEventEchoes = new Set<string>();
  const dedupedLocalMessages = localMessages.filter((message) => {
    const text = message.text.trim();
    const matchingEcho = messages.find((eventMessage) => {
      if (eventMessage.role !== "user" || eventMessage.text.trim() !== text) {
        return false;
      }
      if (
        message.submitEventBaseline != null &&
        ((eventMessage.eventSeq ?? 0) <= message.submitEventBaseline)
      ) {
        return false;
      }
      return !consumedEventEchoes.has(
        `${eventMessage.id}:${eventMessage.eventIndex ?? 0}`,
      );
    });
    if (!matchingEcho) {
      return true;
    }
    consumedEventEchoes.add(`${matchingEcho.id}:${matchingEcho.eventIndex ?? 0}`);
    return false;
  });
  const combined: Array<
    ChatTranscriptMessage & { eventIndex?: number; eventSeq?: number }
  > = [
    ...dedupedLocalMessages,
    ...messages,
  ];
  return combined
    .sort((left, right) => (left.at ?? "").localeCompare(right.at ?? ""))
    .map(
      ({
        eventIndex: _eventIndex,
        eventSeq: _eventSeq,
        ...message
      }) => message,
    );
}

export const useChatStore = create<ChatStoreState>((set) => ({
  runtimes: [],
  sessions: [],
  activeSessionId: undefined,
  eventsBySessionId: {},
  committedEventKeysBySessionId: {},
  localMessagesBySessionId: {},
  loadedSessionIds: {},
  loadingSessionIds: {},
  loadingRuntimes: false,
  loadingSessions: false,
  loadingSessionId: undefined,
  sendingSessionIds: {},
  streamEpoch: undefined,
  error: undefined,
  setRuntimes: (runtimes) => set({ runtimes }),
  mergeSessionCatalogPage: (sessions) =>
    set((state) => ({
      sessions: mergeSessionCatalogPage(state.sessions, sessions),
    })),
  mergeCreatedSession: (session) =>
    set((state) => {
      const existing = state.sessions.find(
        (entry) => entry.sessionId === session.sessionId,
      );
      const nextSession = mergeSession(existing, session);
      const nextSessions = existing
        ? state.sessions.map((entry) =>
            entry.sessionId === session.sessionId ? nextSession : entry,
          )
        : [nextSession, ...state.sessions];
      return {
        sessions: sortSessions(nextSessions),
        loadedSessionIds: {
          ...state.loadedSessionIds,
          [session.sessionId]: true,
        },
      };
    }),
  setActiveSession: (sessionId) => set({ activeSessionId: sessionId }),
  applyCommittedStreamItem: (item) =>
    set((state) => {
      if (item.kind === "event") {
        const streamEpochChanged =
          state.streamEpoch != null &&
          item.streamEpoch !== 0 &&
          state.streamEpoch !== item.streamEpoch;
        return {
          ...applyCommittedEventsToState(state, item.event ? [item.event] : [], {
            resetCommittedEvents: streamEpochChanged,
            streamEpoch: item.streamEpoch,
          }),
          streamEpoch: item.streamEpoch || state.streamEpoch,
        };
      }
      const streamEpochChanged =
        state.streamEpoch != null &&
        item.streamEpoch !== 0 &&
        state.streamEpoch !== item.streamEpoch;
      const resetCommittedEvents =
        streamEpochChanged || item.status === "gap" || item.status === "reset";
      return {
        ...applyCommittedEventsToState(state, item.events, {
          resetCommittedEvents,
          streamEpoch: item.streamEpoch,
        }),
        streamEpoch: item.streamEpoch || state.streamEpoch,
      };
    }),
  applySessionLoadSnapshot: (snapshot) =>
    set((state) => {
      if (state.loadingSessionIds[snapshot.sessionId] !== snapshot.loadToken) {
        return {};
      }
      const existingSession = state.sessions.find(
        (entry) => entry.sessionId === snapshot.sessionId,
      );
      const nextSession = mergeSession(existingSession, snapshot.session);
      const nextSessions = existingSession
        ? state.sessions.map((entry) =>
            entry.sessionId === snapshot.sessionId ? nextSession : entry,
          )
        : [nextSession, ...state.sessions];
      const loadingSessionIds = { ...state.loadingSessionIds };
      delete loadingSessionIds[snapshot.sessionId];
      const loadedSessionIds = { ...state.loadedSessionIds };
      if (snapshot.complete) {
        loadedSessionIds[snapshot.sessionId] = true;
      } else {
        delete loadedSessionIds[snapshot.sessionId];
      }
      const replayEvents = normalizeReplayEvents(
        snapshot.sessionId,
        snapshot.replayEvents,
      );
      const existingEvents = state.eventsBySessionId[snapshot.sessionId] ?? [];
      return {
        sessions: sortSessions(nextSessions),
        eventsBySessionId: {
          ...state.eventsBySessionId,
          [snapshot.sessionId]: replaceScopedReplayEvents(
            existingEvents,
            replayEvents,
          ),
        },
        loadedSessionIds,
        loadingSessionIds,
      };
    }),
  appendLocalMessage: (sessionId, text, submitEventBaseline) =>
    set((state) => {
      const trimmed = text.trim();
      if (!trimmed) {
        return {};
      }
      const existing = state.localMessagesBySessionId[sessionId] ?? [];
      return {
        localMessagesBySessionId: {
          ...state.localMessagesBySessionId,
          [sessionId]: [
            ...existing,
            {
              id: nextLocalMessageId(),
              role: "user",
              text: trimmed,
              at: new Date().toISOString(),
              local: true,
              ...(submitEventBaseline == null ? {} : { submitEventBaseline }),
            },
          ],
        },
      };
    }),
  beginSessionLoad: (sessionId, loadToken) =>
    set((state) => {
      const loadedSessionIds = { ...state.loadedSessionIds };
      delete loadedSessionIds[sessionId];
      return {
        loadedSessionIds,
        loadingSessionIds: {
          ...state.loadingSessionIds,
          [sessionId]: loadToken,
        },
      };
    }),
  failSessionLoad: (sessionId, loadToken) =>
    set((state) => {
      if (state.loadingSessionIds[sessionId] !== loadToken) {
        return {};
      }
      const loadingSessionIds = { ...state.loadingSessionIds };
      delete loadingSessionIds[sessionId];
      return {
        loadingSessionIds,
      };
    }),
  setLoadingRuntimes: (loading) => set({ loadingRuntimes: loading }),
  setLoadingSessions: (loading) => set({ loadingSessions: loading }),
  setLoadingSession: (sessionId) => set({ loadingSessionId: sessionId }),
  setSendingSession: (sessionId, sending) =>
    set((state) => {
      const next = { ...state.sendingSessionIds };
      if (sending) {
        next[sessionId] = true;
      } else {
        delete next[sessionId];
      }
      return { sendingSessionIds: next };
    }),
  setError: (message) => set({ error: message }),
  reset: () =>
    set({
      runtimes: [],
      sessions: [],
      activeSessionId: undefined,
      eventsBySessionId: {},
      committedEventKeysBySessionId: {},
      localMessagesBySessionId: {},
      loadedSessionIds: {},
      loadingSessionIds: {},
      loadingRuntimes: false,
      loadingSessions: false,
      loadingSessionId: undefined,
      sendingSessionIds: {},
      streamEpoch: undefined,
      error: undefined,
    }),
}));
