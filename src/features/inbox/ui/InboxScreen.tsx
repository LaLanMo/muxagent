import { Link } from "react-router-dom";
import { formatRelativeTime } from "@/domain/task-shell";
import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import type { InboxItem } from "@/domain/task-shell";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";

type InboxScreenProps = {
  shell: ShellChromeModel;
  items: InboxItem[];
};

export function InboxScreen({ shell, items }: InboxScreenProps) {
  return (
    <DesktopShellFrame
      addWorkspaceDisabled={shell.phase !== "connected"}
      footerNav={shell.footerNav}
      primaryNav={shell.primaryNav}
      secondaryNav={shell.secondaryNav}
      sidebarStatusLabel={shell.connectionLabel}
      sidebarStatusTone={shell.connectionTone}
      workspaceItems={shell.workspaceItems}
      onAddWorkspace={() => void shell.addWorkspace()}
      topBarLeft={<h1 className="screen-title">Inbox</h1>}
      topBarRight={<span className="screen-meta">{items.length} items</span>}
    >
      <section className="inbox-screen" data-testid="inbox-screen">
        {items.length === 0 ? (
          <div className="board-empty-state">
            <h2>Inbox is clear</h2>
            <p>Approval requests and failed runs will collect here.</p>
          </div>
        ) : (
          items.map((item) => (
            <Link className="inbox-row" key={item.id} to={item.href}>
              <div className="inbox-row__main">
                <h2>{item.title}</h2>
                <p>{item.subtitle}</p>
              </div>
              <div className="inbox-row__meta">
                <span className="screen-meta">{formatRelativeTime(item.updatedAt)}</span>
                <StatusBadge
                  label={item.tone === "awaiting" ? "Awaiting" : "Failed"}
                  tone={item.tone === "awaiting" ? "awaiting" : "failed"}
                />
              </div>
            </Link>
          ))
        )}
      </section>
    </DesktopShellFrame>
  );
}
