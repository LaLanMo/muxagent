import assert from "node:assert/strict";
import test from "node:test";
import { renderToStaticMarkup } from "react-dom/server";
import { ChatTranscript } from "@/features/chat/ui/ChatTranscript";

test("chat transcript keeps the live log region mounted when empty", () => {
  const markup = renderToStaticMarkup(
    <ChatTranscript loading={false} messages={[]} />,
  );

  assert.match(markup, /data-testid="chat-transcript"/);
  assert.match(markup, /role="log"/);
  assert.match(markup, /aria-live="polite"/);
  assert.match(markup, /No messages/);
});
