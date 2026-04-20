import {
  type SettingsSectionId,
  type SettingsRuntimeRowModel,
  type SettingsAboutRowModel,
} from "@/features/settings/model/use-settings-screen";

type SettingsScreenProps = {
  section: SettingsSectionId;
  runtimeRows: SettingsRuntimeRowModel[];
  aboutRows: SettingsAboutRowModel[];
};

function RuntimeRow({ row }: { row: SettingsRuntimeRowModel }) {
  return (
    <div className="settings-row settings-row--runtime" data-testid={`settings-runtime-${row.id}`}>
      <div className="settings-row__copy">
        <strong className="settings-row__title">{row.label}</strong>
        {row.launcher ? <span className="settings-row__subcopy">{row.launcher}</span> : null}
      </div>
      <span className={`settings-row__status settings-row__status--${row.stateTone}`}>
        {row.stateLabel}
      </span>
    </div>
  );
}

function AboutRow({ row }: { row: SettingsAboutRowModel }) {
  return (
    <div className="settings-row" data-testid="settings-version-row">
      <div className="settings-row__copy">
        <strong className="settings-row__title">{row.label}</strong>
      </div>
      <span
        className={
          row.monospace
            ? "settings-row__value settings-row__value--monospace"
            : "settings-row__value"
        }
      >
        {row.value}
      </span>
    </div>
  );
}

export function SettingsScreen({
  section,
  runtimeRows,
  aboutRows,
}: SettingsScreenProps) {
  return (
    <section className="stack-screen settings-screen" data-testid="settings-screen">
      <article className="settings-panel">
        {section === "runtimes" ? (
          <div className="settings-section" data-testid="settings-runtimes-section">
            <div className="settings-section__header">
              <span className="settings-section__eyebrow">Runtimes</span>
            </div>
            <div className="settings-section__rows">
              {runtimeRows.length > 0 ? (
                runtimeRows.map((row) => <RuntimeRow key={row.id} row={row} />)
              ) : (
                <div className="settings-section__empty">No runtimes detected.</div>
              )}
            </div>
          </div>
        ) : null}

        {section === "about" ? (
          <div className="settings-section" data-testid="settings-about-section">
            <div className="settings-section__header">
              <span className="settings-section__eyebrow">About</span>
            </div>
            <div className="settings-section__rows">
              {aboutRows.map((row) => (
                <AboutRow key={row.id} row={row} />
              ))}
            </div>
          </div>
        ) : null}
      </article>
    </section>
  );
}
