import { useEffect, useRef } from "react";
import { useAppSessionController } from "@/features/app/model/use-app-session-controller";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useServerBootstrap(): void {
  const startedInCurrentCycle = useRef(false);
  const phase = useWorkspaceStore((state) => state.phase);
  const bootstrapPending = useWorkspaceStore((state) => state.bootstrapPending);
  const server = useWorkspaceStore((state) => state.server);
  const { bootstrap } = useAppSessionController();

  useEffect(() => {
    if (!bootstrapPending) {
      startedInCurrentCycle.current = false;
      return;
    }
    if (phase !== "idle" || server) {
      return;
    }
    if (startedInCurrentCycle.current) {
      return;
    }
    startedInCurrentCycle.current = true;
    void bootstrap();
  }, [bootstrap, bootstrapPending, phase, server]);
}
