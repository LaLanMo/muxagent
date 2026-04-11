import React from "react";
import ReactDOM from "react-dom/client";
import { App } from "@/app/App";
import "@/styles/index.css";

if (typeof window !== "undefined" && window.__TAURI_INTERNALS__) {
  if (/Mac/i.test(window.navigator.userAgent)) {
    document.body.classList.add("platform-tauri-macos");
  }
  window.addEventListener(
    "contextmenu",
    (event) => {
      event.preventDefault();
    },
    { capture: true },
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
