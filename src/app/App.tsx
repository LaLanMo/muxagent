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
import { useSettingsScreen } from "@/features/settings/model/use-settings-screen";
import { SettingsScreen } from "@/features/settings/ui/SettingsScreen";
import { useInboxScreen } from "@/features/inbox/model/use-inbox-screen";
import { InboxScreen } from "@/features/inbox/ui/InboxScreen";
import { useTaskRouteSelection } from "@/features/app/model/use-task-route-selection";
import { useWorkspaceStore } from "@/state/workspace-store";

function RuntimeEffects() {
  useServerBootstrap();
  useRuntimeSync();
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
    return null;
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
  return <ConfigsScreen entries={model.entries} shell={model.shell} />;
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

function InboxRoute() {
  const model = useInboxScreen();
  return <InboxScreen items={model.items} shell={model.shell} />;
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
        <Route element={<InboxRoute />} path="/inbox" />
        <Route element={<ConfigsRoute />} path="/configs" />
        <Route element={<SettingsRoute />} path="/settings" />
        <Route element={<Navigate replace to="/" />} path="*" />
      </Routes>
    </BrowserRouter>
  );
}
