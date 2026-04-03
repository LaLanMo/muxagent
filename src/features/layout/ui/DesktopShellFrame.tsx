import type { ReactNode } from "react";
import { NavLink } from "react-router-dom";
import { ShellIcon, type ShellIconName } from "@/features/layout/ui/ShellIcon";

export type ShellNavItem = {
  label: string;
  to?: string;
  count?: number | string;
  active?: boolean;
  icon?: ShellIconName;
  onClick?: () => void;
};

export type ShellWorkspaceItem = {
  id: string;
  label: string;
  meta?: string;
  active?: boolean;
  tone?: "running" | "awaiting" | "done" | "failed" | "neutral";
  onClick: () => void;
};

type DesktopShellFrameProps = {
  topBarLeft: ReactNode;
  topBarRight?: ReactNode;
  children: ReactNode;
  workspaceItems?: ShellWorkspaceItem[];
  onAddWorkspace?: () => void;
  addWorkspaceDisabled?: boolean;
  primaryNav: ShellNavItem[];
  secondaryNav?: ShellNavItem[];
  footerNav?: ShellNavItem;
  sidebarStatusLabel?: string;
  sidebarStatusTone?: "running" | "awaiting" | "done" | "failed" | "neutral";
};

function ShellNavRow(item: ShellNavItem) {
  const rowContent = (
    <>
      <span className="shell-nav__leading">
        {item.icon ? <ShellIcon name={item.icon} /> : null}
        <span className="shell-nav__label">{item.label}</span>
      </span>
      {item.count != null ? (
        <span className="shell-nav__count">{item.count}</span>
      ) : null}
    </>
  );

  if (item.to) {
    return (
      <NavLink
        className={({ isActive }) =>
          `shell-nav__row${
            (typeof item.active === "boolean" ? item.active : isActive)
              ? " is-active"
              : ""
          }`
        }
        end={item.to === "/" || item.to.startsWith("/?")}
        to={item.to}
      >
        {rowContent}
      </NavLink>
    );
  }

  return (
    <button
      className={`shell-nav__row shell-nav__row--button${item.active ? " is-active" : ""}`}
      onClick={item.onClick}
      type="button"
    >
      {rowContent}
    </button>
  );
}

function ShellWorkspaceRow(item: ShellWorkspaceItem) {
  return (
    <button
      data-testid={`workspace-row-${item.id}`}
      className={`shell-workspace__row${item.active ? " is-active" : ""}`}
      onClick={item.onClick}
      type="button"
    >
      <span
        className={`shell-workspace__mark shell-workspace__mark--${item.tone ?? "neutral"}`}
      />
      <span className="shell-workspace__copy">
        <span className="shell-workspace__label">{item.label}</span>
        {item.meta ? <span className="shell-workspace__meta">{item.meta}</span> : null}
      </span>
    </button>
  );
}

export function DesktopShellFrame({
  topBarLeft,
  topBarRight,
  children,
  workspaceItems = [],
  onAddWorkspace,
  addWorkspaceDisabled = false,
  primaryNav,
  secondaryNav = [],
  footerNav,
  sidebarStatusLabel,
  sidebarStatusTone = "neutral",
}: DesktopShellFrameProps) {
  return (
    <main className="desktop-shell">
      <aside className="desktop-shell__sidebar">
        <div className="desktop-shell__sidebar-top">
          <div className="desktop-shell__brand-lockup">
            <span className="desktop-shell__brand-mark">&gt;m</span>
            <div className="desktop-shell__brand-copy">
              <span className="desktop-shell__brand">muxagent</span>
              {sidebarStatusLabel ? (
                <span
                  className={`desktop-shell__status desktop-shell__status--${sidebarStatusTone}`}
                >
                  <span className="desktop-shell__status-dot" />
                  {sidebarStatusLabel}
                </span>
              ) : null}
            </div>
          </div>

          <div className="shell-workspace">
            <div className="shell-workspace__header">
              <span className="shell-workspace__eyebrow">Workspaces</span>
              <span className="shell-workspace__header-meta">
                {workspaceItems.length > 0 ? (
                  <span className="shell-workspace__count">{workspaceItems.length}</span>
                ) : null}
                {onAddWorkspace ? (
                  <button
                    className="shell-workspace__add"
                    data-testid="workspace-picker-button"
                    disabled={addWorkspaceDisabled}
                    onClick={onAddWorkspace}
                    type="button"
                  >
                    Add
                  </button>
                ) : null}
              </span>
            </div>
            <div className="shell-workspace__list">
              {workspaceItems.map((item) => (
                <ShellWorkspaceRow key={item.id} {...item} />
              ))}
            </div>
          </div>

          <nav className="shell-nav">
            <div className="shell-nav__section">
              <span className="shell-nav__eyebrow">Views</span>
              <div className="shell-nav__group">
                {primaryNav.map((item) => (
                  <ShellNavRow key={`${item.label}-${item.to ?? "action"}`} {...item} />
                ))}
              </div>
            </div>
            {secondaryNav.length > 0 ? (
              <div className="shell-nav__section">
                <span className="shell-nav__eyebrow">Control</span>
                <div className="shell-nav__group">
                  {secondaryNav.map((item) => (
                    <ShellNavRow key={`${item.label}-${item.to ?? "action"}`} {...item} />
                  ))}
                </div>
              </div>
            ) : null}
          </nav>
        </div>

        {footerNav ? (
          <div className="desktop-shell__sidebar-footer">
            <ShellNavRow {...footerNav} />
          </div>
        ) : null}
      </aside>

      <div className="desktop-shell__divider" />

      <section className="desktop-shell__main">
        <header className="desktop-shell__topbar">
          <div className="desktop-shell__topbar-left">{topBarLeft}</div>
          <div className="desktop-shell__topbar-right">{topBarRight}</div>
        </header>
        <div className="desktop-shell__topbar-divider" />
        <div className="desktop-shell__content">{children}</div>
      </section>
    </main>
  );
}
