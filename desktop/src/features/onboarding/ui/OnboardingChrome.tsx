import type { ReactNode } from "react";

export function OnboardingChrome({ children }: { children: ReactNode }) {
  return (
    <div className="onboarding-window" data-testid="onboarding-window">
      <div className="onboarding-window__body">{children}</div>
    </div>
  );
}
