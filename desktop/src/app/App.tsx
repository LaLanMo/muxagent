import { type ReactNode } from "react";
import { BrowserRouter, Navigate, Route, Routes, useLocation, useNavigate } from "react-router-dom";
import { useServerBootstrap } from "@/features/app/model/use-server-bootstrap";
import { useRuntimeSync } from "@/features/app/model/use-runtime-sync";
import { useEntryScreen } from "@/features/entry/model/use-entry-screen";
import { EntryShellScreen } from "@/features/entry/ui/EntryShellScreen";
import { useNewTaskModal } from "@/features/new-task/model/use-new-task-modal";
import {
  buildNewTaskModalSearch,
  isNewTaskModalOpen,
} from "@/features/new-task/model/new-task-route-state";
import { NewTaskModal } from "@/features/new-task/ui/NewTaskModal";
import { useTaskDetailScreen } from "@/features/task-detail/model/use-task-detail-screen";
import { TaskDetailScreen } from "@/features/task-detail/ui/TaskDetailScreen";
import { useConfigsScreen } from "@/features/configs/model/use-configs-screen";
import { ConfigsScreen } from "@/features/configs/ui/ConfigsScreen";
import { useConfigEditorScreen } from "@/features/configs/model/use-config-editor-screen";
import { ConfigEditorScreen } from "@/features/configs/ui/ConfigEditorScreen";
import { useSettingsScreen } from "@/features/settings/model/use-settings-screen";
import { SettingsScreen } from "@/features/settings/ui/SettingsScreen";
import { useTaskRouteSelection } from "@/features/app/model/use-task-route-selection";
import { useTaskSurfaceReturnContext } from "@/features/app/model/use-task-surface-return-context";
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

function EntryRoute() {
  const model = useEntryScreen();
  return (
    <EntryShellScreen
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
  const launchableEntries = (catalog?.entries ?? []).filter((entry) => entry.launchable);

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
      shell={model.shell}
    />
  );
}

function ConfigEditorRoute() {
  const model = useConfigEditorScreen();
  return <ConfigEditorScreen {...model} />;
}

function SettingsRoute() {
  const model = useSettingsScreen();
  return <SettingsScreen server={model.server} shell={model.shell} status={model.status} />;
}

export function App() {
  return (
    <BrowserRouter>
      <RuntimeEffects />
      <Routes>
        <Route element={<EntryRoute />} path="/" />
        <Route
          element={<ProtectedTaskDetailRoute />}
          path="/workspaces/:workspaceId/tasks/:taskId"
        />
        <Route element={<ConfigsRoute />} path="/configs" />
        <Route element={<ConfigEditorRoute />} path="/configs/:alias" />
        <Route element={<SettingsRoute />} path="/settings" />
        <Route element={<Navigate replace to="/" />} path="*" />
      </Routes>
      <GlobalNewTaskModal />
    </BrowserRouter>
  );
}
