import { getCurrentWindow } from "@tauri-apps/api/window";
import type { MouseEvent as ReactMouseEvent } from "react";

const DRAG_EXCLUSION_SELECTOR = [
  "a",
  "button",
  "input",
  "select",
  "textarea",
  "summary",
  "[role='button']",
  "[role='link']",
  "[role='checkbox']",
  "[role='radio']",
  "[role='switch']",
  "[role='textbox']",
  "[role='combobox']",
  "[contenteditable='true']",
  "[data-no-window-drag]",
].join(", ");

function shouldIgnoreDragTarget(target: EventTarget | null) {
  return target instanceof Element && target.closest(DRAG_EXCLUSION_SELECTOR);
}

export async function startWindowDrag(event: ReactMouseEvent<HTMLElement>) {
  if (event.button !== 0) {
    return;
  }
  if (
    typeof window === "undefined" ||
    !window.__TAURI_INTERNALS__ ||
    !document.body.classList.contains("platform-tauri-macos")
  ) {
    return;
  }
  if (shouldIgnoreDragTarget(event.target)) {
    return;
  }
  event.preventDefault();
  await getCurrentWindow().startDragging();
}
