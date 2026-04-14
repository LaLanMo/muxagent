import { useShellModel } from "@/features/app/model/use-shell-model";
import { useWorkspaceStore } from "@/state/workspace-store";

export function useSettingsScreen() {
  const shell = useShellModel();
  const status = useWorkspaceStore((state) => state.status);
  const server = useWorkspaceStore((state) => state.server);

  return {
    shell,
    status,
    server,
  };
}
