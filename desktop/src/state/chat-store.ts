import { create } from "zustand";
import { eventSessionId } from "@/application/chat";
import type {
  AgentChatEventDto,
  AgentChatRuntimeDto,
  AgentChatSessionDto,
  AgentChatSessionStatusDto,
} from "@/rpc/types";

export type ChatTranscriptMessage = {
  id: string;
  role: string;
  text: string;
  at?: string;
  local?: boolean;
  submitEventBaseline?: number;
};

type ChatStoreState = {
  runtimes: AgentChatRuntimeDto[];
  sessions: AgentChatSessionDto[];
  activeSessionId?: string;
  eventsBySessionId: Record<string, AgentChatEventDto[]>;
  localMessagesBySessionId: Record<string, ChatTranscriptMessage[]>;
  loadedSessionIds: Record<string, boolean>;
  loadReplayBaselinesBySessionId: Record<string, number>;
  loadingRuntimes: boolean;
  loadingSessions: boolean;
  loadingSessionId?: string;
  sendingSessionIds: Record<string, boolean>;
  error?: string;
  setRuntimes: (runtimes: AgentChatRuntimeDto[]) => void;
  mergeSessionCatalogPage: (sessions: AgentChatSessionDto[]) => void;
  mergeCreatedSession: (session: AgentChatSessionDto) => void;
  mergeLoadedSession: (
    session: Pick<AgentChatSessionDto, "sessionId" | "cwd"> &
      Partial<Pick<AgentChatSessionDto, "runtime" | "configOptions">>,
  ) => void;
  setActiveSession: (sessionId?: string) => void;
  appendEvent: (event: AgentChatEventDto) => void;
  appendLocalMessage: (
    sessionId: string,
    text: string,
    submitEventBaseline?: number,
  ) => void;
  markSessionLoaded: (sessionId: string) => void;
  beginSessionLoad: (sessionId: string) => void;
  failSessionLoad: (sessionId: string) => void;
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
  const isLiveEvent = event.seq != null && event.seq > 0;
  if (event.sessionStatus?.app.status) {
    return isLiveEvent ? event.sessionStatus.app.status : undefined;
  }
  switch (event.type) {
    case "approval.requested":
      return isLiveEvent ? "waiting_approval" : undefined;
    case "approval.replied":
      return isLiveEvent ? "running" : undefined;
    case "message.delta":
    case "tool.started":
    case "tool.updated":
      return isLiveEvent ? "running" : undefined;
    case "run.failed":
    case "tool.failed":
      return isLiveEvent ? "error" : undefined;
    case "run.finished":
      return isLiveEvent ? "idle" : undefined;
    default:
      return undefined;
  }
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
  if (event.type === "history.complete") {
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
  events: AgentChatEventDto[],
  event: AgentChatEventDto,
): boolean {
  if (event.seq == null || event.seq <= 0) {
    return false;
  }
  return events.some((entry) => entry.seq === event.seq);
}

function isLiveEvent(event: AgentChatEventDto): boolean {
  return event.seq != null && event.seq > 0;
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
    const submitEventBaseline = message.submitEventBaseline ?? 0;
    const matchingEcho = messages.find((eventMessage) => {
      if (eventMessage.role !== "user" || eventMessage.text.trim() !== text) {
        return false;
      }
      if ((eventMessage.eventIndex ?? 0) < submitEventBaseline) {
        return false;
      }
      if (
        message.submitEventBaseline != null &&
        ((eventMessage.eventSeq ?? 0) <= 0)
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
  localMessagesBySessionId: {},
  loadedSessionIds: {},
  loadReplayBaselinesBySessionId: {},
  loadingRuntimes: false,
  loadingSessions: false,
  loadingSessionId: undefined,
  sendingSessionIds: {},
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
      return { sessions: sortSessions(nextSessions) };
    }),
  mergeLoadedSession: (session) =>
    set((state) => {
      const existing = state.sessions.find(
        (entry) => entry.sessionId === session.sessionId,
      );
      if (!existing) {
        return {};
      }
      const nextSession = mergeSession(existing, {
        sessionId: session.sessionId,
        cwd: session.cwd,
        runtime: session.runtime,
        configOptions: session.configOptions,
      });
      return {
        sessions: sortSessions(
          state.sessions.map((entry) =>
            entry.sessionId === session.sessionId ? nextSession : entry,
          ),
        ),
      };
    }),
  setActiveSession: (sessionId) => set({ activeSessionId: sessionId }),
  appendEvent: (event) =>
    set((state) => {
      const eventSession = eventSessionId(event);
      if (!eventSession) {
        return {};
      }
      if (event.type === "history.complete") {
        const baseline = state.loadReplayBaselinesBySessionId[eventSession];
        if (baseline == null) {
          return {};
        }
        const existingEvents = state.eventsBySessionId[eventSession] ?? [];
        const nextEvents =
          [
            ...existingEvents.slice(0, baseline).filter(isLiveEvent),
            ...existingEvents.slice(baseline),
          ];
        const loadReplayBaselinesBySessionId = {
          ...state.loadReplayBaselinesBySessionId,
        };
        delete loadReplayBaselinesBySessionId[eventSession];
        const loadedSessionIds = state.loadedSessionIds[eventSession]
          ? state.loadedSessionIds
          : {
              ...state.loadedSessionIds,
              [eventSession]: true,
            };
        return {
          eventsBySessionId: {
            ...state.eventsBySessionId,
            [eventSession]: nextEvents,
          },
          loadReplayBaselinesBySessionId,
          loadedSessionIds,
          loadingSessionId:
            state.loadingSessionId === eventSession
              ? undefined
              : state.loadingSessionId,
        };
      }
      const patch = eventPatch(event);
      if (!patch) {
        return {};
      }
      const sessionId = patch.sessionId;
      const existingEvents = state.eventsBySessionId[sessionId] ?? [];
      if (eventAlreadyPresent(existingEvents, event)) {
        return {};
      }
      const nextEvents = [...existingEvents, event];
      if (!isLiveEvent(event)) {
        return {
          eventsBySessionId: {
            ...state.eventsBySessionId,
            [sessionId]: nextEvents,
          },
        };
      }
      const existingSession = state.sessions.find(
        (entry) => entry.sessionId === sessionId,
      );
      const nextSession = mergeSession(existingSession, {
        ...patch,
        configOptions: configOptionsFromEvent(event, existingSession),
      });
      const nextSessions = existingSession
        ? state.sessions.map((entry) =>
            entry.sessionId === sessionId ? nextSession : entry,
          )
        : [nextSession, ...state.sessions];
      return {
        eventsBySessionId: {
          ...state.eventsBySessionId,
          [sessionId]: nextEvents,
        },
        sessions: sortSessions(nextSessions),
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
  markSessionLoaded: (sessionId) =>
    set((state) =>
      state.loadedSessionIds[sessionId]
        ? {}
        : {
            loadedSessionIds: {
              ...state.loadedSessionIds,
              [sessionId]: true,
            },
          },
    ),
  beginSessionLoad: (sessionId) =>
    set((state) => {
      const loadedSessionIds = { ...state.loadedSessionIds };
      delete loadedSessionIds[sessionId];
      return {
        loadedSessionIds,
        loadReplayBaselinesBySessionId: {
          ...state.loadReplayBaselinesBySessionId,
          [sessionId]: state.eventsBySessionId[sessionId]?.length ?? 0,
        },
        loadingSessionId: sessionId,
      };
    }),
  failSessionLoad: (sessionId) =>
    set((state) => {
      const baseline = state.loadReplayBaselinesBySessionId[sessionId];
      const loadReplayBaselinesBySessionId = {
        ...state.loadReplayBaselinesBySessionId,
      };
      delete loadReplayBaselinesBySessionId[sessionId];
      const events = state.eventsBySessionId[sessionId] ?? [];
      const nextEvents =
        baseline == null
          ? events
          : [
              ...events.slice(0, baseline),
              ...events.slice(baseline).filter(isLiveEvent),
            ];
      return {
        eventsBySessionId: {
          ...state.eventsBySessionId,
          [sessionId]: nextEvents,
        },
        loadReplayBaselinesBySessionId,
        loadingSessionId:
          state.loadingSessionId === sessionId
            ? undefined
            : state.loadingSessionId,
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
      localMessagesBySessionId: {},
      loadedSessionIds: {},
      loadReplayBaselinesBySessionId: {},
      loadingRuntimes: false,
      loadingSessions: false,
      loadingSessionId: undefined,
      sendingSessionIds: {},
      error: undefined,
    }),
}));
