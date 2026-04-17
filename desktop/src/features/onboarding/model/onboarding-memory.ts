const onboardingCompletedAtKey = "muxagent-desktop:onboarding-completed-at";

export function isOnboardingCompleted(): boolean {
  return Boolean(localStorage.getItem(onboardingCompletedAtKey)?.trim());
}

export function markOnboardingCompleted(): void {
  localStorage.setItem(onboardingCompletedAtKey, new Date().toISOString());
}

export function clearOnboardingCompleted(): void {
  localStorage.removeItem(onboardingCompletedAtKey);
}
