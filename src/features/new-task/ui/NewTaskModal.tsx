import type { ConfigCatalogEntryDto } from "@/rpc/types";

type NewTaskModalProps = {
  open: boolean;
  description: string;
  onDescriptionChange: (value: string) => void;
  workspaceOptions: Array<{ id: string; label: string }>;
  selectedTargetWorkspaceId: string;
  onTargetWorkspaceChange: (value: string) => void;
  entries: ConfigCatalogEntryDto[];
  selectedAlias: string;
  onAliasChange: (value: string) => void;
  configDescription?: string;
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
  if (!open) {
    return null;
  }

  return (
    <div className="modal-layer" data-testid="new-task-modal">
      <div className="modal-scrim" onClick={onClose} />
      <section className="task-modal">
        <header className="task-modal__header">
          <h2>New Task</h2>
          <button className="icon-button" onClick={onClose} type="button">
            ×
          </button>
        </header>

        <div className="task-modal__body">
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

          <label className="field-block">
            <span className="field-block__label">Workspace</span>
            <div className="task-modal__config-card">
              <select
                className="task-modal__select"
                data-testid="new-task-workspace"
                onChange={(event) => onTargetWorkspaceChange(event.target.value)}
                value={selectedTargetWorkspaceId}
              >
                {workspaceOptions.map((workspace) => (
                  <option key={workspace.id} value={workspace.id}>
                    {workspace.label}
                  </option>
                ))}
              </select>
            </div>
          </label>

          <label className="field-block">
            <span className="field-block__label">Config</span>
            <div className="task-modal__config-card">
              <select
                className="task-modal__select"
                data-testid="new-task-config"
                onChange={(event) => onAliasChange(event.target.value)}
                value={selectedAlias}
              >
                {entries.map((entry) => (
                  <option key={entry.alias} value={entry.alias}>
                    {entry.alias}
                  </option>
                ))}
              </select>
              {configDescription ? (
                <p className="task-modal__config-description">
                  {configDescription}
                </p>
              ) : null}
            </div>
          </label>

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

          {worktreeAvailable ? (
            <label className="task-modal__checkbox">
              <input
                checked={useWorktree}
                onChange={(event) => onToggleWorktree(event.target.checked)}
                type="checkbox"
              />
              <span>Launch in worktree</span>
            </label>
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
