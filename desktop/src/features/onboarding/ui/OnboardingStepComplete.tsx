import { ArrowRight, Check, Cpu, Folder } from "lucide-react";

export interface OnboardingStepCompleteProps {
  workspaceName: string;
  runtimeLabel?: string;
  taskDescription: string;
  onTaskDescriptionChange: (value: string) => void;
  onSkip: () => void;
  onStartTask: () => void;
  submitting: boolean;
  canStart: boolean;
  error?: string;
}

export function OnboardingStepComplete({
  workspaceName,
  runtimeLabel,
  taskDescription,
  onTaskDescriptionChange,
  onSkip,
  onStartTask,
  submitting,
  canStart,
  error,
}: OnboardingStepCompleteProps) {
  return (
    <form
      className="onboarding-step"
      data-testid="onboarding-step-complete"
      onSubmit={(event) => {
        event.preventDefault();
        if (canStart && !submitting) {
          onStartTask();
        }
      }}
    >
      <header className="onboarding-step__header">
        <span aria-hidden="true" className="onboarding-step__ring">
          <Check size={22} />
        </span>
        <h1 className="onboarding-step__title">You're all set</h1>
        <p className="onboarding-step__subtitle">Let's run your first task to see it in action.</p>
      </header>

      <div className="onboarding-summary-chip">
        <span className="onboarding-summary-chip__item">
          <Folder size={12} />
          {workspaceName || "Workspace"}
        </span>
        <span aria-hidden="true" className="onboarding-summary-chip__sep">
          ·
        </span>
        <span className="onboarding-summary-chip__item">
          <Cpu size={12} />
          {runtimeLabel || "Default runtime"}
        </span>
      </div>

      <div className="onboarding-complete-form">
        <div className="onboarding-field">
          <label
            className="onboarding-field__label onboarding-field__label--sentence"
            htmlFor="onboarding-task-description"
          >
            Describe your first task
          </label>
          <textarea
            className="onboarding-textarea onboarding-textarea--complete"
            data-testid="onboarding-task-description"
            id="onboarding-task-description"
            onChange={(event) => onTaskDescriptionChange(event.target.value)}
            placeholder="e.g. Refactor the auth middleware to use JWT validation with configurable TTL..."
            rows={5}
            value={taskDescription}
          />
        </div>

        {error ? (
          <p className="onboarding-error" role="alert">
            {error}
          </p>
        ) : null}

        <div className="onboarding-actions">
          <button
            className="onboarding-btn onboarding-btn--skip"
            data-testid="onboarding-complete-skip"
            onClick={onSkip}
            type="button"
          >
            Skip for now
          </button>
          <button
            className="onboarding-btn onboarding-btn--primary"
            data-testid="onboarding-complete-start"
            disabled={!canStart || submitting}
            type="submit"
          >
            {submitting ? "Starting…" : "Start task"}
            <ArrowRight size={14} />
          </button>
        </div>
      </div>
    </form>
  );
}
