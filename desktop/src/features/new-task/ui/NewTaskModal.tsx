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
import { Button } from "@/features/shared/ui/Button";
import { ImageInputComposer } from "@/features/shared/ui/ImageInputComposer";
import type { DraftImageAttachment } from "@/features/shared/model/image-attachments";
import type { ConfigCatalogEntryDto } from "@/rpc/types";

const secondaryIconStyle = {
  color: "var(--color-text-secondary)",
  flexShrink: 0,
} as const;

const tertiaryIconStyle = {
  color: "var(--color-text-tertiary)",
  flexShrink: 0,
} as const;

/* ── Helpers ── */

function shortenPath(path: string): string {
  if (!path) return "";
  // Replace common home directory prefixes with ~
  return path.replace(/^\/Users\/[^/]+/, "~").replace(/^\/home\/[^/]+/, "~");
}

type ConfigFieldView = {
  value: string;
  placeholder: boolean;
};

type ConfigBodyView = {
  description?: string;
  runtime: ConfigFieldView;
  maxIterations: ConfigFieldView;
  entryNode: ConfigFieldView;
};

function configFieldView(value: string | number | undefined): ConfigFieldView {
  if (value === undefined || value === null || value === "") {
    return { value: "—", placeholder: true };
  }
  return { value: String(value), placeholder: false };
}

function buildConfigBodyView(args: {
  description?: string;
  runtimeName?: string;
  maxIterations?: number;
  entryNode?: string;
}): ConfigBodyView {
  return {
    description: args.description,
    runtime: configFieldView(args.runtimeName),
    maxIterations: configFieldView(args.maxIterations),
    entryNode: configFieldView(args.entryNode),
  };
}

/* ── Component ── */

