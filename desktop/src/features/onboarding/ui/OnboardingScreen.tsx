import { useOnboarding } from "@/features/onboarding/model/use-onboarding";
import { OnboardingChrome } from "@/features/onboarding/ui/OnboardingChrome";
import { OnboardingStepComplete } from "@/features/onboarding/ui/OnboardingStepComplete";
import { OnboardingStepIndicator } from "@/features/onboarding/ui/OnboardingStepIndicator";
import { OnboardingStepRuntime } from "@/features/onboarding/ui/OnboardingStepRuntime";
import { OnboardingStepWelcome } from "@/features/onboarding/ui/OnboardingStepWelcome";

const TOTAL_STEPS = 3;

export function OnboardingScreen() {
  const onboarding = useOnboarding();

  const selectedRuntimeLabel = onboarding.runtimeOptions.find(
    (option) => option.runtimeId === onboarding.selectedRuntimeId,
  )?.label;

  return (
    <main className="onboarding-screen" data-testid="onboarding-screen">
      <OnboardingChrome>
        {onboarding.step === 1 ? (
          <OnboardingStepWelcome
            error={onboarding.error}
            onPickDirectory={() => void onboarding.pickWorkspaceDirectory()}
            onSkip={onboarding.skipOnboarding}
            onSubmit={() => void onboarding.submitWorkspace()}
            onWorkspaceNameChange={onboarding.setWorkspaceName}
            onWorkspacePathChange={onboarding.setWorkspacePath}
            submitting={onboarding.submitting}
            workspaceName={onboarding.workspaceName}
            workspacePath={onboarding.workspacePath}
          />
        ) : null}

        {onboarding.step === 2 ? (
          <OnboardingStepRuntime
            error={onboarding.error}
            onBack={onboarding.back}
            onContinue={() => void onboarding.applyRuntime()}
            onSelect={onboarding.setSelectedRuntimeId}
            options={onboarding.runtimeOptions}
            selectedRuntimeId={onboarding.selectedRuntimeId}
            submitting={onboarding.submitting}
          />
        ) : null}

        {onboarding.step === 3 ? (
          <OnboardingStepComplete
            canStart={Boolean(
              onboarding.taskDescription.trim() && onboarding.defaultLaunchableEntry,
            )}
            error={onboarding.error}
            onSkip={onboarding.finishWithoutTask}
            onStartTask={() => void onboarding.startFirstTask()}
            onTaskDescriptionChange={onboarding.setTaskDescription}
            runtimeLabel={selectedRuntimeLabel}
            submitting={onboarding.submitting}
            taskDescription={onboarding.taskDescription}
            workspaceName={
              onboarding.workspaceAdded?.display_name || onboarding.workspaceName
            }
          />
        ) : null}

        <OnboardingStepIndicator step={onboarding.step} total={TOTAL_STEPS} />
      </OnboardingChrome>
    </main>
  );
}
