import { SlidersHorizontal } from "lucide-react";
import { NavLink } from "react-router-dom";
import { useWorkspaceStore } from "@/state/workspace-store";

export function ConfigsPanel() {
  const catalog = useWorkspaceStore((state) => state.catalog);
  const entries = catalog?.entries ?? [];

  return (
    <div className="configs-panel" data-testid="configs-panel">
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
