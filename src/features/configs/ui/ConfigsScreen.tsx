import { Pencil, Plus, Star, Trash2 } from "lucide-react";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { ConfirmDialog } from "@/features/shared/ui/ConfirmDialog";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import type { ConfigCatalogEntryDto } from "@/rpc/types";
import type { KeyboardEvent } from "react";

type ConfigCardModel = ConfigCatalogEntryDto & {
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
  function runtimeLabel(entry: ConfigCardModel) {
    return entry.runtime_name || entry.runtime_id || "automatic";
  }

  function nodeCountLabel(entry: ConfigCardModel) {
    const nodeCount = entry.node_names?.length ?? 0;
    return `${nodeCount} node${nodeCount === 1 ? "" : "s"}`;
  }

  function locationLabel(entry: ConfigCardModel) {
    const source = entry.bundle_path || entry.config_path;
    const parts = source.split(/[\\/]/).filter(Boolean);
    return parts.at(-1) || source;
  }

  function handleSurfaceKeyDown(
    event: KeyboardEvent<HTMLElement>,
    open: () => void,
  ) {
    if (event.key !== "Enter" && event.key !== " ") {
      return;
    }
    event.preventDefault();
    open();
  }

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
          <h1 className="screen-title">Configs</h1>
        }
        topBarRight={
          <div className="configs-topbar">
            <button
              aria-label="+ New Config"
              className="topbar-action"
              onClick={() => void createConfig()}
              type="button"
            >
              <Plus aria-hidden="true" size={14} strokeWidth={2.2} />
              <span>New Config</span>
            </button>
          </div>
        }
      >
        <section
          aria-label={`Configs (${count})`}
          className="configs-screen"
          data-testid="configs-screen"
        >
          {actionError ? <div className="config-banner config-banner--error">{actionError}</div> : null}

          {entries.length === 0 ? (
            <div className="configs-empty-state">
              <div className="configs-empty-state__icon" aria-hidden="true">
                <Plus size={24} strokeWidth={1.8} />
              </div>
              <h2>No configs yet</h2>
              <p>Configs define how tasks flow between agents. Start with the built-in default, or create your own.</p>
              <div className="configs-empty-state__actions">
                <button className="primary-action" onClick={() => void createConfig()} type="button">
                  New Config
                </button>
              </div>
            </div>
          ) : (
            <div className="configs-grid">
              {entries.map((entry) => (
                <article
                  className={`config-list-card${entry.is_default ? " config-list-card--active" : ""}`}
                  data-testid={`config-card-${entry.alias}`}
                  key={entry.alias}
                >
                  <div
                    aria-label={`Open config ${entry.alias}`}
                    className="config-list-card__surface"
                    onClick={entry.open}
                    onKeyDown={(event) => handleSurfaceKeyDown(event, entry.open)}
                    role="button"
                    tabIndex={0}
                  >
                    <div className="config-list-card__head">
                      <div className="config-list-card__title-group">
                        <div className="config-list-card__headline">
                          <h2>{entry.alias}</h2>
                          <div className="config-list-card__badges">
                            {entry.is_default ? (
                              <span className="config-list-card__state config-list-card__state--default">
                                default
                              </span>
                            ) : null}
                            <span
                              className={`config-list-card__state${
                                entry.builtin
                                  ? " config-list-card__state--builtin"
                                  : " config-list-card__state--custom"
                              }`}
                            >
                              {entry.builtin ? "builtin" : "custom"}
                            </span>
                          </div>
                        </div>
                        <p>{entry.description || "No description provided."}</p>
                      </div>
                      <div className="config-list-card__actions">
                        <button
                          aria-label="Edit"
                          className="config-list-card__icon-action"
                          disabled={busyAlias === entry.alias}
                          onClick={(event) => {
                            event.stopPropagation();
                            void entry.edit();
                          }}
                          type="button"
                        >
                          <Pencil aria-hidden="true" size={14} strokeWidth={1.9} />
                        </button>
                        {!entry.builtin ? (
                          <button
                            aria-label="Delete"
                            className="config-list-card__icon-action"
                            disabled={busyAlias === entry.alias}
                            onClick={(event) => {
                              event.stopPropagation();
                              void entry.remove();
                            }}
                            type="button"
                          >
                            <Trash2 aria-hidden="true" size={14} strokeWidth={1.9} />
                          </button>
                        ) : null}
                      </div>
                    </div>

                    {entry.node_names?.length ? (
                      <p className="config-list-card__flow-line">
                        {entry.node_names.join(" · ")}
                      </p>
                    ) : null}

                    {entry.load_error ? (
                      <div className="config-list-card__error">{entry.load_error}</div>
                    ) : null}

                    <div className="config-list-card__meta-row">
                      <p className="config-list-card__meta-line">
                        <span className="config-list-card__meta-label">runtime</span>
                        <span className="config-list-card__meta-value">{runtimeLabel(entry)}</span>
                        <span className="config-list-card__meta-divider" aria-hidden="true">
                          ·
                        </span>
                        <span className="config-list-card__meta-label">nodes</span>
                        <span className="config-list-card__meta-value">{nodeCountLabel(entry)}</span>
                        <span className="config-list-card__meta-divider" aria-hidden="true">
                          ·
                        </span>
                        <span className="config-list-card__meta-label">file</span>
                        <span className="config-list-card__meta-value">{locationLabel(entry)}</span>
                      </p>
                      {!entry.is_default ? (
                        <button
                          className="config-list-card__default-action"
                          disabled={busyAlias === entry.alias}
                          onClick={(event) => {
                            event.stopPropagation();
                            void entry.setDefault();
                          }}
                          type="button"
                        >
                          <Star aria-hidden="true" size={12} strokeWidth={1.9} />
                          <span>Make default</span>
                        </button>
                      ) : (
                        <span className="config-list-card__default-note">Default for new tasks</span>
                      )}
                    </div>
                  </div>

                  {busyAlias === entry.alias ? (
                    <div className="config-list-card__busy">Working…</div>
                  ) : null}
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
