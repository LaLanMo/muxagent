import { FolderOpen, SquareArrowOutUpRight } from "lucide-react";
import { useState } from "react";
import { getRuntime } from "@/app/runtime";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { startWindowDrag } from "@/features/layout/ui/window-drag";
import { useConfigEditorScreen } from "@/features/configs/model/use-config-editor-screen";
import { ConfigGraphCanvas } from "@/features/configs/ui/ConfigGraphCanvas";

type ConfigEditorScreenProps = ReturnType<typeof useConfigEditorScreen>;

function abbreviateHomePath(path: string): string {
  const normalized = path.replace(/\\/g, "/");
  if (/^\/Users\/[^/]+/.test(normalized)) {
    return normalized.replace(/^\/Users\/[^/]+/, "~");
  }
  if (/^\/home\/[^/]+/.test(normalized)) {
    return normalized.replace(/^\/home\/[^/]+/, "~");
  }
  return path;
}

function getParentDirectory(path: string): string {
  const normalized = path.replace(/\\/g, "/");
  const separatorIndex = normalized.lastIndexOf("/");
  if (separatorIndex <= 0) {
    return path;
  }
  return normalized.slice(0, separatorIndex);
}

export function ConfigEditorScreen({
  shell,
  loading,
  error,
  detail,
  draft,
  selectedNodeName,
  graph,
  validation,
  validating,
  selectNode,
}: ConfigEditorScreenProps) {
  const [fileActionError, setFileActionError] = useState<string>();
  const nodeCount = draft?.topology.nodes.length ?? 0;
  const edgeCount = draft?.topology.edges.length ?? 0;
  const configPathDisplay = detail ? abbreviateHomePath(detail.config_path) : "";
  const graphStatusLabel = validation?.error
    ? "invalid"
    : validating
      ? "validating"
      : validation?.valid
        ? "valid"
        : "draft";
  const statsLabel = `${nodeCount} nodes · ${edgeCount} edges · ${graphStatusLabel}`;

  async function handleOpenConfigFile() {
    if (!detail) {
      return;
    }
    setFileActionError(undefined);
    try {
      await getRuntime().shell.openPath(detail.config_path);
    } catch (actionError) {
      setFileActionError(
        actionError instanceof Error ? actionError.message : "Failed to open config file",
      );
    }
  }

  async function handleRevealConfigDirectory() {
    if (!detail) {
      return;
    }
    setFileActionError(undefined);
    try {
      await getRuntime().shell.openPath(getParentDirectory(detail.config_path));
    } catch (actionError) {
      setFileActionError(
        actionError instanceof Error
          ? actionError.message
          : "Failed to reveal config directory",
      );
    }
  }

  return (
    <DesktopShellFrame
      addWorkspaceDisabled={shell.phase !== "connected"}
      footerNav={shell.footerNav}
      onPrimaryAction={shell.openNewTask}
      primaryActionDisabled={shell.phase !== "connected" || shell.workspaceCount === 0}
      primaryNav={shell.primaryNav}
      topBarClassName="desktop-shell__topbar--detail"
      topBarLeft={null}
      workspaceItems={shell.workspaceItems}
      onAddWorkspace={() => void shell.addWorkspace()}
    >
      <section className="config-editor-screen" data-testid="config-editor-screen">
        {loading ? (
          <div className="board-empty-state">
            <h2>Loading config…</h2>
          </div>
        ) : detail && draft ? (
          <>
            {error ? <div className="config-banner config-banner--error">{error}</div> : null}
            {validation?.error ? (
              <div className="config-banner config-banner--warning">{validation.error}</div>
            ) : null}

            <div className="config-editor-layout">
              <section className="config-editor-canvas" aria-label="Config graph">
                <div
                  aria-hidden="true"
                  className="config-editor-canvas__top-divider"
                  onMouseDown={(event) => {
                    void startWindowDrag(event);
                  }}
                />
                <div className="config-editor-canvas__stage">
                  <div className="config-editor-canvas__surface">
                    <ConfigGraphCanvas
                      graph={graph}
                      onSelectNode={selectNode}
                      selectedNodeName={selectedNodeName}
                    />
                  </div>
                </div>
              </section>

              <aside className="config-editor-panel">
                <header
                  className="config-editor-panel__header"
                  data-testid="config-editor-config-header"
                  onMouseDown={(event) => {
                    void startWindowDrag(event);
                  }}
                >
                  <span className="config-editor-panel__eyebrow">Config File</span>
                </header>
                <div className="config-editor-panel__body">
                  <section className="config-editor-panel__section config-editor-panel__section--summary">
                    <div className="config-editor-summary">
                      <div className="config-editor-summary__field">
                        <span className="config-editor-summary__label">Name</span>
                        <span
                          className="config-editor-summary__value config-editor-summary__value--headline"
                          data-testid="config-editor-name"
                        >
                          {detail.alias}
                        </span>
                      </div>

                      <div className="config-editor-summary__field">
                        <span className="config-editor-summary__label">Description</span>
                        <p className="config-editor-summary__copy">
                          {detail.description || "No description provided."}
                        </p>
                      </div>

                      <div className="config-editor-summary__field">
                        <span className="config-editor-summary__label">Location</span>
                        <p
                          className="config-editor-summary__path"
                          data-testid="config-editor-location"
                        >
                          {configPathDisplay}
                        </p>
                      </div>

                      <div className="config-editor-summary__field">
                        <span className="config-editor-summary__label">Stats</span>
                        <span
                          className="config-editor-summary__value config-editor-summary__value--mono"
                          data-testid="config-editor-stats"
                        >
                          {statsLabel}
                        </span>
                      </div>
                    </div>

                    <div className="config-editor-panel__summary-actions">
                      <button
                        className="config-editor-panel__file-action config-editor-panel__file-action--primary"
                        data-testid="config-open-in-editor-button"
                        onClick={() => void handleOpenConfigFile()}
                        type="button"
                      >
                        <SquareArrowOutUpRight aria-hidden="true" size={14} strokeWidth={2} />
                        <span>Open in editor</span>
                      </button>
                      <button
                        className="config-editor-panel__file-action"
                        data-testid="config-reveal-in-finder-button"
                        onClick={() => void handleRevealConfigDirectory()}
                        type="button"
                      >
                        <FolderOpen aria-hidden="true" size={14} strokeWidth={2} />
                        <span>Reveal in Finder</span>
                      </button>
                    </div>

                    <p className="config-editor-panel__note">
                      Edit the YAML directly in your preferred editor. Changes will be
                      reloaded on next task run.
                    </p>

                    {fileActionError ? (
                      <p className="config-field__error">{fileActionError}</p>
                    ) : null}
                  </section>
                </div>
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
  );
}
