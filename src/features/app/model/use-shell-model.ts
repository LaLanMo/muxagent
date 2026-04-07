import {
  useShellChrome,
  type ShellChromeModel,
} from "@/features/app/model/use-shell-chrome";
import { useShellCommands } from "@/features/app/model/use-shell-commands";

export function useShellModel(): ShellChromeModel {
  const shellState = useShellChrome();
  const shellCommands = useShellCommands();

  return {
    ...shellState,
    ...shellCommands,
    primaryNav: shellState.primaryNav.map((item) =>
      item.label === "Tasks"
        ? {
            ...item,
            onClick: shellCommands.showAllTasks,
          }
        : item,
    ),
    workspaceItems: shellState.workspaceItems.map((item) => ({
      ...item,
      onClick: () => void shellCommands.openWorkspaceTasks(item.id),
    })),
  };
}
