import { MessageSquare, Plus } from "lucide-react";
import { NavLink, useLocation, useNavigate } from "react-router-dom";
import { buildChatPath } from "@/domain/routes";
import { Button } from "@/features/shared/ui/Button";
import { useChatStore } from "@/state/chat-store";
import type { AgentChatSessionDto } from "@/rpc/types";

function formatSessionTime(updatedAt: string): string {
  const date = new Date(updatedAt);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
  }).format(date);
}

function sessionSubtitle(session: AgentChatSessionDto): string {
  const status = (() => {
    switch (session.status) {
      case "running":
        return "streaming…";
      case "waiting_approval":
        return "waiting";
      case "error":
        return "failed";
      case "done":
        return "done";
      case "idle":
      default:
        return formatSessionTime(session.updatedAt);
    }
  })();
  const parts = [session.runtime, status].filter(Boolean);
  return parts.join(" · ");
}

export function ChatPanel() {
  const location = useLocation();
  const navigate = useNavigate();
  const sessions = useChatStore((state) => state.sessions);
  const loadingSessions = useChatStore((state) => state.loadingSessions);
  const showingDraft = location.pathname === buildChatPath();

  return (
    <div className="chat-panel" data-testid="chat-panel">
      <div className="chat-panel__header">
        <div className="chat-panel__title-row">
          <span>CHATS</span>
          <button
            aria-label="New chat"
            className="chat-panel__add"
            onClick={() => navigate(buildChatPath())}
            type="button"
          >
            <Plus size={12} strokeWidth={1.9} />
          </button>
        </div>
      </div>

      <div className="chat-panel__body">
        <Button
          fullWidth
          leadingIcon={<Plus strokeWidth={1.9} />}
          onClick={() => navigate(buildChatPath())}
          size="sm"
          type="button"
          variant="secondary"
        >
          New chat
        </Button>

        <div className="chat-panel__section">
          <div className="chat-panel__section-header">
            <span>RECENT</span>
            {loadingSessions ? <span>Loading</span> : null}
          </div>
          <nav aria-label="Recent chats" className="chat-panel__list">
            {showingDraft ? (
              <NavLink
                className="chat-panel__row is-active"
                title="New chat"
                to={buildChatPath()}
              >
                <span className="chat-panel__row-main">
                  <span className="chat-panel__row-title">New chat</span>
                  <span className="chat-panel__row-subtitle">unsent · draft</span>
                </span>
              </NavLink>
            ) : null}
            {sessions.length > 0 ? (
              sessions.map((session) => (
                <NavLink
                  className={({ isActive }) =>
                    `chat-panel__row${isActive ? " is-active" : ""}`
                  }
                  key={session.sessionId}
                  title={session.title}
                  to={buildChatPath(session.sessionId)}
                >
                  <span className="chat-panel__row-main">
                    <span className="chat-panel__row-title">{session.title}</span>
                    <span className="chat-panel__row-subtitle">
                      {sessionSubtitle(session)}
                    </span>
                  </span>
                </NavLink>
              ))
            ) : !showingDraft ? (
              <div className="chat-panel__empty">
                <MessageSquare aria-hidden="true" size={16} strokeWidth={1.8} />
                <span>No chats yet</span>
              </div>
            ) : null}
          </nav>
        </div>
      </div>
    </div>
  );
}
