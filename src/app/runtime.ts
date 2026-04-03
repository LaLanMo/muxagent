import type { DesktopRuntime } from "@/platform/contract";
import { browserRuntime } from "@/platform/browser/runtime";
import { createTauriRuntime } from "@/platform/tauri/runtime";

declare global {
  interface Window {
    __TAURI_INTERNALS__?: unknown;
  }
}

function detectRuntime(): DesktopRuntime {
  if (typeof window !== "undefined" && window.__TAURI_INTERNALS__) {
    return createTauriRuntime();
  }
  return browserRuntime;
}

let runtime: DesktopRuntime = detectRuntime();

export function getRuntime(): DesktopRuntime {
  return runtime;
}

export function setRuntime(nextRuntime: DesktopRuntime): void {
  runtime = nextRuntime;
}
