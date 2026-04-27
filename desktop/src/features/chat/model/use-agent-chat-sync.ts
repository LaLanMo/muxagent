import { useEffect, useEffectEvent } from "react";
import { agentChatEventFromNotification } from "@/application/chat";
import { getRuntime } from "@/app/runtime";
import type { RuntimeNotification } from "@/platform/contract";
import { useChatStore } from "@/state/chat-store";

export function useAgentChatSync(): void {
  const appendEvent = useChatStore((state) => state.appendEvent);
  const reset = useChatStore((state) => state.reset);

  const handleNotification = useEffectEvent(
    (notification: RuntimeNotification) => {
      const event = agentChatEventFromNotification(notification);
      if (event) {
        appendEvent(event);
      }
    },
  );

  useEffect(() => {
    const runtime = getRuntime();
    return runtime.backend.subscribe((notification) => {
      handleNotification(notification);
    });
  }, [handleNotification]);

  useEffect(() => {
    const runtime = getRuntime();
    return runtime.backend.onConnectionLoss(() => {
      reset();
    });
  }, [reset]);
}
