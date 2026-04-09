import { useEffect, useRef } from "react";
import {
  Check,
  ChevronDown,
  ChevronUp,
  Folder,
  GitBranch,
  SlidersHorizontal,
  X,
} from "lucide-react";
import type { ConfigCatalogEntryDto } from "@/rpc/types";

const secondaryIconStyle = {
  color: "var(--text-secondary)",
  flexShrink: 0,
} as const;

const tertiaryIconStyle = {
  color: "var(--text-tertiary)",
  flexShrink: 0,
} as const;

/* ── Helpers ── */

function shortenPath(path: string): string {
  if (!path) return "";
  // Replace common home directory prefixes with ~
  return path.replace(/^\/Users\/[^/]+/, "~").replace(/^\/home\/[^/]+/, "~");
}

/* ── Component ── */

type NewTaskModalProps = {
  open: boolean;
  description: string;
  onDescriptionChange: (value: string) => void;
  workspaceOptions: Array<{ id: string; label: string; path: string }>;
  selectedTargetWorkspaceId: string;
  onTargetWorkspaceChange: (value: string) => void;
  entries: ConfigCatalogEntryDto[];
  selectedAlias: string;
  onAliasChange: (value: string) => void;
  configDescription?: string;
  selectedRuntimeName?: string;
  configMaxIterations?: number;
  configEntryNode?: string;
  configPicking: boolean;
  onToggleConfigPicker: () => void;
  onCloseConfigPicker: () => void;
  flowNodes: string[];
  worktreeAvailable: boolean;
  useWorktree: boolean;
  onToggleWorktree: (nextValue: boolean) => void;
  onClose: () => void;
  onSubmit: () => void;
  submitting: boolean;
  canSubmit: boolean;
  error?: string;
};

