import { Pencil, Plus, Trash2 } from "lucide-react";
import { Button } from "@/features/shared/ui/Button";
import { ConfirmDialog } from "@/features/shared/ui/ConfirmDialog";
import type { ConfigCatalogEntryDto } from "@/rpc/types";
import type { KeyboardEvent } from "react";

type ConfigCardModel = ConfigCatalogEntryDto & {
  open: () => void;
  edit: () => Promise<void>;
  remove: () => Promise<void>;
};

type ConfigsScreenProps = {
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

  function statusLabel(entry: ConfigCardModel) {
    return entry.builtin ? "builtin" : "custom";
  }

  function summaryLabel(entry: ConfigCardModel) {
    return [runtimeLabel(entry), nodeCountLabel(entry), locationLabel(entry)].join("  ·  ");
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
                <Button
                  leadingIcon={<Plus strokeWidth={2.1} />}
                  onClick={() => void createConfig()}
                  size="lg"
                  type="button"
                  variant="primary"
                >
                  New Config
                </Button>
              </div>
            </div>
          ) : (
            <div className="configs-grid">
              {entries.map((entry) => (
                <article
                  className="config-list-card"
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
                            <span
                              className={`config-list-card__state${
                                entry.builtin
                                  ? " config-list-card__state--builtin"
                                  : " config-list-card__state--custom"
                              }`}
                            >
                              {statusLabel(entry)}
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
                      <div className="config-list-card__flow-row" aria-label="Workflow nodes">
                        {entry.node_names.map((nodeName) => (
                          <span className="config-list-card__node-chip" key={`${entry.alias}-${nodeName}`}>
                            {nodeName}
                          </span>
                        ))}
                      </div>
                    ) : null}

                    {entry.load_error ? (
                      <div className="config-list-card__error">{entry.load_error}</div>
                    ) : null}

                    <p className="config-list-card__meta-line">{summaryLabel(entry)}</p>
                  </div>

                  {busyAlias === entry.alias ? (
                    <div className="config-list-card__busy">Working…</div>
                  ) : null}
                </article>
              ))}
            </div>
        )}
      </section>

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
