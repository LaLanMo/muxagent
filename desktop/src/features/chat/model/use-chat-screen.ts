import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  createAgentChatSession,
  listAgentChatSessions,
  loadAgentChatRuntimes,
  loadAgentChatSession,
  promptAgentChatSession,
} from "@/application/chat";
import { getRuntime } from "@/app/runtime";
import { buildChatPath, type WorkbenchTabId } from "@/domain/routes";
import {
  buildChatTranscriptMessages,
  useChatStore,
  type ChatTranscriptMessage,
} from "@/state/chat-store";
import { useWorkspaceStore } from "@/state/workspace-store";
import type {
  AgentChatRuntimeDto,
  AgentChatSessionDto,
  AgentChatSessionStatusDto,
} from "@/rpc/types";

export type ChatPermissionOption = {
  value: string;
  label: string;
};

export type ChatScreenModel = {
  activeSession?: AgentChatSessionDto;
  activeSessionId?: string;
  canStart: boolean;
  canSend: boolean;
  cwd: string;
  error?: string;
  loading: boolean;
  loadingSession: boolean;
  messages: ChatTranscriptMessage[];
  permissionMode: string;
  permissionOptions: ChatPermissionOption[];
  promptDraft: string;
  runtimes: AgentChatRuntimeDto[];
  selectedRuntimeId: string;
  sending: boolean;
  sessions: AgentChatSessionDto[];
  tabId: WorkbenchTabId;
  clearError: () => void;
  refresh: () => Promise<void>;
  sendPrompt: () => Promise<void>;
  setCwd: (cwd: string) => void;
  setPermissionMode: (permissionMode: string) => void;
  setPromptDraft: (prompt: string) => void;
  setSelectedRuntimeId: (runtimeId: string) => void;
  startNewChat: () => Promise<void>;
};

const permissionOptions: ChatPermissionOption[] = [
  { value: "default", label: "Default" },
  { value: "read-only", label: "Read Only" },
  { value: "acceptEdits", label: "Accept Edits" },
  { value: "full-access", label: "Full Access" },
  { value: "bypassPermissions", label: "Bypass Permissions" },
];

function chooseDefaultRuntime(runtimes: AgentChatRuntimeDto[]): string {
  const readyRuntimes = runtimes.filter((runtime) => runtime.ready);
  const candidates = readyRuntimes.length > 0 ? readyRuntimes : runtimes;
  return (
    candidates.find((runtime) => runtime.id === "codex")?.id ??
    candidates.find((runtime) => runtime.id === "claude-code")?.id ??
    candidates[0]?.id ??
    ""
  );
}

function workspaceDefaultCwd(
  workspaces: ReturnType<typeof useWorkspaceStore.getState>["workspaces"],
  selectedWorkspaceId: string | undefined,
): string {
  const selectedWorkspace = workspaces.find(
    (workspace) => workspace.workspace_id === selectedWorkspaceId,
  );
  return selectedWorkspace?.path ?? workspaces[0]?.path ?? "";
}

function sessionRouteTabId(sessionId?: string): WorkbenchTabId {
  return sessionId ? `chat:${sessionId}` : "chat";
}

function sessionRouteTitle(session?: AgentChatSessionDto): string {
  return session?.title?.trim() || "Chat";
}

function sessionIsLoadable(
  session: AgentChatSessionDto | undefined,
): session is AgentChatSessionDto & { runtime: string } {
  return Boolean(session?.sessionId && session.cwd && session.runtime);
}

function sessionStatusAfterCreate(
  existing?: AgentChatSessionDto,
): AgentChatSessionStatusDto {
  return existing?.status ?? "idle";
}

