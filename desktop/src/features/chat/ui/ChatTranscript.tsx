import { useEffect, useMemo, useRef } from "react";
import { Bot } from "lucide-react";
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
    case "system":
      return "System";
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

  return (
    <div
      aria-live="polite"
      aria-relevant="additions text"
      className={`chat-transcript${
        messages.length === 0 ? " chat-transcript--empty" : ""
      }`}
      data-testid="chat-transcript"
      role="log"
    >
      {messages.length === 0 ? (
        <div className="chat-transcript__empty">
          <Bot aria-hidden="true" size={18} strokeWidth={1.9} />
          <span>{loading ? "Loading messages" : "No messages"}</span>
        </div>
      ) : (
        <div className="chat-transcript__stack">
          {messages.map((message) => {
            const user = isUserRole(message.role);
            return (
              <article
                className={`chat-message${
                  user
                    ? " chat-message--user"
                    : message.role === "system"
                      ? " chat-message--system"
                      : " chat-message--agent"
                }`}
                key={message.id}
              >
                <div className="chat-message__body">
                  <div className="chat-message__meta sr-only">
                    <span>{roleLabel(message.role)}</span>
                  </div>
                  <p className="chat-message__text">{message.text}</p>
                </div>
              </article>
            );
          })}
          <div ref={bottomRef} />
        </div>
      )}
    </div>
  );
}
