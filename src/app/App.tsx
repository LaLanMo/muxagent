import { type ReactNode } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { useServerBootstrap } from "@/features/app/model/use-server-bootstrap";
import { useRuntimeSync } from "@/features/app/model/use-runtime-sync";
import { useEntryScreen } from "@/features/entry/model/use-entry-screen";
import { EntryShellScreen } from "@/features/entry/ui/EntryShellScreen";
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
      modal={model.modal}
      modalOpen={model.modalOpen}
      onCloseModal={model.closeModal}
      onOpenModal={model.openModal}
      shell={model.shell}
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
  return (
    <SettingsScreen
      beginRename={model.beginRename}
      cancelRename={model.cancelRename}
      commitRename={model.commitRename}
      removeWorkspace={model.removeWorkspace}
      renameDraft={model.renameDraft}
      server={model.server}
      shell={model.shell}
      status={model.status}
      setRenameDraft={model.setRenameDraft}
      workspaceActionError={model.workspaceActionError}
      workspaceRows={model.workspaceRows}
      workDir={model.workDir}
    />
  );
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
    </BrowserRouter>
  );
}
