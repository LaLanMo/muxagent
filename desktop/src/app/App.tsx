import { useEffect, type ReactNode } from "react";
import {
  BrowserRouter,
  Navigate,
  Outlet,
  Route,
  Routes,
  useLocation,
  useNavigate,
} from "react-router-dom";
import { buildTaskBoardHref, workbenchZeroTabPath } from "@/domain/routes";
import { useServerBootstrap } from "@/features/app/model/use-server-bootstrap";
import { useRuntimeSync } from "@/features/app/model/use-runtime-sync";
import {
  useTaskBoardRouteSelection,
  useTaskRouteSelection,
} from "@/features/app/model/use-task-route-selection";
import { useTaskSurfaceReturnContext } from "@/features/app/model/use-task-surface-return-context";
import { useConfigEditorScreen } from "@/features/configs/model/use-config-editor-screen";
import { useConfigsScreen } from "@/features/configs/model/use-configs-screen";
import { ConfigEditorScreen } from "@/features/configs/ui/ConfigEditorScreen";
import { ConfigsScreen } from "@/features/configs/ui/ConfigsScreen";
import { useEntryScreen } from "@/features/entry/model/use-entry-screen";
import { EntryShellScreen } from "@/features/entry/ui/EntryShellScreen";
import { WorkbenchShell } from "@/features/layout/ui/WorkbenchShell";
import { useNewTaskModal } from "@/features/new-task/model/use-new-task-modal";
import {
  buildNewTaskModalSearch,
  isNewTaskModalOpen,
} from "@/features/new-task/model/new-task-route-state";
import {
  isOnboardingCompleted,
  markOnboardingCompleted,
} from "@/features/onboarding/model/onboarding-memory";
import { OnboardingScreen } from "@/features/onboarding/ui/OnboardingScreen";
import { NewTaskModal } from "@/features/new-task/ui/NewTaskModal";
import { useSettingsScreen } from "@/features/settings/model/use-settings-screen";
import { SettingsScreen } from "@/features/settings/ui/SettingsScreen";
import { CommitDiffView } from "@/features/source-control/ui/CommitDiffView";
import { FileDiffView } from "@/features/source-control/ui/FileDiffView";
import { SourceControlLanding } from "@/features/source-control/ui/SourceControlLanding";
import { useTaskDetailScreen } from "@/features/task-detail/model/use-task-detail-screen";
import { TaskDetailScreen } from "@/features/task-detail/ui/TaskDetailScreen";
import { useWorkspaceStore } from "@/state/workspace-store";

function RuntimeEffects() {
  useServerBootstrap();
  useRuntimeSync();
  useTaskSurfaceReturnContext();
  return null;
}

function RequireConnectedRoute({ children }: { children: ReactNode }) {
  const phase = useWorkspaceStore((state) => state.phase);
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  if (phase !== "connected" || !selectedWorkspaceId) {
    return <Navigate replace to="/" />;
  }
  return <>{children}</>;
}

function OnboardingGate({ children }: { children: ReactNode }) {
  const phase = useWorkspaceStore((state) => state.phase);
  const bootstrapPending = useWorkspaceStore((state) => state.bootstrapPending);
  const workspaces = useWorkspaceStore((state) => state.workspaces);
  const location = useLocation();

  const onOnboardingRoute = location.pathname.startsWith("/onboarding");
  const isConnected = phase === "connected" && !bootstrapPending;
  const completed = isOnboardingCompleted();
  const hasWorkspaces = workspaces.length > 0;
  const shouldAutoComplete =
    isConnected && !completed && hasWorkspaces && !onOnboardingRoute;

  useEffect(() => {
    if (shouldAutoComplete) {
      markOnboardingCompleted();
    }
  }, [shouldAutoComplete]);

  if (!isConnected) {
    return <>{children}</>;
  }
  if (onOnboardingRoute) {
    return <>{children}</>;
  }
  if (completed || hasWorkspaces) {
    return <>{children}</>;
  }
  return <Navigate replace to="/onboarding" />;
}

function RequireConnectedPhaseRoute({ children }: { children: ReactNode }) {
  const phase = useWorkspaceStore((state) => state.phase);
  if (phase !== "connected") {
    return <Navigate replace to="/" />;
  }
  return <>{children}</>;
}

function WorkbenchLayout() {
  return (
    <WorkbenchShell>
      <Outlet />
    </WorkbenchShell>
  );
}

function EntryRoute() {
  const model = useEntryScreen();
  return (
    <EntryShellScreen
      boardTabId={model.boardTabId}
      boardTitle={model.boardTitle}
      columns={model.columns}
      hasTasks={model.hasTasks}
      launchableEntries={model.launchableEntries}
      shell={model.shell}
    />
  );
}

