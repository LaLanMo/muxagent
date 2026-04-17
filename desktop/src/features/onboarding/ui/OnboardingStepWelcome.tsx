import { ArrowRight } from "lucide-react";
import appIcon from "@/assets/app-icon.png";

export interface OnboardingStepWelcomeProps {
  workspacePath: string;
  workspaceName: string;
  onWorkspacePathChange: (value: string) => void;
  onWorkspaceNameChange: (value: string) => void;
  onPickDirectory: () => void;
  onSkip: () => void;
  onSubmit: () => void;
  submitting: boolean;
  error?: string;
}

export function OnboardingStepWelcome({
  workspacePath,
  workspaceName,
  onWorkspacePathChange,
  onWorkspaceNameChange,
  onPickDirectory,
  onSkip,
  onSubmit,
  submitting,
  error,
}: OnboardingStepWelcomeProps) {
  const canSubmit = Boolean(workspacePath.trim()) && !submitting;
  return (
    <form
      className="onboarding-step"
      data-testid="onboarding-step-welcome"
      onSubmit={(event) => {
        event.preventDefault();
        if (canSubmit) {
          onSubmit();
        }
      }}
    >
      <header className="onboarding-step__header">
        <div className="onboarding-step__brand">
          <img alt="" className="onboarding-step__brand-icon" src={appIcon} />
          <span className="onboarding-step__brand-name">MuxAgent</span>
        </div>
        <h1 className="onboarding-step__title">Welcome. Add your first workspace.</h1>
        <p className="onboarding-step__subtitle">
          Pick a local repository directory. MuxAgent orchestrates its tasks here.
        </p>
      </header>

      <div className="onboarding-form">
        <div className="onboarding-field">
          <label className="onboarding-field__label" htmlFor="onboarding-workspace-path">
            Repository path
          </label>
          <div className="onboarding-field__row">
            <input
              autoComplete="off"
              className="onboarding-input"
              data-testid="onboarding-workspace-path"
              id="onboarding-workspace-path"
              onChange={(event) => onWorkspacePathChange(event.target.value)}
              placeholder="~/Projects/my-app"
              spellCheck={false}
              type="text"
              value={workspacePath}
            />
            <button
              className="onboarding-browse"
              data-testid="onboarding-browse"
              onClick={onPickDirectory}
              type="button"
            >
              Browse
            </button>
          </div>
        </div>

        <div className="onboarding-field">
          <label className="onboarding-field__label" htmlFor="onboarding-workspace-name">
            Workspace name
          </label>
          <input
            autoComplete="off"
            className="onboarding-input"
            data-testid="onboarding-workspace-name"
            id="onboarding-workspace-name"
            onChange={(event) => onWorkspaceNameChange(event.target.value)}
            placeholder="muxagent-cli"
            spellCheck={false}
            type="text"
            value={workspaceName}
          />
          <p className="onboarding-field__hint">Auto-filled from the folder name. Edit any time.</p>
        </div>
      </div>

      {error ? (
        <p className="onboarding-error" role="alert">
          {error}
        </p>
      ) : null}

      <div className="onboarding-actions">
        <button
          className="onboarding-btn onboarding-btn--skip"
          data-testid="onboarding-skip"
          onClick={onSkip}
          type="button"
        >
          Skip for now
        </button>
        <button
          className="onboarding-btn onboarding-btn--primary"
          data-testid="onboarding-submit-workspace"
          disabled={!canSubmit}
          type="submit"
        >
          {submitting ? "Adding…" : "Add workspace"}
          <ArrowRight size={14} />
        </button>
      </div>
    </form>
  );
}
