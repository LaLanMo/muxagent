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
};

type ChatStoreState = {
  runtimes: AgentChatRuntimeDto[];
  sessions: AgentChatSessionDto[];
  activeSessionId?: string;
  eventsBySessionId: Record<string, AgentChatEventDto[]>;
  localMessagesBySessionId: Record<string, ChatTranscriptMessage[]>;
  loadedSessionIds: Record<string, boolean>;
  loadingRuntimes: boolean;
  loadingSessions: boolean;
  loadingSessionId?: string;
  sendingSessionIds: Record<string, boolean>;
  error?: string;
  setRuntimes: (runtimes: AgentChatRuntimeDto[]) => void;
  setSessions: (sessions: AgentChatSessionDto[]) => void;
  upsertSession: (session: AgentChatSessionDto) => void;
  setActiveSession: (sessionId?: string) => void;
  appendEvent: (event: AgentChatEventDto) => void;
  appendLocalMessage: (sessionId: string, text: string) => void;
  markSessionLoaded: (sessionId: string) => void;
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

function statusFromEvent(
  event: AgentChatEventDto,
): AgentChatSessionStatusDto | undefined {
  if (event.sessionStatus?.app.status) {
    return event.sessionStatus.app.status;
  }
  switch (event.type) {
    case "approval.requested":
      return "waiting_approval";
    case "approval.replied":
    case "message.delta":
    case "tool.started":
    case "tool.updated":
      return "running";
    case "run.failed":
    case "tool.failed":
      return "error";
    case "run.finished":
      return "idle";
    default:
      return undefined;
  }
}

function mergeSession(
  existing: AgentChatSessionDto | undefined,
  patch: Partial<AgentChatSessionDto> & { sessionId: string },
): AgentChatSessionDto {
  const updatedAt =
    patch.updatedAt ?? existing?.updatedAt ?? new Date().toISOString();
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

function eventAlreadyPresent(
  events: AgentChatEventDto[],
  event: AgentChatEventDto,
): boolean {
  if (event.seq == null || event.seq <= 0) {
    return false;
  }
  return events.some((entry) => entry.seq === event.seq);
}

function nextLocalMessageId(): string {
  return globalThis.crypto?.randomUUID?.() ?? `local-${Date.now()}`;
}

export function buildChatTranscriptMessages(
  events: AgentChatEventDto[],
  localMessages: ChatTranscriptMessage[],
): ChatTranscriptMessage[] {
  const messages: ChatTranscriptMessage[] = [];
  const byMessageId = new Map<string, ChatTranscriptMessage>();

  for (const event of events) {
    const part = event.messagePart?.app;
    if (!part?.messageId) {
      continue;
    }
    const messageId = part.messageId;
    const existing = byMessageId.get(messageId);
    const nextText = part.fullText || `${existing?.text ?? ""}${part.delta ?? ""}`;
    const nextMessage: ChatTranscriptMessage = {
      id: messageId,
      role: part.role ?? "agent",
      text: nextText,
      at: event.at ?? existing?.at,
    };
    if (existing) {
      Object.assign(existing, nextMessage);
    } else {
      byMessageId.set(messageId, nextMessage);
      messages.push(nextMessage);
    }
  }

  const eventUserTexts = new Set(
    messages
      .filter((message) => message.role === "user")
      .map((message) => message.text.trim())
      .filter(Boolean),
  );
  const dedupedLocalMessages = localMessages.filter(
    (message) => !eventUserTexts.has(message.text.trim()),
  );
  return [...dedupedLocalMessages, ...messages].sort((left, right) =>
    (left.at ?? "").localeCompare(right.at ?? ""),
  );
}

export const useChatStore = create<ChatStoreState>((set) => ({
  runtimes: [],
  sessions: [],
  activeSessionId: undefined,
  eventsBySessionId: {},
  localMessagesBySessionId: {},
  loadedSessionIds: {},
  loadingRuntimes: false,
  loadingSessions: false,
  loadingSessionId: undefined,
  sendingSessionIds: {},
  error: undefined,
  setRuntimes: (runtimes) => set({ runtimes }),
  setSessions: (sessions) => set({ sessions: sortSessions(sessions) }),
  upsertSession: (session) =>
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
  setActiveSession: (sessionId) => set({ activeSessionId: sessionId }),
  appendEvent: (event) =>
    set((state) => {
      const patch = eventPatch(event);
      if (!patch) {
        return {};
      }
      const sessionId = patch.sessionId;
      const existingEvents = state.eventsBySessionId[sessionId] ?? [];
      const nextEvents = eventAlreadyPresent(existingEvents, event)
        ? existingEvents
        : [...existingEvents, event];
      const existingSession = state.sessions.find(
        (entry) => entry.sessionId === sessionId,
      );
      const nextSession = mergeSession(existingSession, patch);
      const nextSessions = existingSession
        ? state.sessions.map((entry) =>
            entry.sessionId === sessionId ? nextSession : entry,
          )
        : [nextSession, ...state.sessions];
      return {
        eventsBySessionId:
          nextEvents === existingEvents
            ? state.eventsBySessionId
            : {
                ...state.eventsBySessionId,
                [sessionId]: nextEvents,
              },
        sessions: sortSessions(nextSessions),
      };
    }),
  appendLocalMessage: (sessionId, text) =>
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
      loadingRuntimes: false,
      loadingSessions: false,
      loadingSessionId: undefined,
      sendingSessionIds: {},
      error: undefined,
    }),
}));
