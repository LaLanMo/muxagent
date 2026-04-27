import { useEffect, useMemo, useRef } from "react";
import { Bot, User } from "lucide-react";
import type { ChatTranscriptMessage } from "@/state/chat-store";

type ChatTranscriptProps = {
  loading?: boolean;
  messages: ChatTranscriptMessage[];
};

function roleLabel(role: string): string {
  switch (role) {
    case "agent":
    case "assistant":
      return "Agent";
    case "user":
      return "You";
    default:
      return role;
  }
}

function isUserRole(role: string): boolean {
  return role === "user";
}

export function ChatTranscript({ loading = false, messages }: ChatTranscriptProps) {
  const bottomRef = useRef<HTMLDivElement>(null);
  const contentKey = useMemo(
    () => messages.map((message) => `${message.id}:${message.text.length}`).join("|"),
    [messages],
  );

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ block: "end" });
  }, [contentKey]);

  if (messages.length === 0) {
    return (
      <div className="chat-transcript chat-transcript--empty">
        <div className="chat-transcript__empty">
          <Bot aria-hidden="true" size={18} strokeWidth={1.9} />
          <span>{loading ? "Loading messages" : "No messages"}</span>
        </div>
      </div>
    );
  }

  return (
    <div className="chat-transcript" data-testid="chat-transcript">
      <div className="chat-transcript__stack">
        {messages.map((message) => {
          const user = isUserRole(message.role);
          return (
            <article
              className={`chat-message${user ? " chat-message--user" : " chat-message--agent"}`}
              key={message.id}
            >
              <div className="chat-message__avatar" aria-hidden="true">
                {user ? <User size={14} strokeWidth={1.9} /> : <Bot size={14} strokeWidth={1.9} />}
              </div>
              <div className="chat-message__body">
                <div className="chat-message__meta">
                  <span>{roleLabel(message.role)}</span>
                </div>
                <p className="chat-message__text">{message.text}</p>
              </div>
            </article>
          );
        })}
        <div ref={bottomRef} />
      </div>
    </div>
  );
}
