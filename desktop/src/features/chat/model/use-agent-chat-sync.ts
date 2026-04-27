import { useEffect, useEffectEvent } from "react";
import { agentChatStreamItemFromNotification } from "@/application/chat";
import { getRuntime } from "@/app/runtime";
import type { RuntimeNotification } from "@/platform/contract";
import { useChatStore } from "@/state/chat-store";

export function useAgentChatSync(): void {
  const applyCommittedStreamItem = useChatStore(
    (state) => state.applyCommittedStreamItem,
  );
  const reset = useChatStore((state) => state.reset);

  const handleNotification = useEffectEvent(
    (notification: RuntimeNotification) => {
      const streamItem = agentChatStreamItemFromNotification(notification);
      if (streamItem) {
        applyCommittedStreamItem(streamItem);
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