export function useChatScreen(): ChatScreenModel {
  const { sessionId } = useParams<{ sessionId?: string }>();
  const navigate = useNavigate();
  const runtimes = useChatStore((state) => state.runtimes);
  const sessions = useChatStore((state) => state.sessions);
  const eventsBySessionId = useChatStore((state) => state.eventsBySessionId);
  const localMessagesBySessionId = useChatStore(
    (state) => state.localMessagesBySessionId,
  );
  const loadedSessionIds = useChatStore((state) => state.loadedSessionIds);
  const loadingRuntimes = useChatStore((state) => state.loadingRuntimes);
  const loadingSessions = useChatStore((state) => state.loadingSessions);
  const loadingSessionId = useChatStore((state) => state.loadingSessionId);
  const sendingSessionIds = useChatStore((state) => state.sendingSessionIds);
  const error = useChatStore((state) => state.error);
  const setRuntimes = useChatStore((state) => state.setRuntimes);
  const setSessions = useChatStore((state) => state.setSessions);
  const upsertSession = useChatStore((state) => state.upsertSession);
  const setActiveSession = useChatStore((state) => state.setActiveSession);
  const appendLocalMessage = useChatStore((state) => state.appendLocalMessage);
  const markSessionLoaded = useChatStore((state) => state.markSessionLoaded);
  const setLoadingRuntimes = useChatStore((state) => state.setLoadingRuntimes);
  const setLoadingSessions = useChatStore((state) => state.setLoadingSessions);
  const setLoadingSession = useChatStore((state) => state.setLoadingSession);
  const setSendingSession = useChatStore((state) => state.setSendingSession);
  const setError = useChatStore((state) => state.setError);
  const workspaceDefaultPath = useWorkspaceStore((state) =>
    workspaceDefaultCwd(state.workspaces, state.selectedWorkspaceId),
  );
  const [selectedRuntimeId, setSelectedRuntimeIdState] = useState("");
  const [runtimeTouched, setRuntimeTouched] = useState(false);
  const [cwd, setCwdState] = useState(() => workspaceDefaultPath);
  const [cwdTouched, setCwdTouched] = useState(false);
  const [permissionMode, setPermissionMode] = useState("default");
  const [promptDraft, setPromptDraft] = useState("");

  const activeSession = useMemo(
    () => sessions.find((session) => session.sessionId === sessionId),
    [sessionId, sessions],
  );
  const activeSessionId = activeSession?.sessionId ?? sessionId;
  const messages = useMemo(
    () =>
      activeSessionId
        ? buildChatTranscriptMessages(
            eventsBySessionId[activeSessionId] ?? [],
            localMessagesBySessionId[activeSessionId] ?? [],
          )
        : [],
    [activeSessionId, eventsBySessionId, localMessagesBySessionId],
  );
  const loading = loadingRuntimes || loadingSessions;
  const loadingSession = activeSessionId
    ? loadingSessionId === activeSessionId
    : loadingSessionId === "new";
  const sending = activeSessionId ? Boolean(sendingSessionIds[activeSessionId]) : false;
  const trimmedPrompt = promptDraft.trim();
  const canStart =
    Boolean(selectedRuntimeId.trim()) &&
    Boolean(cwd.trim()) &&
    !loading &&
    !loadingSession &&
    !sending;
  const canSend =
    Boolean(activeSessionId) &&
    Boolean(trimmedPrompt) &&
    !sending &&
    !loadingSession;
  const tabId = sessionRouteTabId(activeSessionId);

  useEffect(() => {
    setActiveSession(sessionId);
  }, [sessionId, setActiveSession]);

  useEffect(() => {
    if (!cwdTouched && workspaceDefaultPath && cwd !== workspaceDefaultPath) {
      setCwdState(workspaceDefaultPath);
    }
  }, [cwd, cwdTouched, workspaceDefaultPath]);

  useEffect(() => {
    if (runtimeTouched || selectedRuntimeId || runtimes.length === 0) {
      return;
    }
    setSelectedRuntimeIdState(chooseDefaultRuntime(runtimes));
  }, [runtimeTouched, runtimes, selectedRuntimeId]);

  async function refresh(): Promise<void> {
    const runtime = getRuntime();
    setError(undefined);
    setLoadingRuntimes(true);
    setLoadingSessions(true);
    try {
      const [runtimeResult, sessionResult] = await Promise.all([
        loadAgentChatRuntimes(runtime),
        listAgentChatSessions(runtime, { limit: 50 }),
      ]);
      setRuntimes(runtimeResult.runtimes);
      setSessions(sessionResult.sessions);
      if (!runtimeTouched) {
        setSelectedRuntimeIdState(chooseDefaultRuntime(runtimeResult.runtimes));
      }
    } catch (errorValue) {
      setError(
        errorValue instanceof Error
          ? errorValue.message
          : "Failed to load chat state",
      );
    } finally {
      setLoadingRuntimes(false);
      setLoadingSessions(false);
    }
  }

  useEffect(() => {
    void refresh();
  }, []);

  useEffect(() => {
    if (!activeSessionId || loadedSessionIds[activeSessionId]) {
      return;
    }
    if (loadingSessionId === activeSessionId) {
      return;
    }
    if (!sessionIsLoadable(activeSession)) {
      return;
    }

    const sessionToLoad = activeSession;
    const runtime = getRuntime();
    setError(undefined);
    setLoadingSession(activeSessionId);
    void loadAgentChatSession(runtime, {
      sessionId: sessionToLoad.sessionId,
      cwd: sessionToLoad.cwd,
      runtime: sessionToLoad.runtime ?? "",
      permissionMode,
    })
      .then((result) => {
        upsertSession({
          sessionId: sessionToLoad.sessionId,
          cwd: result.app.cwd,
          title: sessionToLoad.title,
          runtime: result.app.runtime,
          updatedAt: new Date().toISOString(),
          status: sessionStatusAfterCreate(sessionToLoad),
          configOptions: result.acp.configOptions ?? sessionToLoad.configOptions,
        });
        markSessionLoaded(sessionToLoad.sessionId);
      })
      .catch((errorValue: unknown) => {
        setError(
          errorValue instanceof Error
            ? errorValue.message
            : "Failed to load chat session",
        );
      })
      .finally(() => {
        setLoadingSession(undefined);
      });
  }, [
    activeSession,
    activeSessionId,
    loadedSessionIds,
    loadingSessionId,
    markSessionLoaded,
    permissionMode,
    setError,
    setLoadingSession,
    upsertSession,
  ]);

  function setSelectedRuntimeId(runtimeId: string) {
    setRuntimeTouched(true);
    setSelectedRuntimeIdState(runtimeId);
  }

  function setCwd(nextCwd: string) {
    setCwdTouched(true);
    setCwdState(nextCwd);
  }

  async function sendPrompt(): Promise<void> {
    if (!activeSessionId || !trimmedPrompt) {
      return;
    }
    setError(undefined);
    appendLocalMessage(activeSessionId, trimmedPrompt);
    setPromptDraft("");
    setSendingSession(activeSessionId, true);
    try {
      await promptAgentChatSession(getRuntime(), {
        sessionId: activeSessionId,
        text: trimmedPrompt,
      });
    } catch (errorValue) {
      setError(
        errorValue instanceof Error ? errorValue.message : "Failed to send prompt",
      );
    } finally {
      setSendingSession(activeSessionId, false);
    }
  }

  async function startNewChat(): Promise<void> {
    if (!canStart) {
      return;
    }
    const runtime = getRuntime();
    const initialPrompt = trimmedPrompt;
    setError(undefined);
    setLoadingSession("new");
    try {
      const result = await createAgentChatSession(runtime, {
        cwd: cwd.trim(),
        runtime: selectedRuntimeId.trim(),
        permissionMode,
      });
      const createdSessionId = result.acp.sessionId;
      upsertSession({
        sessionId: createdSessionId,
        cwd: result.app.cwd,
        title: "New chat",
        runtime: result.app.runtime,
        updatedAt: new Date().toISOString(),
        status: "idle",
        configOptions: result.acp.configOptions,
      });
      markSessionLoaded(createdSessionId);
      setActiveSession(createdSessionId);
      navigate(buildChatPath(createdSessionId));
      if (initialPrompt) {
        appendLocalMessage(createdSessionId, initialPrompt);
        setPromptDraft("");
        setSendingSession(createdSessionId, true);
        try {
          await promptAgentChatSession(runtime, {
            sessionId: createdSessionId,
            text: initialPrompt,
          });
        } finally {
          setSendingSession(createdSessionId, false);
        }
      }
    } catch (errorValue) {
      setError(
        errorValue instanceof Error ? errorValue.message : "Failed to start chat",
      );
    } finally {
      setLoadingSession(undefined);
    }
  }

  return {
    activeSession,
    activeSessionId,
    canStart,
    canSend,
    cwd,
    error,
    loading,
    loadingSession,
    messages,
    permissionMode,
    permissionOptions,
    promptDraft,
    runtimes,
    selectedRuntimeId,
    sending,
    sessions,
    tabId,
    clearError: () => setError(undefined),
    refresh,
    sendPrompt,
    setCwd,
    setPermissionMode,
    setPromptDraft,
    setSelectedRuntimeId,
    startNewChat,
  };
}

export function chatTabTitle(session?: AgentChatSessionDto): string {
  return sessionRouteTitle(session);
}
