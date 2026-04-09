import { useEffect, useState } from "react";
import { CircleCheckBig, CircleX, X } from "lucide-react";

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
      <CircleCheckBig
        aria-hidden="true"
        className="toast__icon toast__icon--success"
        size={16}
        strokeWidth={2}
      />
    );
  }
  return (
    <CircleX
      aria-hidden="true"
      className="toast__icon toast__icon--error"
      size={16}
      strokeWidth={2}
    />
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
        <X aria-hidden="true" size={14} strokeWidth={2} />
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
