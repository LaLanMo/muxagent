import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { DesktopShellFrame } from "@/features/layout/ui/DesktopShellFrame";
import { StatusBadge } from "@/features/shared/ui/StatusBadge";
import type { ConfigCatalogEntryDto } from "@/rpc/types";

type ConfigsScreenProps = {
  shell: ShellChromeModel;
  entries: ConfigCatalogEntryDto[];
};

export function ConfigsScreen({ shell, entries }: ConfigsScreenProps) {
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
      topBarLeft={<h1 className="screen-title">Configs</h1>}
      topBarRight={<span className="screen-meta">{entries.length} configs</span>}
    >
      <section className="stack-screen" data-testid="configs-screen">
        {entries.length === 0 ? (
          <div className="board-empty-state">
            <h2>No configs loaded</h2>
            <p>The current app-server session did not return any launchable task configs.</p>
          </div>
        ) : (
          entries.map((entry) => (
            <article className="config-card" key={entry.alias}>
              <div className="config-card__header">
                <div className="config-card__title-group">
                  <h2>{entry.alias}</h2>
                  <p>{entry.description || entry.config_path}</p>
                </div>
                <div className="config-card__badges">
                  {entry.is_default ? <StatusBadge label="default" tone="done" mono /> : null}
                  <StatusBadge
                    label={entry.launchable ? "launchable" : "disabled"}
                    mono
                    tone={entry.launchable ? "neutral" : "failed"}
                  />
                </div>
              </div>
              <div className="config-card__body">
                <p className="config-card__path">{entry.config_path}</p>
                {entry.node_names?.length ? (
                  <div className="flow-node-inline">
                    {entry.node_names.map((node) => (
                      <span className="flow-node-inline__item" key={node}>
                        {node}
                      </span>
                    ))}
                  </div>
                ) : null}
              </div>
            </article>
          ))
        )}
      </section>
    </DesktopShellFrame>
  );
}
