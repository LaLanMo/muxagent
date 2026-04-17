import {
  type SettingsAboutRowModel,
  type SettingsRuntimeRowModel,
  type SettingsStatusTone,
} from "@/features/settings/model/use-settings-screen";

type SettingsScreenProps = {
  runtimeRows: SettingsRuntimeRowModel[];
  aboutRows: SettingsAboutRowModel[];
};

function statusToneClass(tone: SettingsStatusTone | undefined): string {
  switch (tone) {
    case "available":
      return " settings-status--available";
    case "warning":
      return " settings-status--warning";
    default:
      return "";
  }
}

function RuntimeRow({
  row,
  testId,
}: {
  row: SettingsRuntimeRowModel;
  testId?: string;
}) {
  return (
    <div className="settings-row" data-testid={testId}>
      <div className="settings-row__copy">
        <strong className="settings-row__title">{row.name}</strong>
        {row.detail ? (
          <p
            className={
              row.detailMonospace
                ? "settings-row__detail settings-row__detail--monospace"
                : "settings-row__detail"
            }
          >
            {row.detail}
          </p>
        ) : null}
      </div>
      <span className={`settings-status${statusToneClass(row.statusTone)}`}>
        {row.statusLabel}
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
  runtimeRows,
  aboutRows,
}: SettingsScreenProps) {
  return (
    <section className="stack-screen settings-screen" data-testid="settings-screen">
      <article className="settings-panel">
        <div className="settings-section" data-testid="settings-runtime-section">
          <div className="settings-section__header">
            <span className="settings-section__eyebrow">Runtimes</span>
          </div>
          <div className="settings-section__rows">
            {runtimeRows.map((row) => (
              <RuntimeRow key={row.id} row={row} testId="settings-runtime-row" />
            ))}
          </div>
        </div>

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
      </article>
    </section>
  );
}
