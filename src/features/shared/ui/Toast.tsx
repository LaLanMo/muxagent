import { useEffect, useState } from "react";

type ToastTone = "success" | "error";

type ToastProps = {
  message: string;
  tone: ToastTone;
  duration?: number;
  onDismiss: () => void;
};

function ToastIcon({ tone }: { tone: ToastTone }) {
  if (tone === "success") {
    return (
      <svg aria-hidden="true" className="toast__icon toast__icon--success" fill="none" height="16" width="16" viewBox="0 0 24 24" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2">
        <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
        <path d="M22 4 12 14.01l-3-3" />
      </svg>
    );
  }
  return (
    <svg aria-hidden="true" className="toast__icon toast__icon--error" fill="none" height="16" width="16" viewBox="0 0 24 24" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2">
      <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z" />
      <path d="M15 9l-6 6" />
      <path d="M9 9l6 6" />
    </svg>
  );
}

export function Toast({ message, tone, duration = 4000, onDismiss }: ToastProps) {
  const [exiting, setExiting] = useState(false);

  useEffect(() => {
    const timer = setTimeout(() => {
      setExiting(true);
      setTimeout(onDismiss, 200);
    }, duration);
    return () => clearTimeout(timer);
  }, [duration, onDismiss]);

  return (
    <div
      className={`toast toast--${tone}${exiting ? " toast--exiting" : ""}`}
      role="alert"
    >
      <ToastIcon tone={tone} />
      <span className="toast__message">{message}</span>
      <button
        aria-label="Dismiss"
        className="toast__dismiss"
        onClick={() => {
          setExiting(true);
          setTimeout(onDismiss, 200);
        }}
        type="button"
      >
        <svg aria-hidden="true" fill="none" height="14" width="14" viewBox="0 0 24 24" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" strokeWidth="2">
          <path d="M18 6 6 18" />
          <path d="M6 6l12 12" />
        </svg>
      </button>
    </div>
  );
}

type ToastState = {
  message: string;
  tone: ToastTone;
  key: number;
} | null;

export function useToast() {
  const [toast, setToast] = useState<ToastState>(null);

  return {
    toast,
    showToast: (message: string, tone: ToastTone = "error") =>
      setToast({ message, tone, key: Date.now() }),
    dismissToast: () => setToast(null),
  };
}
