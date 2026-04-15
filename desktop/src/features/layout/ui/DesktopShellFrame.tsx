import type { ReactNode } from "react";
import { Plus, Trash2 } from "lucide-react";
import { NavLink } from "react-router-dom";
import { ShellIcon, type ShellIconName } from "@/features/layout/ui/ShellIcon";
import { Button } from "@/features/shared/ui/Button";
import {
  ConfirmDialog,
  type ConfirmDialogProps,
} from "@/features/shared/ui/ConfirmDialog";
import { startWindowDrag } from "@/features/layout/ui/window-drag";

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
  active?: boolean;
  badgeCount?: number;
  badgeTone?: "running" | "attention";
  onClick: () => void;
  onRemove?: () => void;
  removePending?: boolean;
};

type DesktopShellFrameProps = {
  topBarLeft: ReactNode;
  topBarRight?: ReactNode;
  topBarClassName?: string;
  children: ReactNode;
  workspaceItems?: ShellWorkspaceItem[];
  onAddWorkspace?: () => void;
  addWorkspaceDisabled?: boolean;
  onPrimaryAction?: () => void;
  primaryActionDisabled?: boolean;
  primaryNav: ShellNavItem[];
  footerNav?: ShellNavItem;
  workspaceRemoveDialog?: ConfirmDialogProps;
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
        onClick={item.onClick}
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
  const badgeClassName = item.badgeTone
    ? `shell-workspace__badge shell-workspace__badge--${item.badgeTone}`
    : "shell-workspace__badge";

  return (
    <div
      className={`shell-workspace__item${item.active ? " is-active" : ""}${
        item.removePending ? " is-pending" : ""
      }`}
      data-testid={`workspace-row-${item.id}`}
    >
      <button
        className={`shell-workspace__row${item.active ? " is-active" : ""}`}
        onClick={item.onClick}
        title={item.label}
        type="button"
      >
        <span className="shell-workspace__leading">
          <ShellIcon name="workspace" />
          <span className="shell-workspace__copy">
            <span className="shell-workspace__label">{item.label}</span>
          </span>
        </span>
        {item.active && item.badgeCount ? (
          <span className={badgeClassName}>{item.badgeCount}</span>
        ) : null}
      </button>

      {item.onRemove ? (
        <button
          aria-label={`Remove workspace ${item.label}`}
          className="icon-button shell-workspace__remove"
          data-testid="workspace-row-remove-button"
          disabled={item.removePending}
          onClick={(event) => {
            event.stopPropagation();
            item.onRemove?.();
          }}
          type="button"
        >
          <Trash2 aria-hidden="true" size={14} strokeWidth={1.9} />
        </button>
      ) : null}
    </div>
  );
}

export function DesktopShellFrame({
  topBarLeft,
  topBarRight,
  topBarClassName,
  children,
  workspaceItems = [],
  onAddWorkspace,
  addWorkspaceDisabled = false,
  onPrimaryAction,
  primaryActionDisabled = false,
  primaryNav,
  footerNav,
  workspaceRemoveDialog,
}: DesktopShellFrameProps) {
  const showWorkspacePrimaryAction = workspaceItems.length === 0 && Boolean(onAddWorkspace);
  const primaryActionLabel = showWorkspacePrimaryAction ? "New Workspace" : "New Task";
  const primaryActionTestId = showWorkspacePrimaryAction
    ? "open-new-workspace"
    : "open-new-task";
  const primaryActionHandler = showWorkspacePrimaryAction ? onAddWorkspace : onPrimaryAction;
  const sidebarPrimaryActionDisabled = showWorkspacePrimaryAction
    ? addWorkspaceDisabled
    : primaryActionDisabled;

  return (
    <>
      <main className="desktop-shell">
        <aside className="desktop-shell__sidebar">
          <div
            aria-hidden="true"
            className="desktop-shell__sidebar-drag-strip"
            onMouseDown={(event) => {
              void startWindowDrag(event);
            }}
          />
          <div className="desktop-shell__sidebar-top">
            {primaryActionHandler ? (
              <Button
                data-testid={primaryActionTestId}
                disabled={sidebarPrimaryActionDisabled}
                fullWidth
                leadingIcon={<Plus strokeWidth={2.2} />}
                onClick={primaryActionHandler}
                size="md"
                type="button"
                variant="primary"
              >
                {primaryActionLabel}
              </Button>
            ) : null}

            <nav className="shell-nav">
              <div className="shell-nav__group">
                {primaryNav.map((item) => (
                  <ShellNavRow key={`${item.label}-${item.to ?? "action"}`} {...item} />
                ))}
              </div>
            </nav>

            <div className="shell-section">
              <div className="shell-section__header">
                <span className="shell-section__title">Workspaces</span>
                {onAddWorkspace ? (
                  <button
                    className="shell-section__add"
                    data-testid="workspace-picker-button"
                    disabled={addWorkspaceDisabled}
                    onClick={onAddWorkspace}
                    type="button"
                  >
                    <Plus aria-hidden="true" size={12} strokeWidth={2.2} />
                  </button>
                ) : null}
              </div>
              <div className="shell-workspace__list">
                {workspaceItems.length > 0 ? (
                  workspaceItems.map((item) => (
                    <ShellWorkspaceRow key={item.id} {...item} />
                  ))
                ) : (
                  <div className="shell-section__empty">No workspaces yet</div>
                )}
              </div>
            </div>
          </div>

          {footerNav ? (
            <div className="desktop-shell__sidebar-footer">
              <ShellNavRow {...footerNav} />
            </div>
          ) : null}
        </aside>

        <div className="desktop-shell__divider" />

        <section className="desktop-shell__main">
          <header
            className={
              topBarClassName
                ? `desktop-shell__topbar ${topBarClassName}`
                : "desktop-shell__topbar"
            }
            onMouseDown={(event) => {
              void startWindowDrag(event);
            }}
          >
            <div className="desktop-shell__topbar-left">{topBarLeft}</div>
            {topBarRight ? (
              <div className="desktop-shell__topbar-right">{topBarRight}</div>
            ) : null}
          </header>
          <div className="desktop-shell__topbar-divider" />
          <div className="desktop-shell__content">{children}</div>
        </section>
      </main>

      {workspaceRemoveDialog ? <ConfirmDialog {...workspaceRemoveDialog} /> : null}
    </>
  );
}
