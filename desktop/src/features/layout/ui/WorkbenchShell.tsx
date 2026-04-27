import {
  type MouseEvent,
  useCallback,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  Cpu,
  FileDiff,
  GitBranch,
  GitCommit,
  LayoutGrid,
  ListTodo,
  MessageSquare,
  PanelLeft,
  PanelRight,
  Settings,
  SlidersHorizontal,
  X,
} from "lucide-react";
import { useLocation, useNavigate } from "react-router-dom";
import {
  deriveWorkbenchSidebarView,
  parseTaskBoardHref,
  resolveWorkbenchTab,
  workbenchZeroTabPath,
  type WorkbenchTabDescriptor,
  type WorkbenchTabKind,
} from "@/domain/routes";
import appIcon from "@/assets/app-icon.png";
import { useShellModel } from "@/features/app/model/use-shell-model";
import { useWorkspaceSelection } from "@/features/app/model/use-workspace-selection";
import { ChatPanel } from "@/features/chat/ui/ChatPanel";
import { useWorkbenchStore } from "@/features/layout/model/use-workbench-store";
import { ConfigsPanel } from "@/features/layout/ui/ConfigsPanel";
import { SettingsPanel } from "@/features/layout/ui/SettingsPanel";
import { SourceControlPanel } from "@/features/layout/ui/SourceControlPanel";
import { TasksPanel } from "@/features/layout/ui/TasksPanel";
import {
  WorkbenchRegionsContext,
  WorkbenchTabContext,
  type WorkbenchRegionPanel,
  type WorkbenchRegionsConfig,
  type WorkbenchTabConfig,
} from "@/features/layout/ui/workbench-surface";
import { startWindowDrag } from "@/features/layout/ui/window-drag";
import { ConfirmDialog } from "@/features/shared/ui/ConfirmDialog";

function activityButtonClass(active: boolean): string {
  return active
    ? "workbench__activity-link is-active"
    : "workbench__activity-link";
}

function titlebarActionClass(active: boolean): string {
  return active
    ? "workbench__titlebar-action is-active"
    : "workbench__titlebar-action";
}

function iconForWorkbenchTab(kind: WorkbenchTabKind) {
  switch (kind) {
    case "chat":
      return <MessageSquare size={13} strokeWidth={1.8} />;
    case "task-detail":
      return <MessageSquare size={13} strokeWidth={1.8} />;
    case "source-control":
      return <GitBranch size={13} strokeWidth={1.8} />;
    case "file-diff":
      return <FileDiff size={13} strokeWidth={1.8} />;
    case "commit-diff":
      return <GitCommit size={13} strokeWidth={1.8} />;
    case "config-list":
    case "config-detail":
      return <SlidersHorizontal size={13} strokeWidth={1.8} />;
    case "settings":
      return <Cpu size={13} strokeWidth={1.8} />;
    case "task-board":
    default:
      return <LayoutGrid size={13} strokeWidth={1.8} />;
  }
}

function windowTitleForTab(tab?: WorkbenchTabDescriptor): string {
  return tab ? `muxagent — ${tab.title}` : "muxagent";
}

function ReservedPanelBody({
  message,
  title,
}: {
  message: string;
  title: string;
}) {
  return (
    <div className="workbench__reserved-panel">
      <div className="workbench__reserved-panel-copy">
        <span className="workbench__reserved-panel-kicker">Reserved</span>
        <strong>{title}</strong>
        <p>{message}</p>
      </div>
    </div>
  );
}

const defaultBottomPanel: WorkbenchRegionPanel = {
  title: "Transcript · Live Stream · Output",
  size: 220,
  testId: "workbench-bottom-panel",
  tabs: [
    { key: "transcript", label: "Transcript", active: true },
    { key: "live-stream", label: "Live Stream" },
    { key: "output", label: "Output" },
  ],
  content: (
    <ReservedPanelBody
      message="Low-priority streams and auxiliary output can move here once the product decides what belongs in the dock."
      title="Bottom Panel"
    />
  ),
};

type RegistrationEntry = {
  key: string;
};

type RegistrationRegistry<T extends RegistrationEntry> = {
  entries: Record<string, T>;
  order: string[];
};