function GlobalNewTaskModal() {
  const location = useLocation();
  const navigate = useNavigate();
  const catalog = useWorkspaceStore((state) => state.catalog);
  const modalOpen = isNewTaskModalOpen(location.search);
  const launchableEntries = (catalog?.entries ?? []).filter(
    (entry) => entry.launchable,
  );

  function setModalOpen(nextOpen: boolean) {
    navigate(
      {
        pathname: location.pathname,
        search: buildNewTaskModalSearch(location.search, nextOpen),
      },
      { replace: true },
    );
  }

  const modal = useNewTaskModal({
    open: modalOpen,
    onClose: () => setModalOpen(false),
  });

  return (
    <NewTaskModal
      configDescription={modal.selectedEntry?.description}
      selectedRuntimeName={modal.selectedEntry?.runtime_name}
      configMaxIterations={modal.configMaxIterations}
      configEntryNode={modal.configEntryNode}
      configPicking={modal.configPicking}
      onToggleConfigPicker={modal.toggleConfigPicker}
      onCloseConfigPicker={modal.closeConfigPicker}
      description={modal.description}
      imageAttachments={modal.imageAttachments}
      entries={launchableEntries}
      error={modal.error}
      flowNodes={modal.flowNodes}
      workspacePicking={modal.workspacePicking}
      onToggleWorkspacePicker={modal.toggleWorkspacePicker}
      onCloseWorkspacePicker={modal.closeWorkspacePicker}
      onTargetWorkspaceChange={modal.setSelectedTargetWorkspaceId}
      onAliasChange={modal.setSelectedAlias}
      onClose={() => setModalOpen(false)}
      onDescriptionChange={modal.setDescription}
      onImageAttachmentsChange={modal.setImageAttachments}
      onSubmit={() => void modal.submit()}
      onToggleWorktree={modal.setUseWorktree}
      open={modalOpen}
      selectedTargetWorkspaceId={modal.selectedTargetWorkspaceId}
      selectedAlias={modal.selectedAlias}
      submitting={modal.submitting}
      canSubmit={modal.canSubmit}
      useWorktree={modal.useWorktree}
      workspaceOptions={modal.workspaceOptions}
      worktreeAvailable={modal.worktreeAvailable}
    />
  );
}

function TaskDetailRoute() {
  const model = useTaskDetailScreen();
  return <TaskDetailScreen {...model} />;
}

function ProtectedTaskDetailRoute() {
  const routeState = useTaskRouteSelection();
  if (routeState === "pending") {
    return (
      <main
        aria-busy="true"
        aria-live="polite"
        className="route-pending"
        data-testid="task-route-pending"
      >
        <p className="muted-copy">Loading task…</p>
      </main>
    );
  }
  if (routeState === "redirect") {
    return <Navigate replace to="/" />;
  }
  return (
    <RequireConnectedRoute>
      <TaskDetailRoute />
    </RequireConnectedRoute>
  );
}

function ProtectedTaskBoardRoute() {
  const location = useLocation();
  const routeState = useTaskBoardRouteSelection();
  if (routeState === "pending") {
    return (
      <main
        aria-busy="true"
        aria-live="polite"
        className="route-pending"
        data-testid="task-route-pending"
      >
        <p className="muted-copy">Loading board…</p>
      </main>
    );
  }
  if (routeState === "redirect") {
    return (
      <Navigate
        replace
        to={buildTaskBoardHref({ kind: "all" }, location.search)}
      />
    );
  }
  return <EntryRoute />;
}

function ConfigsRoute() {
  const model = useConfigsScreen();
  return (
    <ConfigsScreen
      actionError={model.actionError}
      busyAlias={model.busyAlias}
      cancelRemove={model.cancelRemove}
      confirmRemove={model.confirmRemove}
      count={model.count}
      createConfig={model.createConfig}
      entries={model.entries}
      pendingRemoveEntry={model.pendingRemoveEntry}
    />
  );
}

function ConfigEditorRoute() {
  const model = useConfigEditorScreen();
  return <ConfigEditorScreen {...model} />;
}

function SettingsRoute() {
  const location = useLocation();
  const model = useSettingsScreen();
  const section = location.pathname.startsWith("/settings/about")
    ? "about"
    : "runtimes";
  return (
    <SettingsScreen
      aboutRows={model.aboutRows}
      runtimeRows={model.runtimeRows}
      section={section}
    />
  );
}

function SourceControlRedirect() {
  return <Navigate replace to="/source-control-landing" />;
}

function WorkbenchZeroTabRoute() {
  return null;
}

export function App() {
  return (
    <BrowserRouter>
      <RuntimeEffects />
      <OnboardingGate>
        <Routes>
          <Route element={<OnboardingScreen />} path="/onboarding" />
          <Route element={<WorkbenchLayout />}>
            <Route element={<EntryRoute />} path="/" />
            <Route element={<WorkbenchZeroTabRoute />} path={workbenchZeroTabPath} />
            <Route
              element={<ProtectedTaskDetailRoute />}
              path="/workspaces/:workspaceId/tasks/:taskId"
            />
            <Route
              element={<ProtectedTaskBoardRoute />}
              path="/workspaces/:workspaceId/tasks"
            />
            <Route
              element={<Navigate replace to="/" />}
              path="/workspaces/:workspaceId/checkouts/:checkoutPath"
            />
            <Route
              element={
                <RequireConnectedPhaseRoute>
                  <FileDiffView />
                </RequireConnectedPhaseRoute>
              }
              path="/workspaces/:workspaceId/checkouts/:checkoutPath/files/:fileId"
            />
            <Route
              element={
                <RequireConnectedPhaseRoute>
                  <CommitDiffView />
                </RequireConnectedPhaseRoute>
              }
              path="/workspaces/:workspaceId/checkouts/:checkoutPath/commits/:commitHash"
            />
            <Route element={<SourceControlRedirect />} path="/source-control" />
            <Route
              element={
                <RequireConnectedPhaseRoute>
                  <SourceControlLanding />
                </RequireConnectedPhaseRoute>
              }
              path="/source-control-landing"
            />
            <Route element={<ConfigsRoute />} path="/configs" />
            <Route element={<ConfigEditorRoute />} path="/configs/:alias" />
            <Route element={<Navigate replace to="/settings/runtimes" />} path="/settings" />
            <Route element={<SettingsRoute />} path="/settings/runtimes" />
            <Route element={<SettingsRoute />} path="/settings/about" />
            <Route element={<Navigate replace to="/" />} path="*" />
          </Route>
        </Routes>
        <GlobalNewTaskModal />
      </OnboardingGate>
    </BrowserRouter>
  );
}
