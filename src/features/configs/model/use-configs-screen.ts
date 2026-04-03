import { useWorkspaceStore } from "@/state/workspace-store";
import { useShellChrome } from "@/features/app/model/use-shell-chrome";

export function useConfigsScreen() {
  const shell = useShellChrome();
  const catalog = useWorkspaceStore((state) => state.catalog);

  return {
    shell,
    entries: catalog?.entries ?? [],
  };
}
