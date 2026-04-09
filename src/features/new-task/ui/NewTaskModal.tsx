import { useEffect, useRef } from "react";
import type { ConfigCatalogEntryDto } from "@/rpc/types";

/* ── Inline Lucide icons (24x24 viewBox, stroke 2) ── */

const svgBase = {
  "aria-hidden": true as const,
  fill: "none",
  stroke: "currentColor",
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  strokeWidth: 2,
  viewBox: "0 0 24 24",
};

function CloseIcon() {
  return (
    <svg {...svgBase} width={16} height={16}>
      <path d="M18 6 6 18" />
      <path d="m6 6 12 12" />
    </svg>
  );
}

function FolderIcon() {
  return (
    <svg {...svgBase} width={14} height={14} style={{ color: "var(--text-secondary)", flexShrink: 0 }}>
      <path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z" />
    </svg>
  );
}

function SlidersIcon() {
  return (
    <svg {...svgBase} width={14} height={14} style={{ color: "var(--text-secondary)", flexShrink: 0 }}>
      <line x1="4" x2="4" y1="21" y2="14" />
      <line x1="4" x2="4" y1="10" y2="3" />
      <line x1="12" x2="12" y1="21" y2="12" />
      <line x1="12" x2="12" y1="8" y2="3" />
      <line x1="20" x2="20" y1="21" y2="16" />
      <line x1="20" x2="20" y1="12" y2="3" />
      <line x1="2" x2="6" y1="14" y2="14" />
      <line x1="10" x2="14" y1="8" y2="8" />
      <line x1="18" x2="22" y1="16" y2="16" />
    </svg>
  );
}

function ChevronDownIcon() {
  return (
    <svg {...svgBase} width={14} height={14} style={{ color: "var(--text-tertiary)", flexShrink: 0 }}>
      <path d="m6 9 6 6 6-6" />
    </svg>
  );
}

function ChevronUpIcon() {
  return (
    <svg {...svgBase} width={14} height={14} style={{ color: "var(--text-tertiary)", flexShrink: 0 }}>
      <path d="m18 15-6-6-6 6" />
    </svg>
  );
}

function GitBranchIcon() {
  return (
    <svg {...svgBase} width={14} height={14} style={{ color: "var(--text-secondary)", flexShrink: 0 }}>
      <line x1="6" x2="6" y1="3" y2="15" />
      <circle cx="18" cy="6" r="3" />
      <circle cx="6" cy="18" r="3" />
      <path d="M18 9a9 9 0 0 1-9 9" />
    </svg>
  );
}

function CheckIcon({ size = 14, color }: { size?: number; color?: string }) {
  return (
    <svg {...svgBase} width={size} height={size} style={{ color: color ?? "currentColor", flexShrink: 0 }}>
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}

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
            <CloseIcon />
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
                <FolderIcon />
                <span className="task-modal__ws-name">{selectedWorkspace?.label ?? ""}</span>
              </div>
              <span className="task-modal__ws-path">
                {shortenPath(selectedWorkspace?.path ?? "")}
              </span>
              <ChevronDownIcon />
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
                  <SlidersIcon />
                  <span className="task-modal__cfg-name">{selectedAlias}</span>
                </div>
                <span style={{ display: "grid", placeItems: "center" }}>
                  {configPicking ? <ChevronDownIcon /> : <ChevronUpIcon />}
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
                          <CheckIcon size={14} color="var(--accent)" />
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
                  {useWorktree && <CheckIcon size={10} color="#fff" />}
                </div>
                <GitBranchIcon />
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
