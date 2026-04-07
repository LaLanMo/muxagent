import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { ConfirmDialog } from "@/features/shared/ui/ConfirmDialog";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import type { ConfigCatalogEntryDto } from "@/rpc/types";

type ConfigCardModel = ConfigCatalogEntryDto & {
  editLabel: string;
  open: () => void;
  edit: () => Promise<void>;
  setDefault: () => Promise<void>;
  remove: () => Promise<void>;
};

type ConfigsScreenProps = {
  shell: ShellChromeModel;
  count: number;
  entries: ConfigCardModel[];
  actionError?: string;
  busyAlias?: string;
  pendingRemoveEntry?: ConfigCatalogEntryDto;
  confirmRemove: () => Promise<void>;
  cancelRemove: () => void;
  createConfig: () => Promise<void>;
};

export function ConfigsScreen({
  shell,
  count,
  entries,
  actionError,
  busyAlias,
  pendingRemoveEntry,
  confirmRemove,
  cancelRemove,
  createConfig,
}: ConfigsScreenProps) {
  return (
    <>
      <DesktopShellFrame
        addWorkspaceDisabled={shell.phase !== "connected"}
        footerNav={shell.footerNav}
        onPrimaryAction={shell.openNewTask}
        primaryActionDisabled={shell.phase !== "connected" || shell.workspaceCount === 0}
        primaryNav={shell.primaryNav}
        workspaceItems={shell.workspaceItems}
        onAddWorkspace={() => void shell.addWorkspace()}
        topBarLeft={
          <div className="screen-heading">
            <h1 className="screen-title">Configs</h1>
            <span className="screen-heading__support">
              Edit built-ins, create copies, switch runtimes, and validate the task graph before saving.
            </span>
          </div>
        }
        topBarRight={
          <div className="configs-topbar">
            <span className="screen-meta">{count} configs</span>
            <button className="topbar-action" onClick={() => void createConfig()} type="button">
              + New Config
            </button>
          </div>
        }
      >
        <section className="configs-screen" data-testid="configs-screen">
          {actionError ? <div className="config-banner config-banner--error">{actionError}</div> : null}

          {entries.length === 0 ? (
            <div className="board-empty-state">
              <h2>No configs loaded</h2>
              <p>Create a config from the default starter and customize its runtime and graph.</p>
            </div>
          ) : (
            <div className="configs-grid">
              {entries.map((entry) => (
                <article
                  className="config-list-card"
                  data-testid={`config-card-${entry.alias}`}
                  key={entry.alias}
                >
                  <button
                    className="config-list-card__surface"
                    onClick={entry.open}
                    type="button"
                  >
                    <div className="config-list-card__head">
                      <div className="config-list-card__title-group">
                        <h2>{entry.alias}</h2>
                        <p>{entry.description || entry.config_path}</p>
                      </div>
                      <div className="config-list-card__badges">
                        {entry.is_default ? <StatusBadge label="default" mono tone="done" /> : null}
                        <StatusBadge
                          label={entry.runtime_name || entry.runtime_id || "Automatic"}
                          mono
                          tone={entry.runtime_configured ? "neutral" : "failed"}
                        />
                        {entry.builtin ? (
                          <StatusBadge label="builtin" mono tone="neutral" />
                        ) : (
                          <StatusBadge label="custom" mono tone="running" />
                        )}
                      </div>
                    </div>

                    <div className="config-list-card__flow">
                      {entry.node_names?.map((node) => (
                        <span className="config-list-card__flow-node" key={node}>
                          {node}
                        </span>
                      ))}
                    </div>

                    {entry.load_error ? (
                      <div className="config-list-card__error">{entry.load_error}</div>
                    ) : null}
                  </button>

                  <div className="config-list-card__actions">
                    <button
                      className="config-inline-button"
                      disabled={busyAlias === entry.alias}
                      onClick={() => void entry.edit()}
                      type="button"
                    >
                      {busyAlias === entry.alias ? "Working..." : entry.editLabel}
                    </button>

                    {!entry.is_default ? (
                      <button
                        className="config-inline-button"
                        disabled={busyAlias === entry.alias}
                        onClick={() => void entry.setDefault()}
                        type="button"
                      >
                        Make default
                      </button>
                    ) : null}

                    {!entry.builtin ? (
                      <button
                        className="config-inline-button config-inline-button--danger"
                        disabled={busyAlias === entry.alias}
                        onClick={() => void entry.remove()}
                        type="button"
                      >
                        Delete
                      </button>
                    ) : null}
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>
      </DesktopShellFrame>

      <ConfirmDialog
        body={
          pendingRemoveEntry
            ? `Delete config "${pendingRemoveEntry.alias}"? This cannot be undone.`
            : ""
        }
        confirmDisabled={Boolean(
          pendingRemoveEntry && busyAlias === pendingRemoveEntry.alias,
        )}
        confirmLabel="Delete"
        onCancel={cancelRemove}
        onConfirm={() => void confirmRemove()}
        open={Boolean(pendingRemoveEntry)}
        title="Delete config"
      />
    </>
  );
}