export function NewTaskModal({
  open,
  description,
  onDescriptionChange,
  workspaceOptions,
  selectedTargetWorkspaceId,
  onTargetWorkspaceChange,
  entries,
  selectedAlias,
  onAliasChange,
  configDescription,
  selectedRuntimeName,
  configMaxIterations,
  configEntryNode,
  configPicking,
  onToggleConfigPicker,
  onCloseConfigPicker,
  flowNodes,
  worktreeAvailable,
  useWorktree,
  onToggleWorktree,
  onClose,
  onSubmit,
  submitting,
  canSubmit,
  error,
}: NewTaskModalProps) {
  const cfgCardRef = useRef<HTMLDivElement>(null);
  const collapsedHeightRef = useRef<number | null>(null);

  // Click-outside + Escape handling for config picker
  useEffect(() => {
    if (!configPicking) return;

    function handleMouseDown(event: MouseEvent) {
      if (cfgCardRef.current && !cfgCardRef.current.contains(event.target as Node)) {
        onCloseConfigPicker();
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.stopPropagation();
        onCloseConfigPicker();
      }
    }

    document.addEventListener("mousedown", handleMouseDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("mousedown", handleMouseDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [configPicking, onCloseConfigPicker]);

  if (!open) {
    return null;
  }

  const selectedWorkspace = workspaceOptions.find((ws) => ws.id === selectedTargetWorkspaceId) ?? workspaceOptions[0];

  function handleHeaderClick() {
    if (!configPicking && cfgCardRef.current) {
      collapsedHeightRef.current = cfgCardRef.current.offsetHeight;
    }
    onToggleConfigPicker();
  }

  function handleSelectConfig(alias: string) {
    onAliasChange(alias);
    onCloseConfigPicker();
  }

  return (
    <div className="modal-layer" data-testid="new-task-modal">
      <div className="modal-scrim" onClick={onClose} />
      <section className="task-modal">
        <header className="task-modal__header">
          <h2>New Task</h2>
          <button className="icon-button task-modal__close" onClick={onClose} type="button">
            <X aria-hidden="true" size={16} strokeWidth={2} />
          </button>
        </header>

        <div className="task-modal__body">
          {/* Task description */}
          <label className="field-block">
            <span className="field-block__label">Task description</span>
            <textarea
              className="task-modal__textarea"
              data-testid="new-task-description"
              onChange={(event) => onDescriptionChange(event.target.value)}
              placeholder="Describe what you want to do..."
              rows={4}
              value={description}
            />
          </label>

          {/* Workspace selector */}
          <div className="field-block">
            <span className="field-block__label">Workspace</span>
            <div className="task-modal__ws-card">
              <div className="task-modal__ws-left">
                <Folder
                  aria-hidden="true"
                  size={14}
                  strokeWidth={2}
                  style={secondaryIconStyle}
                />
                <span className="task-modal__ws-name">{selectedWorkspace?.label ?? ""}</span>
              </div>
              <span className="task-modal__ws-path">
                {shortenPath(selectedWorkspace?.path ?? "")}
              </span>
              <ChevronDown
                aria-hidden="true"
                size={14}
                strokeWidth={2}
                style={tertiaryIconStyle}
              />
              <select
                data-testid="new-task-workspace"
                onChange={(event) => onTargetWorkspaceChange(event.target.value)}
                value={selectedTargetWorkspaceId}
              >
                {workspaceOptions.map((ws) => (
                  <option key={ws.id} value={ws.id}>
                    {ws.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {/* Config selector */}
          <div className="field-block">
            <span className="field-block__label">Config</span>
            <div
              className={`task-modal__cfg-card${configPicking ? " task-modal__cfg-card--picking" : ""}`}
              ref={cfgCardRef}
              style={configPicking && collapsedHeightRef.current ? { height: collapsedHeightRef.current } : undefined}
            >
              <input
                data-testid="new-task-config"
                readOnly
                tabIndex={-1}
                type="hidden"
                value={selectedAlias}
              />
              <div className="task-modal__cfg-header" onClick={handleHeaderClick}>
                <div className="task-modal__cfg-left">
                  <SlidersHorizontal
                    aria-hidden="true"
                    size={14}
                    strokeWidth={2}
                    style={secondaryIconStyle}
                  />
                  <span className="task-modal__cfg-name">{selectedAlias}</span>
                </div>
                <span style={{ display: "grid", placeItems: "center" }}>
                  {configPicking ? (
                    <ChevronDown
                      aria-hidden="true"
                      size={14}
                      strokeWidth={2}
                      style={tertiaryIconStyle}
                    />
                  ) : (
                    <ChevronUp
                      aria-hidden="true"
                      size={14}
                      strokeWidth={2}
                      style={tertiaryIconStyle}
                    />
                  )}
                </span>
              </div>

              {/* Config details */}
              {!configPicking && (
                <div className="task-modal__cfg-body">
                  {configDescription ? (
                    <p className="task-modal__cfg-desc">{configDescription}</p>
                  ) : null}
                  {configDescription && selectedRuntimeName ? (
                    <div className="task-modal__cfg-divider" />
                  ) : null}
                  {(selectedRuntimeName || configMaxIterations !== undefined || configEntryNode) ? (
                    <div className="task-modal__cfg-fields">
                      {selectedRuntimeName ? (
                        <div className="task-modal__cfg-field">
                          <span className="task-modal__cfg-field-label">Runtime</span>
                          <span className="task-modal__cfg-field-value">{selectedRuntimeName}</span>
                        </div>
                      ) : null}
                      {configMaxIterations !== undefined ? (
                        <div className="task-modal__cfg-field">
                          <span className="task-modal__cfg-field-label">Max iterations</span>
                          <span className="task-modal__cfg-field-value">{String(configMaxIterations)}</span>
                        </div>
                      ) : null}
                      {configEntryNode ? (
                        <div className="task-modal__cfg-field">
                          <span className="task-modal__cfg-field-label">Entry node</span>
                          <span className="task-modal__cfg-field-value">{configEntryNode}</span>
                        </div>
                      ) : null}
                    </div>
                  ) : null}
                </div>
              )}

              {/* Picker list */}
              {configPicking && (
                <div className="task-modal__cfg-list">
                  {entries.map((entry) => (
                    <div
                      key={entry.alias}
                      className={`task-modal__cfg-option${entry.alias === selectedAlias ? " task-modal__cfg-option--selected" : ""}`}
                      onClick={() => handleSelectConfig(entry.alias)}
                    >
                      <div className="task-modal__cfg-option-row">
                        <span
                          className={`task-modal__cfg-option-name${entry.alias === selectedAlias ? " task-modal__cfg-option-name--selected" : ""}`}
                        >
                          {entry.alias}
                        </span>
                        {entry.alias === selectedAlias && (
                          <Check
                            aria-hidden="true"
                            color="var(--accent)"
                            size={14}
                            strokeWidth={2.2}
                          />
                        )}
                      </div>
                      {entry.description ? (
                        <span className="task-modal__cfg-option-desc">{entry.description}</span>
                      ) : null}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Flow nodes */}
          <div className="field-block">
            <span className="field-block__label">Flow nodes</span>
            <div className="flow-node-inline flow-node-inline--modal">
              {flowNodes.map((node) => (
                <span className="flow-node-inline__item" key={node}>
                  {node}
                </span>
              ))}
            </div>
          </div>

          {/* Worktree */}
          {worktreeAvailable ? (
            <div className="task-modal__wt-card">
              <div className="task-modal__wt-row" onClick={() => onToggleWorktree(!useWorktree)}>
                <div className={`task-modal__wt-check${useWorktree ? " task-modal__wt-check--checked" : ""}`}>
                  {useWorktree ? (
                    <Check aria-hidden="true" color="#fff" size={10} strokeWidth={2.4} />
                  ) : null}
                </div>
                <GitBranch
                  aria-hidden="true"
                  size={14}
                  strokeWidth={2}
                  style={secondaryIconStyle}
                />
                <span className="task-modal__wt-label">Launch in worktree</span>
              </div>
              <span className="task-modal__wt-desc">Run task in an isolated git worktree branch</span>
            </div>
          ) : null}

          {error ? <p className="screen-error">{error}</p> : null}
        </div>

        <footer className="task-modal__footer">
          <button
            className="primary-action"
            data-testid="new-task-submit"
            disabled={submitting || !canSubmit}
            onClick={onSubmit}
            type="button"
          >
            {submitting ? "Starting…" : "Start task"}
          </button>
        </footer>
      </section>
    </div>
  );
}