function createRegistrationRegistry<T extends RegistrationEntry>(): RegistrationRegistry<T> {
  return { entries: {}, order: [] };
}

function upsertRegistrationEntry<T extends RegistrationEntry>(
  registry: RegistrationRegistry<T>,
  entry: T,
): RegistrationRegistry<T> {
  const existing = registry.entries[entry.key];
  const nextOrder =
    registry.order.at(-1) === entry.key
      ? registry.order
      : [...registry.order.filter((key) => key !== entry.key), entry.key];
  if (existing === entry && nextOrder === registry.order) {
    return registry;
  }
  return {
    entries: {
      ...registry.entries,
      [entry.key]: entry,
    },
    order: nextOrder,
  };
}

function removeRegistrationEntry<T extends RegistrationEntry>(
  registry: RegistrationRegistry<T>,
  key: string,
): RegistrationRegistry<T> {
  if (!(key in registry.entries)) {
    return registry;
  }
  const nextEntries = { ...registry.entries };
  delete nextEntries[key];
  return {
    entries: nextEntries,
    order: registry.order.filter((entryKey) => entryKey !== key),
  };
}

function latestRegistrationEntryForTab<
  T extends RegistrationEntry & { tabId?: WorkbenchTabDescriptor["id"] },
>(
  registry: RegistrationRegistry<T>,
  tabId: WorkbenchTabDescriptor["id"] | undefined,
): T | null {
  if (!tabId) {
    return null;
  }
  for (let index = registry.order.length - 1; index >= 0; index -= 1) {
    const key = registry.order[index];
    const entry = key ? registry.entries[key] : undefined;
    if (entry?.tabId === tabId) {
      return entry;
    }
  }
  return null;
}

function mergeDisplayedTabs(
  tabs: WorkbenchTabDescriptor[],
  routeTab: WorkbenchTabDescriptor | null,
): WorkbenchTabDescriptor[] {
  if (!routeTab) {
    return tabs;
  }
  const existingIndex = tabs.findIndex((tab) => tab.id === routeTab.id);
  if (existingIndex < 0) {
    return [...tabs, routeTab];
  }
  const existing = tabs[existingIndex];
  if (
    existing.id === routeTab.id &&
    existing.kind === routeTab.kind &&
    existing.title === routeTab.title &&
    existing.href === routeTab.href &&
    Boolean(existing.closeable) === Boolean(routeTab.closeable)
  ) {
    return tabs;
  }
  const nextTabs = [...tabs];
  nextTabs[existingIndex] = routeTab;
  return nextTabs;
}

function EmptyWorkspaceState() {
  const contentRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    contentRef.current?.focus();
  }, []);

  return (
    <div className="workbench__empty-state" data-testid="workbench-empty-state">
      <div
        aria-label="No tab open"
        className="workbench__empty-brand"
        data-testid="workbench-empty-brand"
        ref={contentRef}
        tabIndex={-1}
      >
        <img
          alt=""
          aria-hidden="true"
          className="workbench__empty-brand-icon"
          src={appIcon}
        />
        <strong className="workbench__empty-brand-name">muxagent</strong>
      </div>
    </div>
  );
}

function ActivityBarButton({
  active,
  label,
  onClick,
  children,
}: {
  active: boolean;
  label: string;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      aria-label={label}
      aria-pressed={active}
      className={activityButtonClass(active)}
      data-testid={`workbench-activity-${label.toLowerCase().replace(/\s+/g, "-")}`}
      onClick={onClick}
      type="button"
    >
      {children}
    </button>
  );
}

function ToggleAction({
  active,
  disabled = false,
  label,
  onClick,
  children,
}: {
  active: boolean;
  disabled?: boolean;
  label: string;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      aria-label={label}
      aria-pressed={active}
      className={titlebarActionClass(active)}
      data-no-window-drag="true"
      disabled={disabled}
      onClick={onClick}
      type="button"
    >
      {children}
    </button>
  );
}

