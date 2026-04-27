import { useEffect, useMemo, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  cancelAgentChatSession,
  createAgentChatSession,
  listAgentChatSessions,
  loadAgentChatRuntimes,
  loadAgentChatSession,
  promptAgentChatSession,
  setAgentChatSessionConfigOption,
  setAgentChatSessionMode,
} from "@/application/chat";
import { getRuntime } from "@/app/runtime";
import {
  configOptionByCategory,
  configValueByCategory,
} from "@/domain/agent-chat-config";
import { buildChatPath, type WorkbenchTabId } from "@/domain/routes";
import {
  buildChatTranscriptMessages,
  useChatStore,
  type ChatTranscriptMessage,
} from "@/state/chat-store";
import { useWorkspaceStore } from "@/state/workspace-store";
import type {
  AgentChatEventDto,
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
  canCancel: boolean;
  canRetryLoad: boolean;
  canStart: boolean;
  canSend: boolean;
  changingMode: boolean;
  changingModel: boolean;
  configControlsDisabled: boolean;
  cwd: string;
  error?: string;
  loading: boolean;
  loadingSession: boolean;
  messages: ChatTranscriptMessage[];
  permissionMode: string;
  permissionOptions: ChatPermissionOption[];
  pendingConfigValues: Record<string, string>;
  pendingMode?: string;
  promptDraft: string;
  runtimes: AgentChatRuntimeDto[];
  selectedRuntimeId: string;
  sending: boolean;
  sessions: AgentChatSessionDto[];
  stopping: boolean;
  tabId: WorkbenchTabId;
  clearError: () => void;
  refresh: () => Promise<void>;
  retryLoadSession: () => void;
  sendPrompt: () => Promise<void>;
  setActiveConfigOption: (configId: string, value: string) => Promise<void>;
  setActiveMode: (permissionMode: string) => Promise<void>;
  setCwd: (cwd: string) => void;
  setPermissionMode: (permissionMode: string) => void;
  setPromptDraft: (prompt: string) => void;
  setSelectedRuntimeId: (runtimeId: string) => void;
  startNewChat: () => Promise<void>;
  stopSession: () => Promise<void>;
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
  return session?.title?.trim() || "New chat";
}

function sessionIsLoadable(
  session: AgentChatSessionDto | undefined,
): session is AgentChatSessionDto & { runtime: string } {
  return Boolean(session?.sessionId && session.cwd && session.runtime);
}

function sessionStatusIsBusy(
  status: AgentChatSessionStatusDto | undefined,
): boolean {
  return status === "running" || status === "waiting_approval";
}

function sessionIsBusy(session: AgentChatSessionDto | undefined): boolean {
  return sessionStatusIsBusy(session?.status);
}

function eventIsPromptEvidence(event: AgentChatEventDto): boolean {
  if (event.seq == null || event.seq <= 0) {
    return false;
  }
  if (event.messagePart || event.tool || event.runFailed || event.runFinished) {
    return true;
  }
  if (event.approval || event.plan || event.usage) {
    return true;
  }
  return sessionStatusIsBusy(event.sessionStatus?.app.status);
}

function currentSessionMode(
  session: AgentChatSessionDto | undefined,
  fallback: string,
): string {
  return configValueByCategory(session?.configOptions, "mode") || fallback;
}

function promptErrorMessage(errorValue: unknown): string {
  return errorValue instanceof Error ? errorValue.message : "Failed to send prompt";
}

function promptNotAcceptedError(): Error {
  return new Error("Prompt was not accepted");
}

function sessionConfigValue(
  session: AgentChatSessionDto,
  category: string,
): string | undefined {
  return configValueByCategory(session.configOptions, category) || undefined;
}

function runtimeDefaultMode(runtime: AgentChatRuntimeDto | undefined): string {
  return configOptionByCategory(runtime?.configOptions, "mode")?.currentValue ?? "";
}

