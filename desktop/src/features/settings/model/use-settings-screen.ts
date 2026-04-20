import type { RuntimeStatusResult, ServiceStatusResult } from "@/rpc/types";
import { useWorkspaceStore } from "@/state/workspace-store";

export type SettingsAboutRowModel =
  {
    id: "desktop-version" | "service-version";
    label: string;
    value: string;
    monospace?: boolean;
  };

export type SettingsRuntimeRowModel = {
  id: string;
  label: string;
  launcher?: string;
  stateLabel: string;
  stateTone: "ready" | "muted";
};

export type SettingsSectionId = "runtimes" | "about";

function aboutRows(status?: ServiceStatusResult): SettingsAboutRowModel[] {
  return [
    {
      id: "desktop-version",
      label: "Desktop Version",
      value: __MUXAGENT_DESKTOP_VERSION__,
      monospace: true,
    },
    {
      id: "service-version",
      label: "Service Version",
      value: status?.server_version ?? "Unavailable",
      monospace: true,
    },
  ];
}

function runtimeRows(runtimeStatus?: RuntimeStatusResult): SettingsRuntimeRowModel[] {
  if (!runtimeStatus?.runtimes?.length) {
    return [];
  }

  return runtimeStatus.runtimes.map((entry) => ({
    id: entry.runtime_id,
    label: entry.runtime_name || entry.runtime_id,
    launcher: entry.launcher,
    stateLabel: entry.available ? "Available" : "Unavailable",
    stateTone: entry.available ? "ready" : "muted",
  }));
}

export function useSettingsScreen() {
  const status = useWorkspaceStore((state) => state.status);
  const runtimeStatus = useWorkspaceStore((state) => state.runtimeStatus);

  return {
    runtimeRows: runtimeRows(runtimeStatus),
    aboutRows: aboutRows(status),
  };
}
