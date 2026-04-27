import {
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
} from "react";
import { Check, ChevronDown, Folder, RefreshCw } from "lucide-react";
import {
  chatTabTitle,
  useChatScreen,
} from "@/features/chat/model/use-chat-screen";
import {
  configOptionByCategory,
  flattenConfigOptionValues,
} from "@/domain/agent-chat-config";
import { ChatComposer } from "@/features/chat/ui/ChatComposer";
import { ChatTranscript } from "@/features/chat/ui/ChatTranscript";
import {
  useWorkbenchRegions,
  useWorkbenchTab,
} from "@/features/layout/ui/workbench-surface";
import { Button } from "@/features/shared/ui/Button";
import type { AgentChatRuntimeDto, AgentChatSessionConfigOptionDto } from "@/rpc/types";

function runtimeLabel(runtimes: AgentChatRuntimeDto[], runtimeId: string): string {
  return runtimes.find((runtime) => runtime.id === runtimeId)?.label ?? runtimeId;
}

function compactPath(path: string): string {
  const parts = path.split(/[\\/]/).filter(Boolean);
  if (parts.length <= 2) {
    return path;
  }
  return parts.slice(-2).join("/");
}

function configValueLabel(
  option: AgentChatSessionConfigOptionDto | undefined,
  fallback: string,
): string {
  const current = option?.currentValue?.trim();
  if (!current) {
    return fallback;
  }
  return (
    flattenConfigOptionValues(option).find((entry) => entry.value === current)
      ?.name ?? current
  );
}

function modelLabel(options: AgentChatSessionConfigOptionDto[] | undefined): string {
  return configValueLabel(configOptionByCategory(options, "model"), "Model");
}

function optionSelectValue(
  option: AgentChatSessionConfigOptionDto | undefined,
): string {
  return (
    option?.currentValue?.trim() ||
    flattenConfigOptionValues(option)[0]?.value ||
    ""
  );
}

function modeOptions(
  option: AgentChatSessionConfigOptionDto | undefined,
  fallback: { value: string; label: string }[],
): { value: string; label: string }[] {
  const values =
    flattenConfigOptionValues(option).map((entry) => ({
      value: entry.value,
      label: entry.name || entry.value,
    }));
  const availableValues = values.length > 0 ? values : fallback;
  const current = option?.currentValue?.trim();
  if (!current || availableValues.some((entry) => entry.value === current)) {
    return availableValues;
  }
  return [{ value: current, label: current }, ...availableValues];
}

type RuntimePickerProps = {
  disabled: boolean;
  runtimes: AgentChatRuntimeDto[];
  selectedRuntimeId: string;
  onChange: (runtimeId: string) => void;
};

