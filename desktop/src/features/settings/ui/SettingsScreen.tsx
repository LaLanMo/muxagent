import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import {
  type SettingsRowModel,
  type SettingsStatusTone,
} from "@/features/settings/model/use-settings-screen";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";

type SettingsScreenProps = {
  shell: ShellChromeModel;
  appServerRows: SettingsRowModel[];
  automaticRuntime: SettingsRowModel;
  runtimeRows: SettingsRowModel[];
};

function statusToneClass(tone: SettingsStatusTone | undefined): string {
  switch (tone) {
    case "available":
      return " settings-status--available";
    case "warning":
      return " settings-status--warning";
    default:
      return "";
  }
}

function SettingsRow({
  row,
  testId,
}: {
  row: SettingsRowModel;
  testId?: string;
}) {
  return (
    <div className="settings-row" data-testid={testId}>
      <div className="settings-row__copy">
        <span className="settings-row__hint">{row.label}</span>
        <strong className={row.monospace ? "settings-row__value" : undefined}>
          {row.value}
        </strong>
        {row.detail ? <p>{row.detail}</p> : null}
      </div>
      {row.statusLabel ? (
        <span className={`settings-status${statusToneClass(row.statusTone)}`}>
          {row.statusLabel}
        </span>
      ) : null}
    </div>
  );
}

export function SettingsScreen({
  shell,
  appServerRows,
  automaticRuntime,
  runtimeRows,
}: SettingsScreenProps) {
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
          <div className="settings-section" data-testid="settings-app-server-section">
            <div className="settings-section__header">
              <span className="settings-section__eyebrow">App Server</span>
              <p className="settings-section__body-copy">
                Read-only connection details from the muxagent app-server backing
                this desktop session.
              </p>
            </div>
            {appServerRows.map((row) => (
              <SettingsRow key={row.id} row={row} />
            ))}
          </div>

          <div className="settings-section" data-testid="settings-runtime-section">
            <div className="settings-section__header">
              <span className="settings-section__eyebrow">Task Runtime</span>
              <p className="settings-section__body-copy">
                Automatic runtime selection and launcher availability for the
                task runtimes this app-server can actually start.
              </p>
            </div>
            <SettingsRow row={automaticRuntime} testId="settings-runtime-automatic" />
            {runtimeRows.map((row) => (
              <SettingsRow key={row.id} row={row} testId="settings-runtime-row" />
            ))}
          </div>
        </article>
      </section>
    </DesktopShellFrame>
  );
}
