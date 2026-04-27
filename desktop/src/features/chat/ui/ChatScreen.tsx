import { Loader, RefreshCw } from "lucide-react";
import {
  chatTabTitle,
  useChatScreen,
} from "@/features/chat/model/use-chat-screen";
import { ChatComposer } from "@/features/chat/ui/ChatComposer";
import { ChatTranscript } from "@/features/chat/ui/ChatTranscript";
import {
  useWorkbenchRegions,
  useWorkbenchTab,
} from "@/features/layout/ui/workbench-surface";
import { Button } from "@/features/shared/ui/Button";
import type { AgentChatRuntimeDto, AgentChatSessionDto } from "@/rpc/types";

function statusLabel(status: AgentChatSessionDto["status"]): string {
  switch (status) {
    case "waiting_approval":
      return "Waiting";
    case "running":
      return "Running";
    case "error":
      return "Error";
    case "done":
      return "Done";
    case "idle":
    default:
      return "Idle";
  }
}

function runtimeLabel(runtimes: AgentChatRuntimeDto[], runtimeId: string): string {
  return runtimes.find((runtime) => runtime.id === runtimeId)?.label ?? runtimeId;
}

function leafPath(path: string): string {
  return path.split(/[\\/]/).filter(Boolean).at(-1) ?? path;
}

export function ChatScreen() {
  const model = useChatScreen();
  const title = chatTabTitle(model.activeSession);

  useWorkbenchTab({
    key: `chat-tab:${model.tabId}`,
    tabId: model.tabId,
    title,
  });
  useWorkbenchRegions({
    key: `chat-regions:${model.tabId}`,
    tabId: model.tabId,
    secondarySidebar: null,
    panel: null,
  });

  if (model.activeSessionId && !model.activeSession && !model.loading) {
    return (
      <section className="chat-screen" data-testid="chat-screen-missing">
        <div className="chat-screen__empty">
          <h1>Chat unavailable</h1>
          <p>Session metadata was not found.</p>
          {model.error ? (
            <div className="inline-banner inline-banner--failed">{model.error}</div>
          ) : null}
          <Button
            leadingIcon={<RefreshCw strokeWidth={2} />}
            onClick={() => void model.refresh()}
            size="md"
            type="button"
            variant="secondary"
          >
            Refresh
          </Button>
        </div>
      </section>
    );
  }

  if (!model.activeSession) {
    return (
      <section className="chat-screen chat-screen--new" data-testid="chat-screen-new">
        <div className="chat-screen__new">
          <header className="chat-screen__new-header">
            <div>
              <h1>New chat</h1>
              <p>{model.runtimes.length} runtimes available</p>
            </div>
            <Button
              disabled={model.loading}
              leadingIcon={
                model.loading ? (
                  <Loader className="chat-composer__spinner" strokeWidth={2} />
                ) : (
                  <RefreshCw strokeWidth={2} />
                )
              }
              onClick={() => void model.refresh()}
              size="sm"
              type="button"
              variant="secondary"
            >
              Refresh
            </Button>
          </header>

          {model.error ? (
            <div className="inline-banner inline-banner--failed">{model.error}</div>
          ) : null}

          <div className="chat-screen__controls">
            <label className="chat-field">
              <span>Runtime</span>
              <select
                disabled={model.loading || model.runtimes.length === 0}
                onChange={(event) => model.setSelectedRuntimeId(event.target.value)}
                value={model.selectedRuntimeId}
              >
                {model.runtimes.length === 0 ? (
                  <option value="">No runtime</option>
                ) : null}
                {model.runtimes.map((runtime) => (
                  <option
                    disabled={!runtime.ready}
                    key={runtime.id}
                    value={runtime.id}
                  >
                    {runtime.label}
                    {runtime.ready ? "" : " (offline)"}
                  </option>
                ))}
              </select>
            </label>
            <label className="chat-field">
              <span>Mode</span>
              <select
                onChange={(event) => model.setPermissionMode(event.target.value)}
                value={model.permissionMode}
              >
                {model.permissionOptions.map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
              </select>
            </label>
            <label className="chat-field chat-field--cwd">
              <span>CWD</span>
              <input
                onChange={(event) => model.setCwd(event.target.value)}
                placeholder="/path/to/workspace"
                type="text"
                value={model.cwd}
              />
            </label>
          </div>

          <ChatComposer
            canSubmit={model.canStart}
            disabled={model.loading}
            onChange={model.setPromptDraft}
            onSubmit={() => void model.startNewChat()}
            placeholder="Optional first message"
            sending={model.loadingSession}
            sendingLabel="Starting"
            submitLabel="Start chat"
            value={model.promptDraft}
          />
        </div>
      </section>
    );
  }

  return (
    <section className="chat-screen" data-testid="chat-screen">
      <header className="chat-thread-header">
        <div className="chat-thread-header__main">
          <h1>{model.activeSession.title}</h1>
          <div className="chat-thread-header__meta">
            <span>{runtimeLabel(model.runtimes, model.activeSession.runtime ?? "")}</span>
            <span>{leafPath(model.activeSession.cwd)}</span>
          </div>
        </div>
        <span
          className={`chat-thread-header__status chat-thread-header__status--${model.activeSession.status.replace(
            /_/g,
            "-",
          )}`}
        >
          {statusLabel(model.activeSession.status)}
        </span>
      </header>

      {model.error ? (
        <div className="chat-screen__banner inline-banner inline-banner--failed">
          {model.error}
        </div>
      ) : null}

      <ChatTranscript
        loading={model.loadingSession}
        messages={model.messages}
      />
      <div className="chat-screen__composer">
        <ChatComposer
          canSubmit={model.canSend}
          disabled={model.loadingSession}
          onChange={model.setPromptDraft}
          onSubmit={() => void model.sendPrompt()}
          placeholder="Message"
          sending={model.sending}
          value={model.promptDraft}
        />
      </div>
    </section>
  );
}
