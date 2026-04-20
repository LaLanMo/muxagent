import { FolderOpen, SquareArrowOutUpRight } from "lucide-react";
import { useMemo, useState } from "react";
import type { WorkbenchTabId } from "@/domain/routes";
import { getRuntime } from "@/app/runtime";
import {
  useWorkbenchRegions,
  useWorkbenchTab,
} from "@/features/layout/ui/workbench-surface";
import { useConfigEditorScreen } from "@/features/configs/model/use-config-editor-screen";
import { ConfigGraphCanvas } from "@/features/configs/ui/ConfigGraphCanvas";
import { Button } from "@/features/shared/ui/Button";

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
  loading,
  error,
  detail,
  draft,
  selectedNodeName,
  graph,
  validation,
  validating,
  goBackToConfigs,
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

  const inspectorPanel = useMemo(
    () => (
      <div className="config-editor-panel__body config-editor-panel__body--surface">
        <section className="config-editor-panel__section config-editor-panel__section--summary">
          <div className="config-editor-summary">
            <div className="config-editor-summary__field">
              <span className="config-editor-summary__label">Name</span>
              <span
                className="config-editor-summary__value config-editor-summary__value--headline"
                data-testid="config-editor-name"
              >
                {detail?.alias ?? "—"}
              </span>
            </div>

            <div className="config-editor-summary__field">
              <span className="config-editor-summary__label">Description</span>
              <p className="config-editor-summary__copy">
                {detail?.description || "No description provided."}
              </p>
            </div>

            <div className="config-editor-summary__field">
              <span className="config-editor-summary__label">Location</span>
              <p className="config-editor-summary__path" data-testid="config-editor-location">
                {configPathDisplay || "—"}
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
            <Button
              data-testid="config-open-in-editor-button"
              disabled={!detail}
              fullWidth
              leadingIcon={<SquareArrowOutUpRight strokeWidth={2} />}
              onClick={() => void handleOpenConfigFile()}
              size="lg"
              type="button"
              variant="primary"
            >
              Open in editor
            </Button>
            <Button
              data-testid="config-reveal-in-finder-button"
              disabled={!detail}
              fullWidth
              leadingIcon={<FolderOpen strokeWidth={2} />}
              onClick={() => void handleRevealConfigDirectory()}
              size="lg"
              type="button"
              variant="secondary"
            >
              Reveal in Finder
            </Button>
          </div>

          <p className="config-editor-panel__note">
            Edit the YAML directly in your preferred editor. Changes will be
            reloaded on next task run.
          </p>

          {fileActionError ? <p className="config-field__error">{fileActionError}</p> : null}
        </section>
      </div>
    ),
    [configPathDisplay, detail, fileActionError, statsLabel],
  );
  const workbenchTab = useMemo(
    () => ({
      key: `config-editor-tab:${detail?.alias ?? "missing"}`,
      tabId: detail ? (`config-detail:${detail.alias}` as WorkbenchTabId) : undefined,
      title: detail?.alias ?? "Config",
    }),
    [detail],
  );
  const workbenchRegions = useMemo(
    () =>
      detail && draft
        ? {
            key: `config-editor-regions:${detail.alias}`,
            tabId: `config-detail:${detail.alias}` as WorkbenchTabId,
            secondarySidebar: {
              defaultOpen: true,
              preferredSize: 320,
              panel: {
                title: "Config File",
                size: 320,
                testId: "config-editor-config-header",
                content: inspectorPanel,
              },
            },
          }
        : null,
    [detail, draft, inspectorPanel],
  );
  const usingWorkbenchTab = useWorkbenchTab(workbenchTab);
  useWorkbenchRegions(workbenchRegions);
  const layoutClassName = usingWorkbenchTab
    ? "config-editor-layout config-editor-layout--workbench"
    : "config-editor-layout";

  return (
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

            <div className={layoutClassName}>
              <section className="config-editor-canvas" aria-label="Config graph">
                <header
                  className="config-editor-canvas__header"
                  data-testid="config-editor-graph-header"
                >
                  <button
                    aria-label="Back to configs"
                    className="config-editor-canvas__back"
                    data-testid="config-editor-back"
                    onClick={goBackToConfigs}
                    type="button"
                  >
                    <span>‹  Configs</span>
                  </button>
                </header>
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

              {!usingWorkbenchTab ? (
                <aside className="config-editor-panel">
                  <header
                    className="config-editor-panel__header"
                    data-testid="config-editor-config-header"
                  >
                    <span className="config-editor-panel__eyebrow">Config File</span>
                  </header>
                  {inspectorPanel}
                </aside>
              ) : null}
            </div>
          </>
        ) : (
          <div className="board-empty-state">
            <h2>Config not found</h2>
            <p>{error ?? "The requested config could not be loaded."}</p>
          </div>
        )}
    </section>
  );
}