function RuntimePicker({
  disabled,
  runtimes,
  selectedRuntimeId,
  onChange,
}: RuntimePickerProps) {
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const listboxId = useId();
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const optionRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const selectedRuntime = runtimes.find(
    (runtime) => runtime.id === selectedRuntimeId,
  );
  const enabledIndices = useMemo(
    () =>
      runtimes
        .map((runtime, index) => (runtime.ready ? index : -1))
        .filter((index) => index >= 0),
    [runtimes],
  );

  function fallbackActiveIndex(): number {
    const selectedIndex = runtimes.findIndex(
      (runtime) => runtime.id === selectedRuntimeId && runtime.ready,
    );
    return selectedIndex >= 0 ? selectedIndex : enabledIndices[0] ?? 0;
  }

  function optionDomId(runtimeId: string): string {
    return `${listboxId}-${runtimeId.replace(/[^A-Za-z0-9_-]/g, "_")}`;
  }

  function focusTrigger() {
    window.requestAnimationFrame(() => triggerRef.current?.focus());
  }

  function closePicker({ restoreFocus = false } = {}) {
    setOpen(false);
    if (restoreFocus) {
      focusTrigger();
    }
  }

  function openPicker(nextActiveIndex = fallbackActiveIndex()) {
    if (disabled || enabledIndices.length === 0) {
      return;
    }
    setActiveIndex(nextActiveIndex);
    setOpen(true);
  }

  function moveActive(delta: number) {
    if (enabledIndices.length === 0) {
      return;
    }
    const currentEnabledIndex = enabledIndices.indexOf(activeIndex);
    const startIndex = currentEnabledIndex >= 0 ? currentEnabledIndex : 0;
    const nextEnabledIndex =
      (startIndex + delta + enabledIndices.length) % enabledIndices.length;
    setActiveIndex(enabledIndices[nextEnabledIndex] ?? activeIndex);
  }

  function selectRuntime(index: number) {
    const runtime = runtimes[index];
    if (!runtime?.ready) {
      return;
    }
    onChange(runtime.id);
    closePicker({ restoreFocus: true });
  }

  function handleTriggerKeyDown(event: ReactKeyboardEvent<HTMLButtonElement>) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      openPicker(fallbackActiveIndex());
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      openPicker(enabledIndices.at(-1) ?? fallbackActiveIndex());
    }
  }

  function handleOptionKeyDown(
    event: ReactKeyboardEvent<HTMLButtonElement>,
    index: number,
  ) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault();
        moveActive(1);
        break;
      case "ArrowUp":
        event.preventDefault();
        moveActive(-1);
        break;
      case "Home":
        event.preventDefault();
        setActiveIndex(enabledIndices[0] ?? index);
        break;
      case "End":
        event.preventDefault();
        setActiveIndex(enabledIndices.at(-1) ?? index);
        break;
      case "Enter":
      case " ":
        event.preventDefault();
        selectRuntime(index);
        break;
      case "Escape":
        event.preventDefault();
        closePicker({ restoreFocus: true });
        break;
      case "Tab":
        closePicker();
        break;
      default:
        break;
    }
  }

  useEffect(() => {
    if (!open) {
      return;
    }
    function handlePointerDown(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    }
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") {
        closePicker({ restoreFocus: true });
      }
    }
    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleKeyDown);
    return () => {
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [open]);

  useEffect(() => {
    if (!open) {
      return;
    }
    const runtime = runtimes[activeIndex];
    if (!runtime?.ready) {
      return;
    }
    window.requestAnimationFrame(() => optionRefs.current[runtime.id]?.focus());
  }, [activeIndex, open, runtimes]);

  return (
    <div className="chat-runtime-picker" ref={rootRef}>
      <button
        aria-controls={open ? listboxId : undefined}
        aria-expanded={open}
        aria-haspopup="listbox"
        aria-label={`Runtime: ${selectedRuntime?.label ?? "No runtime"}`}
        className="chat-composer__pill chat-runtime-picker__trigger"
        disabled={disabled || enabledIndices.length === 0}
        onClick={() => {
          if (open) {
            closePicker();
          } else {
            openPicker();
          }
        }}
        onKeyDown={handleTriggerKeyDown}
        ref={triggerRef}
        type="button"
      >
        <span
          className="chat-runtime-picker__trigger-label"
          title={selectedRuntime?.label ?? "No runtime"}
        >
          {selectedRuntime?.label ?? "No runtime"}
        </span>
        <ChevronDown aria-hidden="true" size={12} strokeWidth={1.8} />
      </button>
      {open ? (
        <div className="chat-runtime-picker__menu">
          <div className="chat-runtime-picker__section-label">RUNTIME</div>
          <div
            aria-label="Runtime"
            className="chat-runtime-picker__list"
            id={listboxId}
            role="listbox"
          >
            {runtimes.map((runtime, index) => {
              const selected = runtime.id === selectedRuntimeId;
              return (
                <button
                  aria-disabled={!runtime.ready}
                  aria-selected={selected}
                  className="chat-runtime-picker__option"
                  id={optionDomId(runtime.id)}
                  key={runtime.id}
                  onFocus={() => {
                    if (runtime.ready) {
                      setActiveIndex(index);
                    }
                  }}
                  onKeyDown={(event) => handleOptionKeyDown(event, index)}
                  onClick={() => {
                    selectRuntime(index);
                  }}
                  ref={(element) => {
                    optionRefs.current[runtime.id] = element;
                  }}
                  role="option"
                  tabIndex={runtime.ready && index === activeIndex ? 0 : -1}
                  type="button"
                >
                  <span className="chat-runtime-picker__option-main">
                    <span
                      className="chat-runtime-picker__option-dot"
                      aria-hidden="true"
                    />
                    <span className="chat-runtime-picker__option-label">
                      {runtime.label}
                    </span>
                    {!runtime.ready ? (
                      <span className="chat-runtime-picker__option-status">
                        offline
                      </span>
                    ) : null}
                  </span>
                  {selected ? (
                    <Check aria-hidden="true" size={13} strokeWidth={2} />
                  ) : null}
                </button>
              );
            })}
          </div>
        </div>
      ) : null}
    </div>
  );
}

