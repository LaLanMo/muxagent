import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { useShellModel } from "@/features/app/model/use-shell-model";
import type { RuntimeStatusResult, ServiceStatusResult } from "@/rpc/types";
import { useWorkspaceStore } from "@/state/workspace-store";

export type SettingsStatusTone = "default" | "available" | "warning";

export type SettingsRuntimeRowModel = {
  id: string;
  name: string;
  detail?: string;
  detailMonospace?: boolean;
  statusLabel: string;
  statusTone: SettingsStatusTone;
};

export type SettingsAboutRowModel =
  {
    id: "version";
    label: string;
    value: string;
    monospace?: boolean;
  };

function offlineRuntimeRow(
  phase: ShellChromeModel["phase"],
  error?: string,
): SettingsRuntimeRowModel {
  switch (phase) {
    case "connecting":
      return {
        id: "runtime-status-connecting",
        name: "Runtime status",
        detail: "Desktop is opening a fresh app-server session.",
        statusLabel: "Connecting",
        statusTone: "warning",
      };
    case "failed":
      return {
        id: "runtime-status-failed",
        name: "Runtime status",
        detail: error ?? "Desktop could not bootstrap the app-server session.",
        statusLabel: "Failed",
        statusTone: "warning",
      };
    case "idle":
    default:
      return {
        id: "runtime-status-offline",
        name: "Runtime status",
        detail: "Connect to the app-server to inspect launcher availability.",
        statusLabel: "Offline",
        statusTone: "default",
      };
  }
}

function runtimeRows(
  phase: ShellChromeModel["phase"],
  runtimeStatus: RuntimeStatusResult | undefined,
  error?: string,
): SettingsRuntimeRowModel[] {
  if (!runtimeStatus) {
    return [offlineRuntimeRow(phase, error)];
  }

  const automatic = runtimeStatus.automatic;
  const rows = runtimeStatus.runtimes.map((runtime) => {
    const launcher = runtime.launcher?.trim();
    const automaticRow = runtime.runtime_id === automatic.runtime_id;

    return {
      id: runtime.runtime_id,
      name: runtime.runtime_name,
      detail: launcher ?? "Not configured",
      detailMonospace: Boolean(launcher),
      statusLabel: automaticRow
        ? automatic.detected
          ? "Detected"
          : "Fallback"
        : runtime.available
          ? "Available"
          : "Not found",
      statusTone: automaticRow
        ? automatic.detected
          ? "available"
          : "warning"
        : runtime.available
          ? "available"
          : "default",
    } satisfies SettingsRuntimeRowModel;
  });

  if (rows.some((row) => row.id === automatic.runtime_id)) {
    return rows;
  }

  const launcher = automatic.launcher?.trim();
  return [
    {
      id: automatic.runtime_id,
      name: automatic.runtime_name,
      detail: launcher ?? "Detected on this machine",
      detailMonospace: Boolean(launcher),
      statusLabel: automatic.detected ? "Detected" : "Fallback",
      statusTone: automatic.detected ? "available" : "warning",
    },
    ...rows,
  ];
}

function aboutRows(status?: ServiceStatusResult): SettingsAboutRowModel[] {
  return [
    {
      id: "version",
      label: "Version",
      value: status?.server_version ?? "Unavailable",
      monospace: true,
    },
  ];
}

export function useSettingsScreen() {
  const shell = useShellModel();
  const status = useWorkspaceStore((state) => state.status);
  const runtimeStatus = useWorkspaceStore((state) => state.runtimeStatus);

  return {
    shell,
    runtimeRows: runtimeRows(shell.phase, runtimeStatus, shell.error),
    aboutRows: aboutRows(status),
  };
}