type NewTaskModalProps = {
  open: boolean;
  description: string;
  onDescriptionChange: (value: string) => void;
  imageAttachments: DraftImageAttachment[];
  onImageAttachmentsChange: (attachments: DraftImageAttachment[]) => void;
  workspaceOptions: Array<{ id: string; label: string; path: string }>;
  selectedTargetWorkspaceId: string;
  onTargetWorkspaceChange: (value: string) => void;
  workspacePicking: boolean;
  onToggleWorkspacePicker: () => void;
  onCloseWorkspacePicker: () => void;
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
  imageAttachments,
  onImageAttachmentsChange,
  workspaceOptions,
  selectedTargetWorkspaceId,
  onTargetWorkspaceChange,
  workspacePicking,
  onToggleWorkspacePicker,
  onCloseWorkspacePicker,
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
  const wsCardRef = useRef<HTMLDivElement>(null);
  const cfgCardRef = useRef<HTMLDivElement>(null);
  const liveConfigBody = buildConfigBodyView({
    description: configDescription,
    runtimeName: selectedRuntimeName,
    maxIterations: configMaxIterations,
    entryNode: configEntryNode,
  });
  const stableConfigBodyRef = useRef<ConfigBodyView>(liveConfigBody);

  // Click-outside + Escape handling for the expanded pickers
  useEffect(() => {
    if (!configPicking && !workspacePicking) return;

    function handleMouseDown(event: MouseEvent) {
      const target = event.target as Node;
      if (workspacePicking && wsCardRef.current && !wsCardRef.current.contains(target)) {
        onCloseWorkspacePicker();
      }
      if (configPicking && cfgCardRef.current && !cfgCardRef.current.contains(target)) {
        onCloseConfigPicker();
      }
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        event.stopPropagation();
        onCloseWorkspacePicker();
        onCloseConfigPicker();
      }
    }

    document.addEventListener("mousedown", handleMouseDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("mousedown", handleMouseDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [
    configPicking,
    onCloseConfigPicker,
    onCloseWorkspacePicker,
    workspacePicking,
  ]);

  // Freeze the in-flow config detail footprint while the picker overlay is open.
  useEffect(() => {
    if (!configPicking) {
      stableConfigBodyRef.current = liveConfigBody;
    }
  }, [
    configPicking,
    liveConfigBody.description,
    liveConfigBody.entryNode.placeholder,
    liveConfigBody.entryNode.value,
    liveConfigBody.maxIterations.placeholder,
    liveConfigBody.maxIterations.value,
    liveConfigBody.runtime.placeholder,
    liveConfigBody.runtime.value,
  ]);

  if (!open) {
    return null;
  }

  const selectedWorkspace = workspaceOptions.find((ws) => ws.id === selectedTargetWorkspaceId) ?? workspaceOptions[0];
  const configBody = configPicking ? stableConfigBodyRef.current : liveConfigBody;

  function handleWorkspaceHeaderClick() {
    if (configPicking) {
      onCloseConfigPicker();
    }
    onToggleWorkspacePicker();
  }

  function handleSelectWorkspace(workspaceId: string) {
    onTargetWorkspaceChange(workspaceId);
    onCloseWorkspacePicker();
  }

  function handleConfigHeaderClick() {
    if (workspacePicking) {
      onCloseWorkspacePicker();
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
          <button
            className="icon-button task-modal__close"
            data-testid="new-task-close"
            onClick={onClose}
            type="button"
          >
            <X aria-hidden="true" size={16} strokeWidth={2} />
          </button>
        </header>

        <div className="task-modal__body">
          {/* Task description */}
          <div className="field-block">
            <ImageInputComposer
              ariaLabel="Task description"
              attachments={imageAttachments}
              className="image-composer--modal"
              label="Task description"
              onAttachmentsChange={onImageAttachmentsChange}
              onValueChange={onDescriptionChange}
              placeholder="Describe what you want to do..."
              rows={imageAttachments.length > 0 ? 2 : 4}
              testId="new-task-image-composer"
              textareaTestId="new-task-description"
              value={description}
            />
          </div>

          {/* Workspace selector */}
          <div className="field-block">
            <span className="field-block__label">Workspace</span>
            <div
              className={`task-modal__ws-card${workspacePicking ? " task-modal__ws-card--picking" : ""}`}
              ref={wsCardRef}
            >
              <input type="hidden" value={selectedTargetWorkspaceId} />
              <div className="task-modal__ws-anchor">
                <button
                  aria-expanded={workspacePicking}
                  className="task-modal__ws-header"
                  data-testid="new-task-workspace"
                  onClick={handleWorkspaceHeaderClick}
                  type="button"
                >
                  <div className="task-modal__ws-stack">
                    <div className="task-modal__ws-left">
                      <Folder
                        aria-hidden="true"
                        size={14}
                        strokeWidth={2}
                        style={secondaryIconStyle}
                      />
                      <span className="task-modal__ws-name">{selectedWorkspace?.label ?? "No workspace"}</span>
                    </div>
                    <span className="task-modal__ws-path">
                      {shortenPath(selectedWorkspace?.path ?? "")}
                    </span>
                  </div>
                  {workspacePicking ? (
                    <ChevronUp
                      aria-hidden="true"
                      size={14}
                      strokeWidth={2}
                      style={tertiaryIconStyle}
                    />
                  ) : (
                    <ChevronDown
                      aria-hidden="true"
                      size={14}
                      strokeWidth={2}
                      style={tertiaryIconStyle}
                    />
                  )}
                </button>
                {workspacePicking ? (
                  <div className="task-modal__ws-list" role="listbox" aria-label="Workspace">
                    {workspaceOptions.map((workspace) => {
                      const selected = workspace.id === selectedTargetWorkspaceId;
                      return (
                        <button
                          aria-selected={selected}
                          className={`task-modal__ws-option${selected ? " task-modal__ws-option--selected" : ""}`}
                          key={workspace.id}
                          onClick={() => handleSelectWorkspace(workspace.id)}
                          type="button"
                        >
                          <div className="task-modal__ws-option-row">
                            <div className="task-modal__ws-left">
                              <Folder
                                aria-hidden="true"
                                size={14}
                                strokeWidth={2}
                                style={secondaryIconStyle}
                              />
                              <span className="task-modal__ws-name">{workspace.label}</span>
                            </div>
                            {selected ? (
                              <Check
                                aria-hidden="true"
                                color="var(--color-accent)"
                                size={14}
                                strokeWidth={2.2}
                              />
                            ) : null}
                          </div>
                          <span className="task-modal__ws-path">
                            {shortenPath(workspace.path)}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                ) : null}
              </div>
            </div>
          </div>

          {/* Config selector */}
          <div className="field-block">
            <span className="field-block__label">Config</span>
            <div
              className={`task-modal__cfg-card${configPicking ? " task-modal__cfg-card--picking" : ""}`}
              ref={cfgCardRef}
            >
              <input
                data-testid="new-task-config"
                readOnly
                tabIndex={-1}
                type="hidden"
                value={selectedAlias}
              />
              <div className="task-modal__cfg-anchor">
                <button
                  aria-expanded={configPicking}
                  className="task-modal__cfg-header"
                  onClick={handleConfigHeaderClick}
                  type="button"
                >
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
                      <ChevronUp
                        aria-hidden="true"
                        size={14}
                        strokeWidth={2}
                        style={tertiaryIconStyle}
                      />
                    ) : (
                      <ChevronDown
                        aria-hidden="true"
                        size={14}
                        strokeWidth={2}
                        style={tertiaryIconStyle}
                      />
                    )}
                  </span>
                </button>

                {/* Picker list */}
                {configPicking && (
                  <div className="task-modal__cfg-list" role="listbox" aria-label="Config">
                    {entries.map((entry) => {
                      const selected = entry.alias === selectedAlias;
                      return (
                        <button
                          aria-selected={selected}
                          type="button"
                          key={entry.alias}
                          className={`task-modal__cfg-option${selected ? " task-modal__cfg-option--selected" : ""}`}
                          onClick={() => handleSelectConfig(entry.alias)}
                        >
                          <div className="task-modal__cfg-option-row">
                            <span
                              className={`task-modal__cfg-option-name${selected ? " task-modal__cfg-option-name--selected" : ""}`}
                            >
                              {entry.alias}
                            </span>
                            {selected ? (
                              <Check
                                aria-hidden="true"
                                color="var(--color-accent)"
                                size={14}
                                strokeWidth={2.2}
                              />
                            ) : null}
                          </div>
                          {entry.description ? (
                            <span className="task-modal__cfg-option-desc">{entry.description}</span>
                          ) : null}
                        </button>
                      );
                    })}
                  </div>
                )}
              </div>

              {/* Config details */}
              <div
                aria-hidden={configPicking}
                className={`task-modal__cfg-body${configPicking ? " task-modal__cfg-body--hidden" : ""}`}
              >
                {configBody.description ? (
                  <p className="task-modal__cfg-desc">{configBody.description}</p>
                ) : null}
                {configBody.description ? (
                  <div className="task-modal__cfg-divider" />
                ) : null}
                <div className="task-modal__cfg-fields">
                  <div className="task-modal__cfg-field">
                    <span className="task-modal__cfg-field-label">Runtime</span>
                    <span
                      className={`task-modal__cfg-field-value${configBody.runtime.placeholder ? " task-modal__cfg-field-value--placeholder" : ""}`}
                    >
                      {configBody.runtime.value}
                    </span>
                  </div>
                  <div className="task-modal__cfg-field">
                    <span className="task-modal__cfg-field-label">Max iterations</span>
                    <span
                      className={`task-modal__cfg-field-value${configBody.maxIterations.placeholder ? " task-modal__cfg-field-value--placeholder" : ""}`}
                    >
                      {configBody.maxIterations.value}
                    </span>
                  </div>
                  <div className="task-modal__cfg-field">
                    <span className="task-modal__cfg-field-label">Entry node</span>
                    <span
                      className={`task-modal__cfg-field-value${configBody.entryNode.placeholder ? " task-modal__cfg-field-value--placeholder" : ""}`}
                    >
                      {configBody.entryNode.value}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Flow nodes */}
          <div className="field-block">
            <span className="field-block__label">Flow nodes</span>
            <div className="task-modal__flow-line">{flowNodes.join(" · ")}</div>
          </div>

          {/* Worktree */}
          {worktreeAvailable ? (
            <div className="task-modal__wt-card">
              <div className="task-modal__wt-row" onClick={() => onToggleWorktree(!useWorktree)}>
                <div className={`task-modal__wt-check${useWorktree ? " task-modal__wt-check--checked" : ""}`}>
                  {useWorktree ? (
                    <Check
                      aria-hidden="true"
                      color="var(--color-text-on-accent)"
                      size={10}
                      strokeWidth={2.4}
                    />
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
          <Button
            data-testid="new-task-submit"
            disabled={submitting || !canSubmit}
            onClick={onSubmit}
            size="md"
            type="button"
            variant="primary"
          >
            {submitting ? "Starting…" : "Start task"}
          </Button>
        </footer>
      </section>
    </div>
  );
}
