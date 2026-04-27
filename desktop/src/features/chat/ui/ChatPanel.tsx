import { MessageSquare, Plus } from "lucide-react";
import { NavLink, useNavigate } from "react-router-dom";
import { buildChatPath } from "@/domain/routes";
import { Button } from "@/features/shared/ui/Button";
import { useChatStore } from "@/state/chat-store";
import type { AgentChatSessionDto, AgentChatSessionStatusDto } from "@/rpc/types";

function statusClass(status: AgentChatSessionStatusDto): string {
  return `chat-panel__status chat-panel__status--${status.replace(/_/g, "-")}`;
}

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
  const parts = [
    session.runtime,
    session.cwd.split(/[\\/]/).filter(Boolean).at(-1),
    formatSessionTime(session.updatedAt),
  ].filter(Boolean);
  return parts.join(" · ");
}

export function ChatPanel() {
  const navigate = useNavigate();
  const sessions = useChatStore((state) => state.sessions);
  const loadingSessions = useChatStore((state) => state.loadingSessions);

  return (
    <div className="chat-panel" data-testid="chat-panel">
      <div className="chat-panel__header">
        <Button
          fullWidth
          leadingIcon={<Plus strokeWidth={2.2} />}
          onClick={() => navigate(buildChatPath())}
          size="md"
          type="button"
          variant="primary"
        >
          New chat
        </Button>
      </div>

      <div className="chat-panel__section">
        <div className="chat-panel__section-header">
          <span>RECENT</span>
          {loadingSessions ? <span>Loading</span> : null}
        </div>
        <nav aria-label="Recent chats" className="chat-panel__list">
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
                <span className={statusClass(session.status)} />
                <span className="chat-panel__row-main">
                  <span className="chat-panel__row-title">{session.title}</span>
                  <span className="chat-panel__row-subtitle">
                    {sessionSubtitle(session)}
                  </span>
                </span>
              </NavLink>
            ))
          ) : (
            <div className="chat-panel__empty">
              <MessageSquare aria-hidden="true" size={16} strokeWidth={1.8} />
              <span>No chats</span>
            </div>
          )}
        </nav>
      </div>
    </div>
  );
}
