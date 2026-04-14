import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { useEffect, useRef } from "react";
import type { MouseEvent as ReactMouseEvent, RefObject } from "react";

type NativeMenuAction = {
  id: string;
  label: string;
  onSelect: () => void | Promise<void>;
};

type NativeContextMenuOptions = {
  actions: NativeMenuAction[];
};

type NativeContextMenuBinding<T extends HTMLElement> = {
  ref: RefObject<T | null>;
  onContextMenu: (event: ReactMouseEvent<T>) => void;
};

type NativeContextMenuActionEvent = {
  itemId: string;
};

const nativeContextActionEvent = "native-context-menu-action";
const callbacks = new Map<string, () => void | Promise<void>>();
let actionListenerReady: Promise<boolean> | null = null;

function isTauriRuntime() {
  return typeof window !== "undefined" && !!window.__TAURI_INTERNALS__;
}

async function ensureActionListener() {
  if (!isTauriRuntime()) {
    return false;
  }

  if (!actionListenerReady) {
    actionListenerReady = listen<NativeContextMenuActionEvent>(
      nativeContextActionEvent,
      (event) => {
        const itemId = event.payload?.itemId;
        if (!itemId) {
          return;
        }

        const callback = callbacks.get(itemId);
        callbacks.delete(itemId);
        if (callback) {
          void callback();
        }
      },
    )
      .then(() => true)
      .catch((error) => {
        console.error("Failed to register native context-menu listener", error);
        actionListenerReady = null;
        return false;
      });
  }

  return actionListenerReady;
}

export function useNativeContextMenu<T extends HTMLElement>({
  actions,
}: NativeContextMenuOptions): NativeContextMenuBinding<T> {
  const ref = useRef<T | null>(null);
  const actionsRef = useRef(actions);
  actionsRef.current = actions;

  useEffect(() => {
    return () => {
      for (const action of actionsRef.current) {
        callbacks.delete(action.id);
      }
    };
  }, []);

  return {
    ref,
    onContextMenu: (event) => {
      if (!isTauriRuntime()) {
        return;
      }

      event.preventDefault();
      event.stopPropagation();

      void (async () => {
        const ready = await ensureActionListener();
        if (!ready) {
          return;
        }

        const items = actionsRef.current.map((action) => {
          callbacks.set(action.id, action.onSelect);
          return {
            id: action.id,
            label: action.label,
          };
        });

        try {
          await invoke("show_context_menu", {
            x: event.clientX,
            y: event.clientY,
            items,
          });
        } catch (error) {
          for (const action of actionsRef.current) {
            callbacks.delete(action.id);
          }
          console.error("Failed to show native context menu", error);
        }
      })();
    },
  };
}
