export function OnboardingStepIndicator({
  step,
  total,
}: {
  step: number;
  total: number;
}) {
  return (
    <div className="onboarding-step-indicator" data-testid="onboarding-step-indicator">
      <div className="onboarding-step-indicator__dots">
        {Array.from({ length: total }).map((_, index) => (
          <span
            aria-hidden="true"
            className={`onboarding-step-indicator__dot${
              index === step - 1 ? " onboarding-step-indicator__dot--active" : ""
            }`}
            key={index}
          />
        ))}
      </div>
      <div className="onboarding-step-indicator__label">
        Step {step} of {total}
      </div>
    </div>
  );
}
