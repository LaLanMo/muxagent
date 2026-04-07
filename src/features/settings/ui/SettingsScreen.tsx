import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import type { SettingsWorkspaceRowModel } from "@/features/settings/model/use-settings-screen";
import type { InitializeResult, ServiceStatusResult } from "@/rpc/types";

type SettingsScreenProps = {
  shell: ShellChromeModel;
  status?: ServiceStatusResult;
  workDir?: string;
  server?: InitializeResult;
  workspaceRows: SettingsWorkspaceRowModel[];
  renameDraft: string;
  setRenameDraft: (value: string) => void;
  workspaceActionError?: string;
  beginRename: (workspaceId: string) => void;
  cancelRename: () => void;
  commitRename: (workspaceId: string) => Promise<void>;
  removeWorkspace: (workspaceId: string) => Promise<void>;
};

export function SettingsScreen({
  shell,
  status,
  workDir,
  server,
  workspaceRows,
  renameDraft,
  setRenameDraft,
  workspaceActionError,
  beginRename,
  cancelRename,
  commitRename,
  removeWorkspace,
}: SettingsScreenProps) {
  const selectedWorkspaceValue = workDir ? shell.workspaceLabel : "None";
  const selectedWorkspacePath = workDir || "No workspace selected";

  return (
    <DesktopShellFrame
      addWorkspaceDisabled={shell.phase !== "connected"}
      footerNav={shell.footerNav}
      onPrimaryAction={shell.openNewTask}
      primaryActionDisabled={shell.phase !== "connected" || shell.workspaceCount === 0}
      primaryNav={shell.primaryNav}
      workspaceItems={shell.workspaceItems}
      onAddWorkspace={() => void shell.addWorkspace()}
      topBarLeft={<h1 className="screen-title">Settings</h1>}
      topBarRight={<span className="screen-meta">{status?.server_version ?? "local app-server"}</span>}
    >
      <section className="stack-screen" data-testid="settings-screen">
        <article className="settings-panel">
          <div className="settings-section">
            <span className="settings-section__eyebrow">General</span>
            <div className="settings-row">
              <div className="settings-row__copy">
                <strong>Selected workspace</strong>
                <p>{selectedWorkspacePath}</p>
              </div>
              <span className="settings-row__value">{selectedWorkspaceValue}</span>
            </div>
            <div className="settings-row">
              <div className="settings-row__copy">
                <strong>Server</strong>
                <p>{server?.server_name ?? "muxagent app-server"}</p>
              </div>
              <span className="settings-row__value">{status?.server_version ?? "n/a"}</span>
            </div>
            <div className="settings-row">
              <div className="settings-row__copy">
                <strong>State dir</strong>
                <p>{status?.state_dir ?? "n/a"}</p>
              </div>
              <span className="settings-row__value">Local</span>
            </div>
          </div>

          <div className="settings-section" id="runtime">
            <span className="settings-section__eyebrow">Runtime / Service</span>
            <div className="settings-row">
              <div className="settings-row__copy">
                <strong>Protocol</strong>
                <p>Current app-server wire protocol.</p>
              </div>
              <span className="settings-row__value">{status?.protocol_version ?? "n/a"}</span>
            </div>
            <div className="settings-row">
              <div className="settings-row__copy">
                <strong>Workspaces</strong>
                <p>Registered desktop workspaces.</p>
              </div>
              <span className="settings-row__value">{status?.workspace_count ?? "0"}</span>
            </div>
            <div className="settings-row">
              <div className="settings-row__copy">
                <strong>Connected clients</strong>
                <p>Desktop sessions currently attached.</p>
              </div>
              <span className="settings-row__value">{status?.connected_clients ?? "0"}</span>
            </div>
            <div className="settings-row">
              <div className="settings-row__copy">
                <strong>Configured runtimes</strong>
                <p>Runtime backends available to launch configs.</p>
              </div>
              <span className="settings-row__value">{status?.runtime_count ?? "0"}</span>
            </div>
          </div>

          <div className="settings-section">
            <span className="settings-section__eyebrow">Workspaces</span>
            {workspaceActionError ? (
              <div className="inline-banner inline-banner--failed">{workspaceActionError}</div>
            ) : null}
            {workspaceRows.length === 0 ? (
              <div className="board-empty-state board-empty-state--compact">
                <h2>No workspaces</h2>
                <p>Add a workspace from the sidebar to register it with the desktop shell.</p>
              </div>
            ) : (
              <div className="workspace-settings-list">
                {workspaceRows.map((workspace) => (
                  <article
                    className="workspace-settings-row"
                    data-testid="settings-workspace-row"
                    key={workspace.id}
                  >
                    <div className="workspace-settings-row__copy">
                      <div className="workspace-settings-row__heading">
                        {workspace.editing ? (
                          <input
                            className="workspace-settings-row__input"
                            data-testid="workspace-rename-input"
                            onChange={(event) => setRenameDraft(event.target.value)}
                            value={renameDraft}
                          />
                        ) : (
                          <strong>{workspace.label}</strong>
                        )}
                        {workspace.selected ? (
                          <StatusBadge label="selected" mono tone="neutral" />
                        ) : null}
                        <StatusBadge
                          label={workspace.reachable ? "reachable" : "missing"}
                          mono
                          tone={workspace.reachable ? "done" : "failed"}
                        />
                        <StatusBadge
                          label={workspace.actorState}
                          mono
                          tone={
                            workspace.actorState === "Running"
                              ? "running"
                              : workspace.actorState === "Failed"
                                ? "failed"
                                : "neutral"
                          }
                        />
                      </div>
                      <p>{workspace.path}</p>
                      <span className="settings-row__hint">
                        {workspace.pathLabel} · {workspace.taskSummary}
                      </span>
                    </div>
                    <div className="workspace-settings-row__actions">
                      {workspace.editing ? (
                        <>
                          <button
                            className="primary-action"
                            data-testid="workspace-rename-save"
                            disabled={workspace.pendingRename || !renameDraft.trim()}
                            onClick={() => void commitRename(workspace.id)}
                            type="button"
                          >
                            {workspace.pendingRename ? "Saving…" : "Save"}
                          </button>
                          <button
                            className="secondary-action"
                            onClick={cancelRename}
                            type="button"
                          >
                            Cancel
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            className="secondary-action"
                            data-testid="workspace-rename-button"
                            onClick={() => void beginRename(workspace.id)}
                            type="button"
                          >
                            Rename
                          </button>
                          <button
                            className="secondary-action secondary-action--danger"
                            data-testid="workspace-remove-button"
                            disabled={workspace.pendingRemove}
                            onClick={() => void removeWorkspace(workspace.id)}
                            type="button"
                          >
                            {workspace.pendingRemove ? "Removing…" : "Remove"}
                          </button>
                        </>
                      )}
                    </div>
                  </article>
                ))}
              </div>
            )}
          </div>

          <div className="settings-section settings-section--danger">
            <span className="settings-section__eyebrow">Danger zone</span>
            <div className="settings-row settings-row--danger">
              <div className="settings-row__copy">
                <strong>Disconnect app-server</strong>
                <p>Disconnect the desktop client from the local task control plane.</p>
              </div>
              <button
                className="secondary-action secondary-action--danger"
                onClick={() => void shell.disconnect()}
                type="button"
              >
                Disconnect
              </button>
            </div>
          </div>
        </article>
      </section>
    </DesktopShellFrame>
  );
}
