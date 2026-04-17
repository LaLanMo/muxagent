import { Plus, SlidersHorizontal } from "lucide-react";
import { useState } from "react";
import { NavLink, useNavigate } from "react-router-dom";
import {
  cloneConfig,
  pickBuiltinDefaultConfig,
  refreshConfigCatalog,
  suggestConfigAlias,
} from "@/application/configs";
import { getRuntime } from "@/app/runtime";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { Button } from "@/features/shared/ui/Button";
import { useWorkspaceStore } from "@/state/workspace-store";

type ConfigsPanelProps = {
  shell: ShellChromeModel;
};

export function ConfigsPanel({ shell }: ConfigsPanelProps) {
  const navigate = useNavigate();
  const catalog = useWorkspaceStore((state) => state.catalog);
  const setCatalog = useWorkspaceStore((state) => state.setCatalog);
  const entries = catalog?.entries ?? [];
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string>();

  async function createConfig() {
    const sourceAlias = pickBuiltinDefaultConfig(entries)?.alias;
    if (!sourceAlias) {
      setError("No source config is available to customize");
      return;
    }
    const nextAlias = suggestConfigAlias(
      sourceAlias,
      entries.map((entry) => entry.alias),
    );
    setBusy(true);
    setError(undefined);
    try {
      const cloned = await cloneConfig(getRuntime(), sourceAlias, nextAlias);
      const nextCatalog = await refreshConfigCatalog(getRuntime());
      setCatalog(nextCatalog);
      navigate(`/configs/${encodeURIComponent(cloned.alias)}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to create config");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="configs-panel" data-testid="configs-panel">
      <div className="configs-panel__header">
        <Button
          data-testid="configs-panel-new"
          disabled={busy || shell.phase !== "connected"}
          fullWidth
          leadingIcon={<Plus strokeWidth={2.2} />}
          onClick={() => void createConfig()}
          size="md"
          type="button"
          variant="primary"
        >
          New Config
        </Button>
      </div>

      {error ? (
        <div className="configs-panel__error" role="alert">
          {error}
        </div>
      ) : null}

      <div className="configs-panel__section-header">
        <span>CONFIGS</span>
        <span>{entries.length}</span>
      </div>

      <div className="configs-panel__list">
        {entries.length === 0 ? (
          <div className="configs-panel__empty">No configs yet</div>
        ) : (
          entries.map((entry) => (
            <NavLink
              className={({ isActive }) =>
                `configs-panel__row${isActive ? " is-active" : ""}`
              }
              data-testid={`configs-panel-row-${entry.alias}`}
              end
              key={entry.alias}
              to={`/configs/${encodeURIComponent(entry.alias)}`}
            >
              <span className="configs-panel__row-icon">
                <SlidersHorizontal size={14} strokeWidth={1.8} />
              </span>
              <span className="configs-panel__row-copy">
                <span className="configs-panel__row-title">{entry.alias}</span>
                {entry.runtime_name ? (
                  <span className="configs-panel__row-subtitle">
                    {entry.runtime_name}
                  </span>
                ) : null}
              </span>
              {entry.builtin ? (
                <span className="configs-panel__row-badge">builtin</span>
              ) : null}
            </NavLink>
          ))
        )}
      </div>

      <NavLink
        className="configs-panel__footer-link"
        data-testid="configs-panel-view-all"
        end
        to="/configs"
      >
        Open catalog
      </NavLink>
    </div>
  );
}
