import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import type { InitializeResult, ServiceStatusResult } from "@/rpc/types";

type SettingsScreenProps = {
  shell: ShellChromeModel;
  status?: ServiceStatusResult;
  server?: InitializeResult;
};

export function SettingsScreen({
  shell,
  status,
  server,
}: SettingsScreenProps) {
  const serverAvailable = Boolean(status || server);
  const serverLabel = server?.server_name ?? "muxagent app-server";
  const stateDirectory = status?.state_dir ?? "No state directory available";

  return (
    <DesktopShellFrame
      addWorkspaceDisabled={shell.phase !== "connected"}
      footerNav={shell.footerNav}
      onPrimaryAction={shell.openNewTask}
      primaryActionDisabled={shell.phase !== "connected" || shell.workspaceCount === 0}
      primaryNav={shell.primaryNav}
      workspaceRemoveDialog={shell.workspaceRemoveDialog}
      workspaceItems={shell.workspaceItems}
      onAddWorkspace={() => void shell.addWorkspace()}
      topBarLeft={<h1 className="screen-title">Settings</h1>}
    >
      <section className="stack-screen" data-testid="settings-screen">
        <article className="settings-panel">
          <div className="settings-section">
            <div className="settings-section__header">
              <span className="settings-section__eyebrow">Runtime</span>
            </div>
            <div className="settings-row">
              <div className="settings-row__copy">
                <strong>{serverLabel}</strong>
                <p>{stateDirectory}</p>
              </div>
              <span
                className={`settings-status${serverAvailable ? " settings-status--available" : ""}`}
              >
                {serverAvailable ? "Available" : "Not found"}
              </span>
            </div>
          </div>
        </article>
      </section>
    </DesktopShellFrame>
  );
}
