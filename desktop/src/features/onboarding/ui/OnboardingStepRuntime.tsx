import { ArrowLeft, ArrowRight, Cpu } from "lucide-react";
import type { OnboardingRuntimeOption } from "@/features/onboarding/model/use-onboarding";

export interface OnboardingStepRuntimeProps {
  options: OnboardingRuntimeOption[];
  selectedRuntimeId?: string;
  onSelect: (runtimeId: string) => void;
  onBack: () => void;
  onContinue: () => void;
  submitting: boolean;
  error?: string;
}

export function OnboardingStepRuntime({
  options,
  selectedRuntimeId,
  onSelect,
  onBack,
  onContinue,
  submitting,
  error,
}: OnboardingStepRuntimeProps) {
  const canContinue = Boolean(selectedRuntimeId) && !submitting;

  return (
    <div className="onboarding-step" data-testid="onboarding-step-runtime">
      <header className="onboarding-step__header">
        <span aria-hidden="true" className="onboarding-step__ring">
          <Cpu size={22} />
        </span>
        <h1 className="onboarding-step__title">Pick your default agent runtime</h1>
        <p className="onboarding-step__subtitle">
          These are the agents MuxAgent detected on this machine. Choose one as the default — you can change it anytime in Configs.
        </p>
      </header>

      {options.length === 0 ? (
        <div className="onboarding-form onboarding-form--empty">
          No runtimes detected. Install claude-code, codex, or opencode to continue.
        </div>
      ) : (
        <div className="onboarding-runtime-list" role="radiogroup">
          {options.map((option) => {
            const checked = option.runtimeId === selectedRuntimeId;
            const classes = [
              "onboarding-runtime-row",
              checked ? "onboarding-runtime-row--selected" : "",
              option.available ? "" : "onboarding-runtime-row--unavailable",
            ]
              .filter(Boolean)
              .join(" ");
            return (
              <button
                aria-checked={checked}
                aria-disabled={!option.available}
                className={classes}
                data-testid={`onboarding-runtime-${option.runtimeId}`}
                key={option.runtimeId}
                onClick={() => onSelect(option.runtimeId)}
                role="radio"
                type="button"
              >
                <span
                  aria-hidden="true"
                  className={`onboarding-radio${checked ? " onboarding-radio--checked" : ""}`}
                />
                <span className="onboarding-runtime-row__body">
                  <span className="onboarding-runtime-row__head">
                    <span className="onboarding-runtime-row__label">{option.label}</span>
                    <span
                      className={`onboarding-runtime-row__badge ${
                        option.available
                          ? "onboarding-runtime-row__badge--ready"
                          : "onboarding-runtime-row__badge--missing"
                      }`}
                    >
                      {option.available ? "Available" : "Not installed"}
                    </span>
                  </span>
                  <span className="onboarding-runtime-row__hint">
                    {option.launcher ?? (option.available ? "" : "Executable not found")}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      )}

      {error ? (
        <p className="onboarding-error" role="alert">
          {error}
        </p>
      ) : null}

      <div className="onboarding-actions">
        <button
          className="onboarding-btn onboarding-btn--secondary"
          data-testid="onboarding-runtime-back"
          onClick={onBack}
          type="button"
        >
          <ArrowLeft size={14} />
          Back
        </button>
        <button
          className="onboarding-btn onboarding-btn--primary"
          data-testid="onboarding-runtime-continue"
          disabled={!canContinue}
          onClick={onContinue}
          type="button"
        >
          {submitting ? "Applying…" : "Continue"}
          <ArrowRight size={14} />
        </button>
      </div>
    </div>
  );
}
