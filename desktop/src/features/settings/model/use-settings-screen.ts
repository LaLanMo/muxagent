import type { ShellChromeModel } from "@/features/app/model/use-shell-chrome";
import { useShellModel } from "@/features/app/model/use-shell-model";
import type { RuntimeStatusResult } from "@/rpc/types";
import { useWorkspaceStore } from "@/state/workspace-store";

export type SettingsStatusTone = "default" | "available" | "warning";

export type SettingsRowModel = {
  id: string;
  label: string;
  value: string;
  detail?: string;
  statusLabel?: string;
  statusTone?: SettingsStatusTone;
  monospace?: boolean;
};

function connectionRow(
  phase: ShellChromeModel["phase"],
  error?: string,
): Pick<SettingsRowModel, "value" | "detail" | "statusLabel" | "statusTone"> {
  switch (phase) {
    case "connected":
      return {
        value: "Connected",
        detail: "Desktop is attached to the app-server and receiving live runtime status.",
        statusLabel: "Connected",
        statusTone: "available",
      };
    case "connecting":
      return {
        value: "Connecting",
        detail: "Desktop is opening a fresh app-server session.",
        statusLabel: "Connecting",
        statusTone: "warning",
      };
    case "failed":
      return {
        value: "Failed",
        detail: error ?? "Desktop could not bootstrap the app-server session.",
        statusLabel: "Failed",
        statusTone: "warning",
      };
    case "idle":
    default:
      return {
        value: "Disconnected",
        detail: "Connect to the app-server to inspect runtime availability.",
        statusLabel: "Disconnected",
        statusTone: "default",
      };
  }
}

function automaticRuntimeRow(runtimeStatus?: RuntimeStatusResult): SettingsRowModel {
  if (!runtimeStatus) {
    return {
      id: "automatic-runtime",
      label: "Automatic default",
      value: "Unavailable",
      detail: "Connect to the app-server to inspect automatic runtime detection.",
      statusLabel: "Unavailable",
      statusTone: "default",
    };
  }

  const automatic = runtimeStatus.automatic;
  const launcher = automatic.launcher?.trim();
  if (automatic.detected) {
    return {
      id: "automatic-runtime",
      label: "Automatic default",
      value: automatic.runtime_name,
      detail: launcher
        ? `Detected via ${launcher} on PATH.`
        : "Detected on this machine.",
      statusLabel: "Detected",
      statusTone: "available",
    };
  }

  return {
    id: "automatic-runtime",
    label: "Automatic default",
    value: automatic.runtime_name,
    detail: launcher
      ? `No preferred runtime binary was detected, so app-server falls back to ${automatic.runtime_name} via ${launcher}.`
      : `No preferred runtime binary was detected, so app-server falls back to ${automatic.runtime_name}.`,
    statusLabel: "Fallback",
    statusTone: "warning",
  };
}

function taskRuntimeRows(runtimeStatus?: RuntimeStatusResult): SettingsRowModel[] {
  return (runtimeStatus?.runtimes ?? []).map((runtime) => ({
    id: runtime.runtime_id,
    label: "Task runtime",
    value: runtime.runtime_name,
    detail: runtime.launcher
      ? `Launcher: ${runtime.launcher}`
      : "No launcher metadata reported.",
    statusLabel: runtime.available ? "Available" : "Unavailable",
    statusTone: runtime.available ? "available" : "default",
  }));
}

export function useSettingsScreen() {
  const shell = useShellModel();
  const server = useWorkspaceStore((state) => state.server);
  const status = useWorkspaceStore((state) => state.status);
  const runtimeStatus = useWorkspaceStore((state) => state.runtimeStatus);

  const appServerRows: SettingsRowModel[] = [
    {
      id: "server",
      label: "Server",
      value: server?.server_name ?? "muxagent app-server",
      detail: "Authoritative app-server metadata for this desktop session.",
    },
    {
      id: "state-dir",
      label: "State directory",
      value: status?.state_dir ?? "Unavailable",
      detail: "Workspace registry and app-server local state live here.",
      monospace: true,
    },
    {
      id: "connection",
      label: "Connection",
      ...connectionRow(shell.phase, shell.error),
    },
  ];

  return {
    shell,
    appServerRows,
    automaticRuntime: automaticRuntimeRow(runtimeStatus),
    runtimeRows: taskRuntimeRows(runtimeStatus),
  };
}
