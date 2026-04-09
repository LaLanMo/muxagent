import { Plus } from "lucide-react";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import { ConfirmDialog } from "@/features/shared/ui/ConfirmDialog";
import { useConfigEditorScreen } from "@/features/configs/model/use-config-editor-screen";
import { ConfigGraphCanvas } from "@/features/configs/ui/ConfigGraphCanvas";

type ConfigEditorScreenProps = ReturnType<typeof useConfigEditorScreen>;

export function ConfigEditorScreen({
  shell,
  loading,
  error,
  detail,
  draft,
  runtimes,
  selectedNodeName,
  selectedNode,
  selectedDefinition,
  selectedPrompt,
  outgoingEdges,
  graph,
  renameDraft,
  setRenameDraft,
  schemaText,
  setSchemaText,
  schemaError,
  validation,
  validating,
  pendingConfirmAction,
  saving,
  renaming,
  working,
  isDirty,
  selectNode,
  setDescription,
  setRuntime,
  setEntryNode,
  setTopologyMaxIterations,
  setClarificationField,
  addNode,
  removeSelectedNode,
  renameSelectedNode,
  updateSelectedNodeRef,
  updateSelectedDefinition,
  initializeSelectedPrompt,
  setSelectedPromptContent,
  saveSelectedPrompt,
  applySchema,
  addOutgoingEdge,
  updateOutgoingEdge,
  removeOutgoingEdge,
  saveDraft,
  renameCurrentConfig,
  makeDefault,
  requestRemoveCurrentConfig,
  requestResetBuiltinConfig,
  cancelPendingConfigAction,
  confirmPendingConfigAction,
}: ConfigEditorScreenProps) {
  const saveDisabled =
    saving ||
    validating ||
    !isDirty ||
    !validation?.valid;
  const promptEditable =
    Boolean(selectedNode && selectedDefinition?.type === "agent");
  const promptInitialized = Boolean(selectedDefinition?.system_prompt?.trim());
  const promptSaveDisabled =
    !selectedPrompt ||
    selectedPrompt.saving ||
    selectedPrompt.loading ||
    selectedPrompt.content === selectedPrompt.savedContent ||
    selectedPrompt.needsConfigSave;

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
          <h1 className="screen-title">{detail?.alias ?? "Config editor"}</h1>
          <div className="screen-heading__subline">
            <span className="screen-heading__support">
              {detail?.description || "Edit graph, runtime, and node properties."}
            </span>
            {detail ? (
              <>
                <StatusBadge
                  label={detail.builtin ? "builtin" : "custom"}
                  mono
                  tone={detail.builtin ? "neutral" : "running"}
                />
                {detail.is_default ? (
                  <StatusBadge label="default" mono tone="done" />
                ) : null}
              </>
            ) : null}
          </div>
        </div>
      }
      topBarRight={
        <div className="configs-topbar">
          {validation?.error ? (
            <span className="screen-meta">invalid</span>
          ) : validating ? (
            <span className="screen-meta">validating…</span>
          ) : validation?.valid ? (
            <span className="screen-meta">valid</span>
          ) : null}

          {detail?.builtin ? (
            <button
              className="secondary-action"
              data-testid="config-reset-button"
              disabled={working}
              onClick={requestResetBuiltinConfig}
              type="button"
            >
              {working ? "Working…" : "Reset to builtin"}
            </button>
          ) : null}
          <button
            className="topbar-action"
            data-testid="config-save-button"
            disabled={saveDisabled}
            onClick={() => void saveDraft()}
            type="button"
          >
            {saving ? "Saving…" : "Save"}
          </button>
        </div>
      }
    >
      <section className="config-editor-screen" data-testid="config-editor-screen">
        {loading ? (
          <div className="board-empty-state">
            <h2>Loading config…</h2>
          </div>
        ) : detail && draft ? (
          <>
            {error ? (
              <div className="config-banner config-banner--error">{error}</div>
            ) : null}
            {validation?.error ? (
              <div className="config-banner config-banner--warning">
                {validation.error}
              </div>
            ) : null}

            <div className="config-editor-layout">
              <section className="config-editor-canvas" aria-label="Config graph">
                <div className="config-editor-canvas__header">
                  <div className="config-editor-canvas__title-group">
                    <span className="field-block__label">Graph</span>
                    <h2>{detail.alias}</h2>
                  </div>
                  <div className="config-editor-canvas__actions">
                    <button
                      className="config-inline-button"
                      onClick={addNode}
                      type="button"
                    >
                      <Plus aria-hidden="true" size={14} strokeWidth={2.2} />
                      <span>Node</span>
                    </button>
                    {selectedNodeName ? (
                      <button
                        className="config-inline-button config-inline-button--danger"
                        onClick={removeSelectedNode}
                        type="button"
                      >
                        Remove
                      </button>
                    ) : null}
                  </div>
                </div>

                <div className="config-editor-canvas__stage">
                  <div className="config-editor-canvas__surface">
                    <ConfigGraphCanvas
                      graph={graph}
                      onSelectNode={selectNode}
                      selectedNodeName={selectedNodeName}
                    />
                  </div>
                </div>

                <section className="config-editor-prompt">
                  <div className="config-editor-prompt__header">
                    <div className="config-editor-prompt__title-group">
                      <span className="field-block__label">Prompt</span>
                      <h2>
                        {selectedNode ? selectedNode.name : "Select an agent node"}
                      </h2>
                    </div>

                    {promptEditable && selectedPrompt ? (
                      <div className="config-editor-prompt__actions">
                        <span className="config-editor-prompt__path">
                          {selectedPrompt.path}
                        </span>
                        <button
                          className="config-inline-button"
                          data-testid="config-prompt-save-button"
                          disabled={promptSaveDisabled}
                          onClick={() => void saveSelectedPrompt()}
                          type="button"
                        >
                          {selectedPrompt.saving ? "Saving…" : "Save prompt"}
                        </button>
                      </div>
                    ) : null}
                  </div>

                  {!selectedNode ? (
                    <div className="config-editor-prompt__empty">
                      Select a node to inspect its prompt.
                    </div>
                  ) : !promptEditable ? (
                    <div className="config-editor-prompt__empty">
                      Only agent nodes have editable prompts.
                    </div>
                  ) : !promptInitialized ? (
                    <div className="config-editor-prompt__empty">
                      <p>This agent node does not have a prompt file yet.</p>
                      <button
                        className="config-inline-button"
                        data-testid="config-prompt-init-button"
                        onClick={initializeSelectedPrompt}
                        type="button"
                      >
                        Create prompt file
                      </button>
                    </div>
                  ) : selectedPrompt ? (
                    <div className="config-editor-prompt__body">
                      {selectedPrompt.error ? (
                        <p className="config-field__error">{selectedPrompt.error}</p>
                      ) : null}
                      {selectedPrompt.needsConfigSave ? (
                        <p className="config-editor-prompt__hint">
                          Save config changes to persist this prompt file, then save the
                          prompt content.
                        </p>
                      ) : null}
                      <textarea
                        className="config-prompt-editor"
                        data-testid="config-prompt-editor"
                        disabled={selectedPrompt.loading}
                        onChange={(event) =>
                          setSelectedPromptContent(event.target.value)
                        }
                        placeholder={
                          selectedPrompt.loading
                            ? "Loading prompt…"
                            : "Write the agent instructions for this node."
                        }
                        value={selectedPrompt.content}
                      />
                    </div>
                  ) : (
                    <div className="config-editor-prompt__empty">Loading prompt…</div>
                  )}
                </section>
              </section>

              <aside className="config-editor-panel">
                <section className="config-editor-panel__section">
                  <div className="config-editor-panel__section-header">
                    <h2>Config</h2>
                    {detail.runtime_name || detail.runtime_id ? (
                      <StatusBadge
                        label={detail.runtime_name || detail.runtime_id || "Automatic"}
                        mono
                        tone={detail.runtime_configured ? "neutral" : "failed"}
                      />
                    ) : null}
                  </div>

                  <label className="config-field">
                    <span>Alias</span>
                    <div className="config-field__row">
                      <input
                        data-testid="config-alias-input"
                        disabled={detail.builtin || renaming}
                        onChange={(event) => setRenameDraft(event.target.value)}
                        value={renameDraft}
                      />
                      {!detail.builtin ? (
                        <button
                          className="config-inline-button"
                          disabled={
                            renaming ||
                            !renameDraft.trim() ||
                            renameDraft.trim() === detail.alias
                          }
                          onClick={() => void renameCurrentConfig()}
                          type="button"
                        >
                          {renaming ? "…" : "Rename"}
                        </button>
                      ) : null}
                    </div>
                  </label>

                  <label className="config-field">
                    <span>Description</span>
                    <textarea
                      data-testid="config-description-input"
                      onChange={(event) => setDescription(event.target.value)}
                      rows={3}
                      value={draft.description ?? ""}
                    />
                  </label>

                  <div className="config-field-grid">
                    <label className="config-field">
                      <span>Runtime</span>
                      <select
                        data-testid="config-runtime-select"
                        onChange={(event) => setRuntime(event.target.value)}
                        value={draft.runtime ?? ""}
                      >
                        <option value="">Automatic</option>
                        {runtimes.map((runtime) => (
                          <option key={runtime.runtime_id} value={runtime.runtime_id}>
                            {runtime.runtime_name}
                          </option>
                        ))}
                      </select>
                    </label>

                    <label className="config-field">
                      <span>Entry node</span>
                      <select
                        onChange={(event) => setEntryNode(event.target.value)}
                        value={draft.topology.entry}
                      >
                        {draft.topology.nodes.map((node) => (
                          <option key={node.name} value={node.name}>
                            {node.name}
                          </option>
                        ))}
                      </select>
                    </label>
                  </div>

                  <div className="config-field-grid config-field-grid--three">
                    <label className="config-field">
                      <span>Max iterations</span>
                      <input
                        min={1}
                        onChange={(event) =>
                          setTopologyMaxIterations(event.target.value)
                        }
                        type="number"
                        value={draft.topology.max_iterations}
                      />
                    </label>
                    <label className="config-field">
                      <span>Clarification max</span>
                      <input
                        min={1}
                        onChange={(event) =>
                          setClarificationField("max_questions", event.target.value)
                        }
                        type="number"
                        value={draft.clarification.max_questions}
                      />
                    </label>
                    <label className="config-field">
                      <span>Options</span>
                      <div className="config-field__inline-pair">
                        <input
                          min={1}
                          onChange={(event) =>
                            setClarificationField(
                              "min_options_per_question",
                              event.target.value,
                            )
                          }
                          type="number"
                          value={draft.clarification.min_options_per_question}
                        />
                        <input
                          min={1}
                          onChange={(event) =>
                            setClarificationField(
                              "max_options_per_question",
                              event.target.value,
                            )
                          }
                          type="number"
                          value={draft.clarification.max_options_per_question}
                        />
                      </div>
                    </label>
                  </div>
                </section>

                {selectedNode && selectedDefinition ? (
                  <>
                    <section className="config-editor-panel__section">
                      <div className="config-editor-panel__section-header">
                        <h2>Node</h2>
                        <span className="screen-meta">{selectedNode.name}</span>
                      </div>

                      <label className="config-field">
                        <span>Name</span>
                        <input
                          disabled={detail.builtin || renaming}
                          onChange={(event) =>
                            renameSelectedNode(event.target.value)
                          }
                          value={selectedNode.name}
                        />
                      </label>

                      <div className="config-field-grid config-field-grid--three">
                        <label className="config-field">
                          <span>Type</span>
                          <select
                            onChange={(event) =>
                              updateSelectedDefinition("type", event.target.value)
                            }
                            value={selectedDefinition.type ?? "agent"}
                          >
                            <option value="agent">agent</option>
                            <option value="human">human</option>
                            <option value="terminal">terminal</option>
                          </select>
                        </label>

                        <label className="config-field">
                          <span>Join</span>
                          <select
                            onChange={(event) =>
                              updateSelectedNodeRef(
                                "join",
                                event.target.value || undefined,
                              )
                            }
                            value={selectedNode.join ?? ""}
                          >
                            <option value="">none</option>
                            <option value="all">all</option>
                            <option value="any">any</option>
                          </select>
                        </label>

                        <label className="config-field">
                          <span>Node max</span>
                          <input
                            min={0}
                            onChange={(event) =>
                              updateSelectedNodeRef(
                                "max_iterations",
                                Number(event.target.value) || undefined,
                              )
                            }
                            type="number"
                            value={selectedNode.max_iterations ?? 0}
                          />
                        </label>
                      </div>

                      <label className="config-field">
                        <span>Prompt file</span>
                        <input
                          data-testid="config-prompt-path-input"
                          disabled
                          value={
                            selectedDefinition.system_prompt?.trim() ||
                            (selectedDefinition.type === "agent"
                              ? "./prompts/<node>.md"
                              : "Not used")
                          }
                        />
                      </label>

                      <label className="config-field">
                        <span>Max clarification rounds</span>
                        <input
                          min={0}
                          onChange={(event) =>
                            updateSelectedDefinition(
                              "max_clarification_rounds",
                              Number(event.target.value) || 0,
                            )
                          }
                          type="number"
                          value={selectedDefinition.max_clarification_rounds ?? 0}
                        />
                      </label>
                    </section>

                    <section className="config-editor-panel__section">
                      <div className="config-editor-panel__section-header">
                        <h2>Schema</h2>
                        <button
                          className="config-inline-button"
                          onClick={applySchema}
                          type="button"
                        >
                          Apply
                        </button>
                      </div>
                      <textarea
                        className="config-schema-editor"
                        onChange={(event) => setSchemaText(event.target.value)}
                        value={schemaText}
                      />
                      {schemaError ? (
                        <p className="config-field__error">{schemaError}</p>
                      ) : null}
                    </section>

                    <section className="config-editor-panel__section">
                      <div className="config-editor-panel__section-header">
                        <h2>Outgoing edges</h2>
                        <button
                          className="config-inline-button"
                          onClick={addOutgoingEdge}
                          type="button"
                        >
                          <Plus aria-hidden="true" size={14} strokeWidth={2.2} />
                          <span>Edge</span>
                        </button>
                      </div>
                      <div className="config-edges">
                        {outgoingEdges.length > 0 ? (
                          outgoingEdges.map(({ edge, index }) => (
                            <div
                              className="config-edge-card"
                              key={`${edge.from}-${edge.to}-${index}`}
                            >
                              <label className="config-field">
                                <span>To</span>
                                <select
                                  onChange={(event) =>
                                    updateOutgoingEdge(index, "to", event.target.value)
                                  }
                                  value={edge.to}
                                >
                                  {draft.topology.nodes.map((node) => (
                                    <option key={node.name} value={node.name}>
                                      {node.name}
                                    </option>
                                  ))}
                                </select>
                              </label>

                              <div className="config-field-grid">
                                <label className="config-field">
                                  <span>Condition</span>
                                  <select
                                    onChange={(event) =>
                                      updateOutgoingEdge(
                                        index,
                                        "kind",
                                        event.target.value,
                                      )
                                    }
                                    value={edge.when?.kind ?? ""}
                                  >
                                    <option value="">always</option>
                                    <option value="when">when</option>
                                    <option value="else">else</option>
                                  </select>
                                </label>

                                {edge.when?.kind === "when" ? (
                                  <>
                                    <label className="config-field">
                                      <span>Field</span>
                                      <input
                                        onChange={(event) =>
                                          updateOutgoingEdge(
                                            index,
                                            "whenField",
                                            event.target.value,
                                          )
                                        }
                                        value={String(edge.when.field ?? "")}
                                      />
                                    </label>
                                    <label className="config-field">
                                      <span>Equals</span>
                                      <input
                                        onChange={(event) =>
                                          updateOutgoingEdge(
                                            index,
                                            "equals",
                                            event.target.value,
                                          )
                                        }
                                        value={String(edge.when.equals ?? "")}
                                      />
                                    </label>
                                  </>
                                ) : null}
                              </div>

                              <button
                                className="config-inline-button config-inline-button--danger"
                                onClick={() => removeOutgoingEdge(index)}
                                type="button"
                              >
                                Remove edge
                              </button>
                            </div>
                          ))
                        ) : (
                          <p className="screen-heading__support">
                            No outgoing edges from this node yet.
                          </p>
                        )}
                      </div>
                    </section>
                  </>
                ) : null}

                <section className="config-editor-panel__footer">
                  {!detail.is_default ? (
                    <button
                      className="config-inline-button"
                      onClick={() => void makeDefault()}
                      type="button"
                    >
                      Make default
                    </button>
                  ) : null}
                  {!detail.builtin ? (
                    <button
                      className="config-inline-button config-inline-button--danger"
                      data-testid="config-delete-button"
                      disabled={working}
                      onClick={requestRemoveCurrentConfig}
                      type="button"
                    >
                      Delete
                    </button>
                  ) : null}
                </section>
              </aside>
            </div>
          </>
        ) : (
          <div className="board-empty-state">
            <h2>Config not found</h2>
            <p>{error ?? "The requested config could not be loaded."}</p>
          </div>
        )}
      </section>
      </DesktopShellFrame>

      <ConfirmDialog
        body={
          detail && pendingConfirmAction === "delete"
            ? `Delete config "${detail.alias}"? This cannot be undone.`
            : detail && pendingConfirmAction === "reset"
              ? `Reset "${detail.alias}" to the built-in defaults? This will discard your edits to the config and prompts.`
              : ""
        }
        confirmDisabled={working}
        confirmLabel={pendingConfirmAction === "reset" ? "Reset" : "Delete"}
        onCancel={cancelPendingConfigAction}
        onConfirm={() => void confirmPendingConfigAction()}
        open={Boolean(pendingConfirmAction)}
        title={pendingConfirmAction === "reset" ? "Reset config" : "Delete config"}
      />
    </>
  );
}