const stopReconcileTimeoutMs = 5000;

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
  const mergeSessionCatalogPage = useChatStore(
    (state) => state.mergeSessionCatalogPage,
  );
  const mergeCreatedSession = useChatStore((state) => state.mergeCreatedSession);
  const mergeLoadedSession = useChatStore((state) => state.mergeLoadedSession);
  const setActiveSession = useChatStore((state) => state.setActiveSession);
  const appendLocalMessage = useChatStore((state) => state.appendLocalMessage);
  const markSessionLoaded = useChatStore((state) => state.markSessionLoaded);
  const beginSessionLoad = useChatStore((state) => state.beginSessionLoad);
  const failSessionLoad = useChatStore((state) => state.failSessionLoad);
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
  const [permissionModeTouched, setPermissionModeTouched] = useState(false);
  const [promptDraft, setPromptDraft] = useState("");
  const promptDraftVersion = useRef(0);
  const promptEventBaselines = useRef<Record<string, number>>({});
  const loadRequestCounter = useRef(0);
  const activeLoadRequest = useRef<
    { sessionId: string; token: number } | undefined
  >(undefined);
  const stoppingReconcileTimers = useRef<
    Record<string, ReturnType<typeof setTimeout>>
  >({});
  const [failedLoadSessionIds, setFailedLoadSessionIds] = useState<
    Record<string, boolean>
  >({});
  const [stoppingSessionIds, setStoppingSessionIds] = useState<
    Record<string, boolean>
  >({});
  const [changingModeSessionIds, setChangingModeSessionIds] = useState<
    Record<string, boolean>
  >({});
  const [changingModelSessionIds, setChangingModelSessionIds] = useState<
    Record<string, boolean>
  >({});
  const [pendingModeBySessionId, setPendingModeBySessionId] = useState<
    Record<string, string>
  >({});
  const [pendingConfigValuesBySessionId, setPendingConfigValuesBySessionId] =
    useState<Record<string, Record<string, string>>>({});

  const activeSession = useMemo(
    () => sessions.find((session) => session.sessionId === sessionId),
    [sessionId, sessions],
  );
  const selectedRuntime = useMemo(
    () => runtimes.find((runtime) => runtime.id === selectedRuntimeId),
    [runtimes, selectedRuntimeId],
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
  const stopping = activeSessionId
    ? Boolean(stoppingSessionIds[activeSessionId])
    : false;
  const changingMode = activeSessionId
    ? Boolean(
        changingModeSessionIds[activeSessionId] ||
          pendingModeBySessionId[activeSessionId],
      )
    : false;
  const changingModel = activeSessionId
    ? Boolean(
        changingModelSessionIds[activeSessionId] ||
          Object.keys(pendingConfigValuesBySessionId[activeSessionId] ?? {})
            .length > 0,
      )
    : false;
  const pendingMode = activeSessionId
    ? pendingModeBySessionId[activeSessionId]
    : undefined;
  const pendingConfigValues = activeSessionId
    ? pendingConfigValuesBySessionId[activeSessionId] ?? {}
    : {};
  const sessionBusy = sessionIsBusy(activeSession);
  const configControlsDisabled = loadingSession || sending || stopping || sessionBusy;
  const trimmedPrompt = promptDraft.trim();
  const canStart =
    Boolean(selectedRuntime?.ready) &&
    Boolean(cwd.trim()) &&
    !loading &&
    !loadingSession &&
    !sending;
  const canSend =
    Boolean(activeSessionId) &&
    Boolean(trimmedPrompt) &&
    !sending &&
    !stopping &&
    !loadingSession &&
    !sessionBusy;
  const canCancel =
    Boolean(activeSessionId) &&
    (sessionBusy || sending) &&
    !stopping &&
    !loadingSession;
  const canRetryLoad = Boolean(
    activeSessionId && failedLoadSessionIds[activeSessionId],
  );
  const tabId = sessionRouteTabId(activeSessionId);

  function clearStoppingTimer(sessionIdToClear: string) {
    const timer = stoppingReconcileTimers.current[sessionIdToClear];
    if (timer) {
      clearTimeout(timer);
      delete stoppingReconcileTimers.current[sessionIdToClear];
    }
  }

  function scheduleStoppingReconcile(sessionIdToReconcile: string) {
    clearStoppingTimer(sessionIdToReconcile);
    stoppingReconcileTimers.current[sessionIdToReconcile] = setTimeout(() => {
      void reconcileStoppingSession(sessionIdToReconcile);
    }, stopReconcileTimeoutMs);
  }

  function setPromptDraftValue(nextPromptDraft: string) {
    promptDraftVersion.current += 1;
    setPromptDraft(nextPromptDraft);
  }

  function clearSubmittedPromptDraft(submittedText: string, submittedVersion: number) {
    setPromptDraft((current) => {
      if (
        promptDraftVersion.current !== submittedVersion ||
        current.trim() !== submittedText
      ) {
        return current;
      }
      promptDraftVersion.current += 1;
      return "";
    });
  }

  function clearPendingMode(sessionIdToClear: string) {
    setPendingModeBySessionId((current) => {
      if (!current[sessionIdToClear]) {
        return current;
      }
      const next = { ...current };
      delete next[sessionIdToClear];
      return next;
    });
  }

  function clearPendingConfigValue(sessionIdToClear: string, configId: string) {
    setPendingConfigValuesBySessionId((current) => {
      const sessionValues = current[sessionIdToClear];
      if (!sessionValues?.[configId]) {
        return current;
      }
      const nextSessionValues = { ...sessionValues };
      delete nextSessionValues[configId];
      const next = { ...current };
      if (Object.keys(nextSessionValues).length === 0) {
        delete next[sessionIdToClear];
      } else {
        next[sessionIdToClear] = nextSessionValues;
      }
      return next;
    });
  }

  async function refreshSessionsOnly(): Promise<void> {
    const result = await listAgentChatSessions(getRuntime(), { limit: 50 });
    mergeSessionCatalogPage(result.sessions);
  }

  async function reconcileStoppingSession(sessionIdToReconcile: string) {
    clearStoppingTimer(sessionIdToReconcile);
    let stopConfirmed = false;
    try {
      const result = await listAgentChatSessions(getRuntime(), { limit: 50 });
      mergeSessionCatalogPage(result.sessions);
      const reconciledSession = result.sessions.find(
        (entry) => entry.sessionId === sessionIdToReconcile,
      );
      if (!reconciledSession) {
        setError("Stop is still pending. Waiting for session status.");
        scheduleStoppingReconcile(sessionIdToReconcile);
        return;
      }
      if (sessionIsBusy(reconciledSession)) {
        setError("Stop is still pending. Waiting for the session to stop.");
        scheduleStoppingReconcile(sessionIdToReconcile);
        return;
      }
      stopConfirmed = true;
    } catch (errorValue) {
      setError(
        errorValue instanceof Error
          ? errorValue.message
          : "Failed to reconcile stopped chat",
      );
      scheduleStoppingReconcile(sessionIdToReconcile);
    } finally {
      if (stopConfirmed) {
        setStoppingSessionIds((current) => {
          const next = { ...current };
          delete next[sessionIdToReconcile];
          return next;
        });
      }
    }
  }

  useEffect(() => {
    setStoppingSessionIds((current) => {
      let changed = false;
      const next = { ...current };
      for (const stoppedSessionId of Object.keys(current)) {
        const session = sessions.find(
          (entry) => entry.sessionId === stoppedSessionId,
        );
        if (!sessionIsBusy(session)) {
          clearStoppingTimer(stoppedSessionId);
          delete next[stoppedSessionId];
          changed = true;
        }
      }
      return changed ? next : current;
    });
  }, [sessions]);

  useEffect(() => {
    for (const sendingSessionId of Object.keys(sendingSessionIds)) {
      const baseline = promptEventBaselines.current[sendingSessionId] ?? 0;
      const eventsAfterSubmit =
        eventsBySessionId[sendingSessionId]?.slice(baseline) ?? [];
      const session = sessions.find(
        (entry) => entry.sessionId === sendingSessionId,
      );
      if (eventsAfterSubmit.some(eventIsPromptEvidence) || sessionIsBusy(session)) {
        delete promptEventBaselines.current[sendingSessionId];
        setSendingSession(sendingSessionId, false);
      }
    }
  }, [eventsBySessionId, sendingSessionIds, sessions, setSendingSession]);

  useEffect(() => {
    setPendingModeBySessionId((current) => {
      let changed = false;
      const next = { ...current };
      for (const session of sessions) {
        const pendingValue = next[session.sessionId];
        if (
          pendingValue &&
          configValueByCategory(session.configOptions, "mode") === pendingValue
        ) {
          delete next[session.sessionId];
          changed = true;
        }
      }
      return changed ? next : current;
    });
    setPendingConfigValuesBySessionId((current) => {
      let changed = false;
      const next = { ...current };
      for (const session of sessions) {
        const pendingValues = next[session.sessionId];
        if (!pendingValues) {
          continue;
        }
        const nextPendingValues = { ...pendingValues };
        for (const [configId, pendingValue] of Object.entries(pendingValues)) {
          const option = session.configOptions?.find(
            (entry) => entry.id === configId,
          );
          if (option?.currentValue === pendingValue) {
            delete nextPendingValues[configId];
            changed = true;
          }
        }
        if (Object.keys(nextPendingValues).length === 0) {
          delete next[session.sessionId];
        } else {
          next[session.sessionId] = nextPendingValues;
        }
      }
      return changed ? next : current;
    });
  }, [sessions]);

  useEffect(() => {
    return () => {
      for (const timer of Object.values(stoppingReconcileTimers.current)) {
        clearTimeout(timer);
      }
      stoppingReconcileTimers.current = {};
    };
  }, []);

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

  useEffect(() => {
    if (permissionModeTouched || !selectedRuntimeId) {
      return;
    }
    const defaultMode = runtimeDefaultMode(selectedRuntime) || "default";
    if (defaultMode !== permissionMode) {
      setPermissionMode(defaultMode);
    }
  }, [permissionMode, permissionModeTouched, selectedRuntime, selectedRuntimeId]);

  async function refresh(): Promise<void> {
    const runtime = getRuntime();
    setError(undefined);
    setFailedLoadSessionIds({});
    setLoadingRuntimes(true);
    setLoadingSessions(true);
    try {
      const [runtimeResult, sessionResult] = await Promise.all([
        loadAgentChatRuntimes(runtime),
        listAgentChatSessions(runtime, { limit: 50 }),
      ]);
      setRuntimes(runtimeResult.runtimes);
      mergeSessionCatalogPage(sessionResult.sessions);
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
    if (failedLoadSessionIds[activeSessionId]) {
      return;
    }
    if (loadingSessionId === activeSessionId) {
      return;
    }
    if (loadingSessionId) {
      return;
    }
    if (!sessionIsLoadable(activeSession)) {
      return;
    }

    const sessionToLoad = activeSession;
    const token = loadRequestCounter.current + 1;
    loadRequestCounter.current = token;
    activeLoadRequest.current = { sessionId: sessionToLoad.sessionId, token };
    const runtime = getRuntime();
    const loadPermissionMode = sessionConfigValue(sessionToLoad, "mode");
    const loadModel = sessionConfigValue(sessionToLoad, "model");
    let loadAccepted = false;
    setError(undefined);
    beginSessionLoad(sessionToLoad.sessionId);
    void loadAgentChatSession(runtime, {
      sessionId: sessionToLoad.sessionId,
      cwd: sessionToLoad.cwd,
      runtime: sessionToLoad.runtime ?? "",
      ...(loadPermissionMode ? { permissionMode: loadPermissionMode } : {}),
      ...(loadModel ? { model: loadModel } : {}),
    })
      .then((result) => {
        const currentSession = useChatStore
          .getState()
          .sessions.find((entry) => entry.sessionId === sessionToLoad.sessionId);
        const requestIsCurrent =
          activeLoadRequest.current?.sessionId === sessionToLoad.sessionId &&
          activeLoadRequest.current.token === token;
        if (!requestIsCurrent) {
          return;
        }
        loadAccepted = true;
        mergeLoadedSession({
          sessionId: sessionToLoad.sessionId,
          cwd: result.app.cwd,
          runtime: result.app.runtime,
          configOptions:
            result.acp.configOptions ??
            currentSession?.configOptions ??
            sessionToLoad.configOptions,
        });
        setFailedLoadSessionIds((current) => {
          if (!current[sessionToLoad.sessionId]) {
            return current;
          }
          const next = { ...current };
          delete next[sessionToLoad.sessionId];
          return next;
        });
      })
      .catch((errorValue: unknown) => {
        const requestIsCurrent =
          activeLoadRequest.current?.sessionId === sessionToLoad.sessionId &&
          activeLoadRequest.current.token === token;
        if (!requestIsCurrent) {
          return;
        }
        failSessionLoad(sessionToLoad.sessionId);
        setFailedLoadSessionIds((current) => ({
          ...current,
          [sessionToLoad.sessionId]: true,
        }));
        setError(
          errorValue instanceof Error
            ? errorValue.message
            : "Failed to load chat session",
        );
      })
      .finally(() => {
        const currentRequest = activeLoadRequest.current;
        if (
          currentRequest?.sessionId === sessionToLoad.sessionId &&
          currentRequest.token === token
        ) {
          activeLoadRequest.current = undefined;
          if (
            !loadAccepted ||
            useChatStore.getState().loadedSessionIds[sessionToLoad.sessionId]
          ) {
            setLoadingSession(undefined);
          }
        }
      });
  }, [
    activeSession,
    activeSessionId,
    failedLoadSessionIds,
    beginSessionLoad,
    failSessionLoad,
    loadedSessionIds,
    loadingSessionId,
    mergeLoadedSession,
    setError,
    setLoadingSession,
  ]);

  function setSelectedRuntimeId(runtimeId: string) {
    setRuntimeTouched(true);
    setPermissionModeTouched(false);
    setSelectedRuntimeIdState(runtimeId);
  }

  function setCwd(nextCwd: string) {
    setCwdTouched(true);
    setCwdState(nextCwd);
  }

  function setDraftPermissionMode(nextPermissionMode: string) {
    setPermissionModeTouched(true);
    setPermissionMode(nextPermissionMode);
  }

  function retryLoadSession() {
    if (!activeSessionId) {
      return;
    }
    setError(undefined);
    setFailedLoadSessionIds((current) => {
      if (!current[activeSessionId]) {
        return current;
      }
      const next = { ...current };
      delete next[activeSessionId];
      return next;
    });
  }

  async function sendPrompt(): Promise<void> {
    if (!activeSessionId || !trimmedPrompt || sessionBusy || stopping || sending) {
      return;
    }
    const promptedSessionId = activeSessionId;
    const promptText = trimmedPrompt;
    const submittedDraftVersion = promptDraftVersion.current;
    setError(undefined);
    const submitEventBaseline = eventsBySessionId[promptedSessionId]?.length ?? 0;
    promptEventBaselines.current[promptedSessionId] = submitEventBaseline;
    setSendingSession(promptedSessionId, true);
    let accepted = false;
    try {
      const result = await promptAgentChatSession(getRuntime(), {
        sessionId: promptedSessionId,
        text: promptText,
      });
      if (!result.accepted) {
        throw promptNotAcceptedError();
      }
      accepted = true;
      appendLocalMessage(promptedSessionId, promptText, submitEventBaseline);
      clearSubmittedPromptDraft(promptText, submittedDraftVersion);
    } catch (errorValue) {
      delete promptEventBaselines.current[promptedSessionId];
      setError(promptErrorMessage(errorValue));
    } finally {
      if (!accepted) {
        setSendingSession(promptedSessionId, false);
      }
    }
  }

  async function startNewChat(): Promise<void> {
    if (!canStart) {
      return;
    }
    const runtime = getRuntime();
    const initialPrompt = trimmedPrompt;
    const submittedDraftVersion = promptDraftVersion.current;
    setError(undefined);
    setLoadingSession("new");
    try {
      const result = await createAgentChatSession(runtime, {
        cwd: cwd.trim(),
        runtime: selectedRuntimeId.trim(),
        permissionMode,
      });
      const createdSessionId = result.app.sessionId;
      mergeCreatedSession({
        sessionId: createdSessionId,
        cwd: result.app.cwd,
        title: result.app.title,
        runtime: result.app.runtime,
        updatedAt: result.app.updatedAt,
        status: result.app.status,
        configOptions: result.acp.configOptions,
      });
      markSessionLoaded(createdSessionId);
      setActiveSession(createdSessionId);
      navigate(buildChatPath(createdSessionId));
      if (initialPrompt) {
        const submitEventBaseline =
          eventsBySessionId[createdSessionId]?.length ?? 0;
        promptEventBaselines.current[createdSessionId] = submitEventBaseline;
        setSendingSession(createdSessionId, true);
        let promptAccepted = false;
        try {
          const result = await promptAgentChatSession(runtime, {
            sessionId: createdSessionId,
            text: initialPrompt,
          });
          if (!result.accepted) {
            throw promptNotAcceptedError();
          }
          promptAccepted = true;
          appendLocalMessage(createdSessionId, initialPrompt, submitEventBaseline);
          clearSubmittedPromptDraft(initialPrompt, submittedDraftVersion);
        } catch (errorValue) {
          delete promptEventBaselines.current[createdSessionId];
          setError(promptErrorMessage(errorValue));
        } finally {
          if (!promptAccepted) {
            setSendingSession(createdSessionId, false);
          }
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

  async function stopSession(): Promise<void> {
    if (!activeSessionId || (!sessionBusy && !sending) || stopping) {
      return;
    }
    const stoppedSessionId = activeSessionId;
    setError(undefined);
    setStoppingSessionIds((current) => ({ ...current, [stoppedSessionId]: true }));
    let cancelAccepted = false;
    try {
      await cancelAgentChatSession(getRuntime(), { sessionId: stoppedSessionId });
      cancelAccepted = true;
      delete promptEventBaselines.current[stoppedSessionId];
      setSendingSession(stoppedSessionId, false);
      scheduleStoppingReconcile(stoppedSessionId);
    } catch (errorValue) {
      setError(
        errorValue instanceof Error ? errorValue.message : "Failed to stop chat",
      );
    } finally {
      if (!cancelAccepted) {
        setStoppingSessionIds((current) => {
          const next = { ...current };
          delete next[stoppedSessionId];
          return next;
        });
      }
    }
  }

  async function setActiveMode(nextPermissionMode: string): Promise<void> {
    if (changingMode || configControlsDisabled) {
      return;
    }
    const previousMode = currentSessionMode(activeSession, permissionMode);
    if (!activeSessionId || nextPermissionMode === previousMode) {
      return;
    }
    const modeSessionId = activeSessionId;
    setError(undefined);
    setPendingModeBySessionId((current) => ({
      ...current,
      [modeSessionId]: nextPermissionMode,
    }));
    setChangingModeSessionIds((current) => ({
      ...current,
      [modeSessionId]: true,
    }));
    try {
      await setAgentChatSessionMode(getRuntime(), {
        sessionId: modeSessionId,
        permissionMode: nextPermissionMode,
      });
      await refreshSessionsOnly();
    } catch (errorValue) {
      clearPendingMode(modeSessionId);
      setError(
        errorValue instanceof Error
          ? errorValue.message
          : "Failed to change chat mode",
      );
    } finally {
      setChangingModeSessionIds((current) => {
        const next = { ...current };
        delete next[modeSessionId];
        return next;
      });
    }
  }

  async function setActiveConfigOption(
    configId: string,
    value: string,
  ): Promise<void> {
    if (changingModel || !activeSessionId || !configId.trim() || !value.trim()) {
      return;
    }
    if (configControlsDisabled) {
      return;
    }
    const configSessionId = activeSessionId;
    setError(undefined);
    setPendingConfigValuesBySessionId((current) => ({
      ...current,
      [configSessionId]: {
        ...(current[configSessionId] ?? {}),
        [configId]: value,
      },
    }));
    setChangingModelSessionIds((current) => ({
      ...current,
      [configSessionId]: true,
    }));
    try {
      await setAgentChatSessionConfigOption(getRuntime(), {
        sessionId: configSessionId,
        configId,
        value,
      });
      await refreshSessionsOnly();
    } catch (errorValue) {
      clearPendingConfigValue(configSessionId, configId);
      setError(
        errorValue instanceof Error
          ? errorValue.message
          : "Failed to change chat option",
      );
    } finally {
      setChangingModelSessionIds((current) => {
        const next = { ...current };
        delete next[configSessionId];
        return next;
      });
    }
  }

  return {
    activeSession,
    activeSessionId,
    canCancel,
    canRetryLoad,
    canStart,
    canSend,
    changingMode,
    changingModel,
    configControlsDisabled,
    cwd,
    error,
    loading,
    loadingSession,
    messages,
    permissionMode,
    permissionOptions,
    pendingConfigValues,
    pendingMode,
    promptDraft,
    runtimes,
    selectedRuntimeId,
    sending,
    sessions,
    stopping,
    tabId,
    clearError: () => setError(undefined),
    refresh,
    retryLoadSession,
    sendPrompt,
    setActiveConfigOption,
    setActiveMode,
    setCwd,
    setPermissionMode: setDraftPermissionMode,
    setPromptDraft: setPromptDraftValue,
    setSelectedRuntimeId,
    startNewChat,
    stopSession,
  };
}

export function chatTabTitle(session?: AgentChatSessionDto): string {
  return sessionRouteTitle(session);
}
