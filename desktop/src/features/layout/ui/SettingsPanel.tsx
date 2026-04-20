import { Cpu, Info } from "lucide-react";
import { NavLink } from "react-router-dom";

function rowClassName(active: boolean): string {
  return active
    ? "settings-panel-nav__row is-active"
    : "settings-panel-nav__row";
}

export function SettingsPanel() {
  return (
    <section
      aria-label="Settings navigation"
      className="settings-panel-nav"
      data-testid="settings-panel-nav"
    >
      <div className="settings-panel-nav__header">
        <span className="settings-panel-nav__eyebrow">Settings</span>
      </div>

      <div className="settings-panel-nav__list">
        <NavLink
          className={({ isActive }) => rowClassName(isActive)}
          data-testid="settings-panel-runtimes"
          to="/settings/runtimes"
        >
          <span className="settings-panel-nav__leading">
            <Cpu size={14} strokeWidth={1.9} />
            <span>Runtimes</span>
          </span>
        </NavLink>
        <NavLink
          className={({ isActive }) => rowClassName(isActive)}
          data-testid="settings-panel-about"
          to="/settings/about"
        >
          <span className="settings-panel-nav__leading">
            <Info size={14} strokeWidth={1.9} />
            <span>About</span>
          </span>
        </NavLink>
      </div>
    </section>
  );
}