function SlotHeader({
  panel,
  testId,
}: {
  panel: WorkbenchRegionPanel;
  testId?: string;
}) {
  if (panel.tabs?.length) {
    return (
      <header
        className="workbench__slot-header workbench__slot-header--tabs"
        data-testid={testId}
      >
        <div className="workbench__slot-tabstrip">
          {panel.tabs.map((tab) => (
            <span
              className={`workbench__slot-tab${tab.active ? " is-active" : ""}`}
              key={tab.key}
            >
              {tab.label}
            </span>
          ))}
        </div>
      </header>
    );
  }

  return (
    <header className="workbench__slot-header" data-testid={testId}>
      <span className="workbench__slot-title">{panel.title}</span>
    </header>
  );
}

export function WorkbenchShell({ children }: { children: ReactNode }) {
  const shell = useShellModel();
  const { clearWorkspaceSelection } = useWorkspaceSelection();
  const location = useLocation();
  const navigate = useNavigate();
  const currentHref = `${location.pathname}${location.search}`;
  const isZeroTabRoute = location.pathname === workbenchZeroTabPath;

  const routeTab = useMemo(
    () => resolveWorkbenchTab(location.pathname, location.search),
    [location.pathname, location.search],
  );
  const routeSidebarView = useMemo(
    () => deriveWorkbenchSidebarView(location.pathname),
    [location.pathname],
  );

  const activeSidebarView = useWorkbenchStore(
    (state) => state.activeSidebarView,
  );
  const sidebarOpen = useWorkbenchStore((state) => state.sidebarOpen);
  const secondarySidebarStateByTabId = useWorkbenchStore(
    (state) => state.secondarySidebarStateByTabId,
  );
  const panelOpen = useWorkbenchStore((state) => state.panelOpen);
  const sidebarWidth = useWorkbenchStore((state) => state.sidebarWidth);
  const panelHeight = useWorkbenchStore((state) => state.panelHeight);
  const tabs = useWorkbenchStore((state) => state.tabs);
  const activeTabId = useWorkbenchStore((state) => state.activeTabId);
  const syncRouteTab = useWorkbenchStore((state) => state.syncRouteTab);
  const activateTab = useWorkbenchStore((state) => state.activateTab);
  const closeTab = useWorkbenchStore((state) => state.closeTab);
  const clearTabs = useWorkbenchStore((state) => state.clearTabs);
  const hydrateSidebarView = useWorkbenchStore(
    (state) => state.hydrateSidebarView,
  );
  const selectSidebarView = useWorkbenchStore(
    (state) => state.selectSidebarView,
  );
  const showSidebarView = useWorkbenchStore((state) => state.showSidebarView);
  const toggleSidebarOpen = useWorkbenchStore(
    (state) => state.toggleSidebarOpen,
  );
  const registerTabSecondarySidebar = useWorkbenchStore(
    (state) => state.registerTabSecondarySidebar,
  );
  const toggleTabSecondarySidebarOpen = useWorkbenchStore(
    (state) => state.toggleTabSecondarySidebarOpen,
  );
  const [tabRegistry, setTabRegistry] = useState<
    RegistrationRegistry<WorkbenchTabConfig>
  >(() => createRegistrationRegistry());
  const [regionsRegistry, setRegionsRegistry] = useState<
    RegistrationRegistry<WorkbenchRegionsConfig>
  >(() => createRegistrationRegistry());

  const tabController = useMemo(
    () => ({
      setTab: (nextTab: WorkbenchTabConfig) => {
        setTabRegistry((current) => upsertRegistrationEntry(current, nextTab));
      },
      clearTab: (key: string) => {
        setTabRegistry((current) => removeRegistrationEntry(current, key));
      },
    }),
    [],
  );
  const regionsController = useMemo(
    () => ({
      setRegions: (nextRegions: WorkbenchRegionsConfig) => {
        setRegionsRegistry((current) => upsertRegistrationEntry(current, nextRegions));
      },
      clearRegions: (key: string) => {
        setRegionsRegistry((current) => removeRegistrationEntry(current, key));
      },
    }),
    [],
  );

  const routeTabId = routeTab?.id;
  const registeredTab = latestRegistrationEntryForTab(tabRegistry, routeTabId);
  const registeredRegions = latestRegistrationEntryForTab(regionsRegistry, routeTabId);
  const resolvedRouteTab = useMemo(() => {
    if (!routeTab) {
      return null;
    }
    const existingTab = useWorkbenchStore
      .getState()
      .tabs.find((tab) => tab.id === routeTab.id);
    const registeredTitle =
      registeredTab?.tabId === routeTab.id ? registeredTab.title?.trim() : undefined;
    const existingWorkspaceBoardTitle =
      routeTab.kind === "task-board" &&
      routeTab.id !== "task-board" &&
      existingTab?.title &&
      existingTab.title !== "Board"
        ? existingTab.title
        : undefined;
    const title = registeredTitle ?? existingWorkspaceBoardTitle;
    return title ? { ...routeTab, title } : routeTab;
  }, [registeredTab?.tabId, registeredTab?.title, routeTab]);

  useLayoutEffect(() => {
    if (isZeroTabRoute) {
      clearTabs();
    } else if (resolvedRouteTab) {
      syncRouteTab(resolvedRouteTab);
    }
    hydrateSidebarView(routeSidebarView);
  }, [
    clearTabs,
    hydrateSidebarView,
    isZeroTabRoute,
    routeSidebarView,
    resolvedRouteTab,
    syncRouteTab,
  ]);

  const centerTabs = useMemo(
    () => (isZeroTabRoute ? [] : mergeDisplayedTabs(tabs, resolvedRouteTab)),
    [isZeroTabRoute, resolvedRouteTab, tabs],
  );
  const activeCenterTabId = resolvedRouteTab?.id ?? activeTabId;
  const activeTab =
    centerTabs.find((tab) => tab.id === activeCenterTabId) ?? centerTabs[0];
  const showEmptyWorkspaceState = centerTabs.length === 0;
  const registeredSecondarySidebar = registeredRegions?.secondarySidebar;
  const registeredPanel = registeredRegions?.panel;
  const activeSecondarySidebarState = activeTab?.id
    ? secondarySidebarStateByTabId[activeTab.id]
    : undefined;

  useEffect(() => {
    if (!activeTab?.id || showEmptyWorkspaceState || registeredRegions?.tabId !== activeTab.id) {
      return;
    }
    if (registeredSecondarySidebar === undefined) {
      return;
    }
    if (registeredSecondarySidebar === null) {
      registerTabSecondarySidebar(activeTab.id, { available: false });
      return;
    }
    registerTabSecondarySidebar(activeTab.id, {
      available: true,
      defaultOpen: registeredSecondarySidebar.defaultOpen,
      preferredSize:
        registeredSecondarySidebar.preferredSize ??
        registeredSecondarySidebar.panel.size,
    });
  }, [
    activeTab?.id,
    registerTabSecondarySidebar,
    registeredRegions?.tabId,
    registeredSecondarySidebar,
    showEmptyWorkspaceState,
  ]);

  const leftPanel =
    activeSidebarView === "chat" ? (
      <ChatPanel />
    ) : activeSidebarView === "source-control" ? (
      <SourceControlPanel />
    ) : activeSidebarView === "configs" ? (
      <ConfigsPanel />
    ) : activeSidebarView === "settings" ? (
      <SettingsPanel />
    ) : (
      <TasksPanel shell={shell} />
    );

  const activeSecondarySidebarAvailable = showEmptyWorkspaceState
    ? false
    : activeSecondarySidebarState?.available ??
      (registeredSecondarySidebar === null
        ? false
        : Boolean(registeredSecondarySidebar));
  const activeSecondarySidebarOpen = activeSecondarySidebarAvailable
    ? activeSecondarySidebarState?.open ??
      (registeredSecondarySidebar && registeredSecondarySidebar !== null
        ? Boolean(registeredSecondarySidebar.defaultOpen)
        : false)
    : false;
  const rightPanel =
    activeSecondarySidebarAvailable &&
    registeredSecondarySidebar &&
    registeredSecondarySidebar !== null
      ? registeredSecondarySidebar.panel
      : null;
  const bottomPanel = showEmptyWorkspaceState
    ? null
    : registeredPanel !== undefined
      ? registeredPanel
      : defaultBottomPanel;
  const rightPanelVisible = activeSecondarySidebarOpen && Boolean(rightPanel);
  const bottomPanelVisible = panelOpen && Boolean(bottomPanel);
  const rightPanelToggleActive = activeSecondarySidebarAvailable && activeSecondarySidebarOpen;

  const bodyStyle = useMemo(
    () => ({
      gridTemplateColumns: [
        "60px",
        sidebarOpen ? `${sidebarWidth}px` : "0px",
        "minmax(0, 1fr)",
        rightPanelVisible
          ? `${
              activeSecondarySidebarState?.size ??
              registeredSecondarySidebar?.preferredSize ??
              rightPanel?.size ??
              320
            }px`
          : "0px",
      ].join(" "),
    }),
    [
      activeSecondarySidebarState?.size,
      registeredSecondarySidebar?.preferredSize,
      rightPanel?.size,
      rightPanelVisible,
      sidebarOpen,
      sidebarWidth,
    ],
  );

  const bottomPanelStyle = useMemo(
    () => ({
      height: `${bottomPanel?.size ?? panelHeight}px`,
    }),
    [bottomPanel?.size, panelHeight],
  );

  const onTitlebarMouseDown = useCallback(
    (event: MouseEvent<HTMLElement>) => {
      void startWindowDrag(event);
    },
    [],
  );

  const onOpenCenterTab = useCallback(
    (tab: WorkbenchTabDescriptor) => {
      activateTab(tab.id);
      if (tab.kind === "task-board") {
        showSidebarView("tasks");
        const boardRoute = parseTaskBoardHref(tab.href);
        if (boardRoute?.scope.kind === "all") {
          clearWorkspaceSelection({ navigateToTaskSurface: false });
        }
      }
      if (tab.kind === "chat") {
        showSidebarView("chat");
      }
      if (tab.href !== currentHref) {
        navigate(tab.href);
      }
    },
    [
      activateTab,
      clearWorkspaceSelection,
      currentHref,
      navigate,
      showSidebarView,
    ],
  );

  const onCloseCenterTab = useCallback(
    (tabId: WorkbenchTabDescriptor["id"]) => {
      const tabIndex = centerTabs.findIndex((tab) => tab.id === tabId);
      if (tabIndex < 0) {
        return;
      }

      const nextTabs = centerTabs.filter((tab) => tab.id !== tabId);
      const closingActiveTab = activeTab?.id === tabId;
      const fallbackTab =
        nextTabs[Math.max(0, Math.min(tabIndex - 1, nextTabs.length - 1))] ??
        nextTabs[0];

      closeTab(tabId);

      if (!closingActiveTab) {
        return;
      }

      if (fallbackTab) {
        if (fallbackTab.href !== currentHref) {
          navigate(fallbackTab.href);
        }
        return;
      }

      navigate(workbenchZeroTabPath);
    },
    [activeTab?.id, centerTabs, closeTab, currentHref, navigate],
  );

  return (
    <WorkbenchTabContext.Provider value={tabController}>
      <WorkbenchRegionsContext.Provider value={regionsController}>
        <main className="workbench" data-testid="workbench-shell">
          <header className="workbench__titlebar" onMouseDown={onTitlebarMouseDown}>
            <div className="workbench__titlebar-side" />
            <div className="workbench__titlebar-title">
              {windowTitleForTab(activeTab ?? resolvedRouteTab ?? undefined)}
            </div>
            <div className="workbench__titlebar-side workbench__titlebar-side--actions">
              <ToggleAction
                active={sidebarOpen}
                label={sidebarOpen ? "Collapse left panel" : "Expand left panel"}
                onClick={toggleSidebarOpen}
              >
                <PanelLeft size={16} strokeWidth={1.9} />
              </ToggleAction>
              <ToggleAction
                active={rightPanelToggleActive}
                disabled={!activeSecondarySidebarAvailable}
                label={
                  rightPanelToggleActive
                    ? "Collapse right panel"
                    : "Expand right panel"
                }
                onClick={() => {
                  if (activeTab?.id) {
                    toggleTabSecondarySidebarOpen(activeTab.id);
                  }
                }}
              >
                <PanelRight size={16} strokeWidth={1.9} />
              </ToggleAction>
            </div>
          </header>

          <div className="workbench__body" style={bodyStyle}>
            <aside className="workbench__activity-bar">
              <div className="workbench__activity-top">
                <nav aria-label="Primary" className="workbench__activity-nav">
                  <ActivityBarButton
                    active={activeSidebarView === "tasks"}
                    label="Tasks"
                    onClick={() => selectSidebarView("tasks")}
                  >
                    <ListTodo size={18} strokeWidth={1.9} />
                  </ActivityBarButton>
                  <ActivityBarButton
                    active={activeSidebarView === "chat"}
                    label="Chat"
                    onClick={() => selectSidebarView("chat")}
                  >
                    <MessageSquare size={18} strokeWidth={1.9} />
                  </ActivityBarButton>
                  <ActivityBarButton
                    active={activeSidebarView === "source-control"}
                    label="Source Control"
                    onClick={() => selectSidebarView("source-control")}
                  >
                    <GitBranch size={18} strokeWidth={1.9} />
                  </ActivityBarButton>
                  <ActivityBarButton
                    active={activeSidebarView === "configs"}
                    label="Configs"
                    onClick={() => selectSidebarView("configs")}
                  >
                    <SlidersHorizontal size={18} strokeWidth={1.9} />
                  </ActivityBarButton>
                </nav>
              </div>

              <nav aria-label="Utility" className="workbench__activity-bottom">
                <ActivityBarButton
                  active={activeSidebarView === "settings"}
                  label="Settings"
                  onClick={() => selectSidebarView("settings")}
                >
                  <Settings size={18} strokeWidth={1.9} />
                </ActivityBarButton>
              </nav>
            </aside>

            {sidebarOpen ? (
              <section
                className="workbench__panel"
                data-testid={`workbench-panel-${activeSidebarView}`}
              >
                {leftPanel}
              </section>
            ) : null}

            <section className="workbench__center-stack">
              <header
                aria-label="Workspace tabs"
                className="workbench__tabbar"
                data-testid="workbench-center-tabs"
                role="tablist"
              >
                {centerTabs.map((tab) => (
                  <div
                    className={`workbench__tab${tab.id === activeTab?.id ? " is-active" : ""}`}
                    data-testid={`workbench-tab-${tab.id}`}
                    key={tab.id}
                  >
                    <button
                      aria-current={tab.id === activeTab?.id ? "page" : undefined}
                      aria-selected={tab.id === activeTab?.id}
                      className="workbench__tab-button"
                      data-no-window-drag="true"
                      onClick={() => onOpenCenterTab(tab)}
                      role="tab"
                      type="button"
                    >
                      <span className="workbench__tab-icon" aria-hidden="true">
                        {iconForWorkbenchTab(tab.kind)}
                      </span>
                      <span className="workbench__tab-label">{tab.title}</span>
                    </button>
                    {tab.closeable ? (
                      <button
                        aria-label={`Close ${tab.title}`}
                        className="workbench__tab-close"
                        data-testid={`workbench-tab-close-${tab.id}`}
                        data-no-window-drag="true"
                        onClick={(event) => {
                          event.stopPropagation();
                          onCloseCenterTab(tab.id);
                        }}
                        type="button"
                      >
                        <X size={12} strokeWidth={1.9} />
                      </button>
                    ) : null}
                  </div>
                ))}
              </header>

              <section className="workbench__main" data-testid="workbench-main">
                {showEmptyWorkspaceState ? <EmptyWorkspaceState /> : children}
              </section>

              {bottomPanelVisible && bottomPanel ? (
                <section
                  className="workbench__bottom-panel"
                  data-testid={bottomPanel.testId ?? "workbench-bottom-panel"}
                  style={bottomPanelStyle}
                >
                  <SlotHeader panel={bottomPanel} />
                  <div className="workbench__slot-body">{bottomPanel.content}</div>
                </section>
              ) : null}
            </section>

            {rightPanelVisible && rightPanel ? (
              <aside
                className="workbench__right-panel"
                data-testid="workbench-right-panel"
              >
                <SlotHeader panel={rightPanel} testId={rightPanel.testId} />
                <div className="workbench__slot-body">{rightPanel.content}</div>
              </aside>
            ) : null}
          </div>
        </main>

        {shell.workspaceRemoveDialog ? (
          <ConfirmDialog {...shell.workspaceRemoveDialog} />
        ) : null}
      </WorkbenchRegionsContext.Provider>
    </WorkbenchTabContext.Provider>
  );
}