export function ChatScreen() {
  const model = useChatScreen();
  const title = chatTabTitle(model.activeSession);
  const selectedRuntime = model.runtimes.find(
    (runtime) => runtime.id === model.selectedRuntimeId,
  );
  const activeModelOption = configOptionByCategory(
    model.activeSession?.configOptions,
    "model",
  );
  const activeModelValues = flattenConfigOptionValues(activeModelOption);
  const activeModeOption = configOptionByCategory(
    model.activeSession?.configOptions,
    "mode",
  );
  const activeModeValue =
    model.pendingMode ??
    activeModeOption?.currentValue?.trim() ??
    model.permissionMode;
  const activeModeOptions = modeOptions(activeModeOption, model.permissionOptions);
  const draftModeOption = configOptionByCategory(
    selectedRuntime?.configOptions,
    "mode",
  );
  const draftModeOptions = modeOptions(draftModeOption, model.permissionOptions);
  const draftModeValue =
    (draftModeOptions.find((option) => option.value === model.permissionMode)
      ?.value ??
      optionSelectValue(draftModeOption)) ||
    model.permissionMode;

  useWorkbenchTab({
    key: `chat-tab:${model.tabId}`,
    tabId: model.tabId,
    title,
  });
  useWorkbenchRegions({
    key: `chat-regions:${model.tabId}`,
    tabId: model.tabId,
    secondarySidebar: null,
    panel: null,
  });

  if (model.activeSessionId && !model.activeSession && !model.loading) {
    return (
      <section className="chat-screen" data-testid="chat-screen-missing">
        <div className="chat-screen__empty">
          <h1>Chat unavailable</h1>
          <p>Session metadata was not found.</p>
          {model.error ? (
            <div className="inline-banner inline-banner--failed" role="alert">
              {model.error}
            </div>
          ) : null}
          <Button
            leadingIcon={<RefreshCw strokeWidth={2} />}
            onClick={() => void model.refresh()}
            size="md"
            type="button"
            variant="secondary"
          >
            Refresh
          </Button>
        </div>
      </section>
    );
  }

  if (!model.activeSession) {
    return (
      <section className="chat-screen chat-screen--new" data-testid="chat-screen-new">
        <div className="chat-screen__new-center">
          <h1>What should we build in muxagent?</h1>
        </div>

        <div className="chat-screen__composer chat-screen__composer--new">
          {model.error ? (
            <div
              className="chat-screen__banner inline-banner inline-banner--failed"
              role="alert"
            >
              {model.error}
            </div>
          ) : null}
          <ChatComposer
            canSubmit={model.canStart}
            controls={{
              runtime: (
                <RuntimePicker
                  disabled={model.loading || model.loadingSession}
                  onChange={model.setSelectedRuntimeId}
                  runtimes={model.runtimes}
                  selectedRuntimeId={model.selectedRuntimeId}
                />
              ),
              model: (
                <button
                  className="chat-composer__pill"
                  disabled
                  title="Model can be changed after the session starts"
                  type="button"
                >
                  <span>{modelLabel(selectedRuntime?.configOptions)}</span>
                </button>
              ),
              mode: (
                <label className="chat-select-pill chat-select-pill--mode">
                  <span className="chat-mode-dot" aria-hidden="true" />
                  <span className="sr-only">Mode</span>
                  <select
                    disabled={model.loadingSession}
                    onChange={(event) => model.setPermissionMode(event.target.value)}
                    value={draftModeValue}
                  >
                    {draftModeOptions.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                  <ChevronDown aria-hidden="true" size={12} strokeWidth={1.8} />
                </label>
              ),
              cwd: (
                <label className="chat-select-pill chat-select-pill--cwd">
                  <Folder aria-hidden="true" size={12} strokeWidth={1.8} />
                  <span className="sr-only">Working directory</span>
                  <input
                    disabled={model.loadingSession}
                    onChange={(event) => model.setCwd(event.target.value)}
                    placeholder="/path/to/workspace"
                    type="text"
                    value={model.cwd}
                  />
                </label>
              ),
            }}
            disabled={model.loading}
            onChange={model.setPromptDraft}
            onSubmit={() => void model.startNewChat()}
            placeholder="Message…"
            sending={model.loadingSession}
            sendingLabel="Starting"
            submitLabel="Send"
            value={model.promptDraft}
          />
        </div>
      </section>
    );
  }

  return (
    <section className="chat-screen" data-testid="chat-screen">
      <header className="chat-thread-header">
        <div className="chat-thread-header__main">
          <span className="chat-thread-header__runtime-dot" aria-hidden="true" />
          <span className="chat-thread-header__runtime">
            {runtimeLabel(model.runtimes, model.activeSession.runtime ?? "")}
          </span>
          <span className="chat-thread-header__separator" aria-hidden="true">
            ·
          </span>
          <Folder aria-hidden="true" size={12} strokeWidth={1.8} />
          <span className="chat-thread-header__path" title={model.activeSession.cwd}>
            {compactPath(model.activeSession.cwd)}
          </span>
        </div>
      </header>

      {model.error ? (
        <div
          className="chat-screen__banner inline-banner inline-banner--failed"
          role="alert"
        >
          <span>{model.error}</span>
          {model.canRetryLoad ? (
            <button
              className="chat-screen__banner-action"
              onClick={model.retryLoadSession}
              type="button"
            >
              Retry
            </button>
          ) : null}
        </div>
      ) : null}

      <ChatTranscript
        loading={model.loadingSession}
        messages={model.messages}
      />
      <div className="chat-screen__composer">
        <ChatComposer
          canSubmit={model.canSend}
          controls={{
            model: (
              activeModelOption && activeModelValues.length ? (
                <label
                  aria-busy={model.changingModel || undefined}
                  className="chat-select-pill chat-select-pill--model"
                >
                  <span className="sr-only">Model</span>
                  <select
                    disabled={
                      model.configControlsDisabled || model.changingModel
                    }
                    onChange={(event) =>
                      void model.setActiveConfigOption(
                        activeModelOption.id,
                        event.target.value,
                      )
                    }
                    value={
                      model.pendingConfigValues[activeModelOption.id] ??
                      optionSelectValue(activeModelOption)
                    }
                  >
                    {activeModelValues.map((option) => (
                      <option key={option.value} value={option.value}>
                        {option.name || option.value}
                      </option>
                    ))}
                  </select>
                  <ChevronDown aria-hidden="true" size={12} strokeWidth={1.8} />
                </label>
              ) : (
                <button className="chat-composer__pill" disabled type="button">
                  <span>{modelLabel(model.activeSession.configOptions)}</span>
                </button>
              )
            ),
            mode: (
              <label
                aria-busy={model.changingMode || undefined}
                className="chat-select-pill chat-select-pill--mode"
              >
                <span className="chat-mode-dot" aria-hidden="true" />
                <span className="sr-only">Mode</span>
                <select
                  aria-label="Mode"
                  disabled={model.configControlsDisabled || model.changingMode}
                  onChange={(event) => void model.setActiveMode(event.target.value)}
                  value={activeModeValue}
                >
                  {activeModeOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
                <ChevronDown aria-hidden="true" size={12} strokeWidth={1.8} />
              </label>
            ),
          }}
          disabled={model.loadingSession}
          canCancel={model.canCancel}
          canceling={model.stopping}
          onCancel={() => void model.stopSession()}
          onChange={model.setPromptDraft}
          onSubmit={() => void model.sendPrompt()}
          placeholder="Message…"
          sending={model.sending}
          submitLabel={model.canCancel ? "Stop" : "Send"}
          value={model.promptDraft}
        />
      </div>
    </section>
  );
}
