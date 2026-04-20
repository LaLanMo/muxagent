import {
  createContext,
  useContext,
  useLayoutEffect,
  type ReactNode,
} from "react";
import type { WorkbenchTabId } from "@/domain/routes";

export type WorkbenchRegionPanelTab = {
  key: string;
  label: string;
  active?: boolean;
};

export type WorkbenchRegionPanel = {
  title?: string;
  content: ReactNode;
  size?: number;
  testId?: string;
  tabs?: WorkbenchRegionPanelTab[];
};

export type WorkbenchSecondarySidebarConfig = {
  panel: WorkbenchRegionPanel;
  defaultOpen?: boolean;
  preferredSize?: number;
};

export type WorkbenchTabConfig = {
  key: string;
  tabId?: WorkbenchTabId;
  title?: string;
};

export type WorkbenchRegionsConfig = {
  key: string;
  tabId: WorkbenchTabId;
  secondarySidebar?: WorkbenchSecondarySidebarConfig | null;
  panel?: WorkbenchRegionPanel | null;
};

type WorkbenchTabController = {
  setTab: (tab: WorkbenchTabConfig) => void;
  clearTab: (key: string) => void;
};

type WorkbenchRegionsController = {
  setRegions: (regions: WorkbenchRegionsConfig) => void;
  clearRegions: (key: string) => void;
};

export const WorkbenchTabContext =
  createContext<WorkbenchTabController | null>(null);

export const WorkbenchRegionsContext =
  createContext<WorkbenchRegionsController | null>(null);

export function useWorkbenchTab(
  tab: WorkbenchTabConfig | null,
): boolean {
  const controller = useContext(WorkbenchTabContext);

  useLayoutEffect(() => {
    if (!controller || !tab) {
      return;
    }
    controller.setTab(tab);
    return () => {
      controller.clearTab(tab.key);
    };
  }, [controller, tab]);

  return Boolean(controller);
}

export function useWorkbenchRegions(
  regions: WorkbenchRegionsConfig | null,
): boolean {
  const controller = useContext(WorkbenchRegionsContext);

  useLayoutEffect(() => {
    if (!controller || !regions) {
      return;
    }
    controller.setRegions(regions);
    return () => {
      controller.clearRegions(regions.key);
    };
  }, [controller, regions]);

  return Boolean(controller);
}
