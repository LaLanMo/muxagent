import { create } from "zustand";
import type {
  WorkbenchSidebarViewId,
  WorkbenchTabDescriptor,
  WorkbenchTabId,
} from "@/domain/routes";

export type WorkbenchSecondarySidebarState = {
  available: boolean;
  open: boolean;
  size?: number;
};

type WorkbenchStoreState = {
  activeSidebarView: WorkbenchSidebarViewId;
  sidebarOpen: boolean;
  panelOpen: boolean;
  sidebarWidth: number;
  panelHeight: number;
  tabs: WorkbenchTabDescriptor[];
  activeTabId?: WorkbenchTabId;
  secondarySidebarStateByTabId: Partial<
    Record<WorkbenchTabId, WorkbenchSecondarySidebarState>
  >;
  sidebarHydrated: boolean;
  syncRouteTab: (tab: WorkbenchTabDescriptor) => void;
  updateTab: (
    tabId: WorkbenchTabId,
    patch: Partial<WorkbenchTabDescriptor>,
  ) => void;
  activateTab: (tabId: WorkbenchTabId) => void;
  closeTab: (tabId: WorkbenchTabId) => void;
  clearTabs: () => void;
  hydrateSidebarView: (viewId: WorkbenchSidebarViewId) => void;
  selectSidebarView: (viewId: WorkbenchSidebarViewId) => void;
  setSidebarOpen: (open: boolean) => void;
  toggleSidebarOpen: () => void;
  registerTabSecondarySidebar: (
    tabId: WorkbenchTabId,
    registration: {
      available: boolean;
      defaultOpen?: boolean;
      preferredSize?: number;
    },
  ) => void;
  setTabSecondarySidebarOpen: (tabId: WorkbenchTabId, open: boolean) => void;
  toggleTabSecondarySidebarOpen: (tabId: WorkbenchTabId) => void;
  setPanelOpen: (open: boolean) => void;
  togglePanelOpen: () => void;
};

function tabsEqual(
  left: WorkbenchTabDescriptor,
  right: WorkbenchTabDescriptor,
): boolean {
  return (
    left.id === right.id &&
    left.kind === right.kind &&
    left.title === right.title &&
    left.href === right.href &&
    Boolean(left.closeable) === Boolean(right.closeable)
  );
}

function upsertTab(
  tabs: WorkbenchTabDescriptor[],
  tab: WorkbenchTabDescriptor,
): WorkbenchTabDescriptor[] {
  const existingIndex = tabs.findIndex((entry) => entry.id === tab.id);
  if (existingIndex < 0) {
    return [...tabs, tab];
  }

  const existing = tabs[existingIndex];
  if (tabsEqual(existing, tab)) {
    return tabs;
  }

  const nextTabs = [...tabs];
  nextTabs[existingIndex] = tab;
  return nextTabs;
}

export const useWorkbenchStore = create<WorkbenchStoreState>((set) => ({
  activeSidebarView: "tasks",
  sidebarOpen: true,
  panelOpen: false,
  sidebarWidth: 280,
  panelHeight: 220,
  tabs: [],
  activeTabId: undefined,
  secondarySidebarStateByTabId: {},
  sidebarHydrated: false,
  syncRouteTab: (tab) =>
    set((state) => {
      const tabs = upsertTab(state.tabs, tab);
      if (tabs === state.tabs && state.activeTabId === tab.id) {
        return {};
      }
      return {
        tabs,
        activeTabId: tab.id,
      };
    }),
  updateTab: (tabId, patch) =>
    set((state) => {
      const existingIndex = state.tabs.findIndex((tab) => tab.id === tabId);
      if (existingIndex < 0) {
        return {};
      }

      const existing = state.tabs[existingIndex];
      const nextTab = { ...existing, ...patch, id: existing.id };
      if (tabsEqual(existing, nextTab)) {
        return {};
      }

      const tabs = [...state.tabs];
      tabs[existingIndex] = nextTab;
      return { tabs };
    }),
  activateTab: (tabId) =>
    set((state) =>
      state.activeTabId === tabId ? {} : { activeTabId: tabId },
    ),
  closeTab: (tabId) =>
    set((state) => {
      const nextSecondarySidebarStateByTabId = {
        ...state.secondarySidebarStateByTabId,
      };
      delete nextSecondarySidebarStateByTabId[tabId];
      return {
        tabs: state.tabs.filter((tab) => tab.id !== tabId),
        activeTabId:
          state.activeTabId === tabId ? undefined : state.activeTabId,
        secondarySidebarStateByTabId: nextSecondarySidebarStateByTabId,
      };
    }),
  clearTabs: () =>
    set((state) =>
      state.tabs.length === 0 && state.activeTabId == null
        ? {}
        : {
            tabs: [],
            activeTabId: undefined,
            secondarySidebarStateByTabId: {},
          },
    ),
  hydrateSidebarView: (viewId) =>
    set((state) =>
      state.sidebarHydrated
        ? {}
        : {
            activeSidebarView: viewId,
            sidebarHydrated: true,
          },
    ),
  selectSidebarView: (viewId) =>
    set((state) =>
      state.activeSidebarView === viewId
        ? {
            sidebarHydrated: true,
            sidebarOpen: !state.sidebarOpen,
          }
        : {
            activeSidebarView: viewId,
            sidebarHydrated: true,
            sidebarOpen: true,
          },
    ),
  setSidebarOpen: (open) =>
    set((state) => (state.sidebarOpen === open ? {} : { sidebarOpen: open })),
  toggleSidebarOpen: () =>
    set((state) => ({ sidebarOpen: !state.sidebarOpen })),
  registerTabSecondarySidebar: (tabId, registration) =>
    set((state) => {
      const current = state.secondarySidebarStateByTabId[tabId];
      const next: WorkbenchSecondarySidebarState = current
        ? {
            available: registration.available,
            open: registration.available ? current.open : false,
            size: current.size ?? registration.preferredSize,
          }
        : {
            available: registration.available,
            open: registration.available && Boolean(registration.defaultOpen),
            size: registration.preferredSize,
          };
      if (
        current &&
        current.available === next.available &&
        current.open === next.open &&
        current.size === next.size
      ) {
        return {};
      }
      return {
        secondarySidebarStateByTabId: {
          ...state.secondarySidebarStateByTabId,
          [tabId]: next,
        },
      };
    }),
  setTabSecondarySidebarOpen: (tabId, open) =>
    set((state) => {
      const current = state.secondarySidebarStateByTabId[tabId];
      if (!current || !current.available || current.open === open) {
        return {};
      }
      return {
        secondarySidebarStateByTabId: {
          ...state.secondarySidebarStateByTabId,
          [tabId]: {
            ...current,
            open,
          },
        },
      };
    }),
  toggleTabSecondarySidebarOpen: (tabId) =>
    set((state) => {
      const current = state.secondarySidebarStateByTabId[tabId];
      if (!current || !current.available) {
        return {};
      }
      return {
        secondarySidebarStateByTabId: {
          ...state.secondarySidebarStateByTabId,
          [tabId]: {
            ...current,
            open: !current.open,
          },
        },
      };
    }),
  setPanelOpen: (open) =>
    set((state) => (state.panelOpen === open ? {} : { panelOpen: open })),
  togglePanelOpen: () =>
    set((state) => ({ panelOpen: !state.panelOpen })),
}));
