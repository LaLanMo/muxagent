type StatusBadgeTone = "running" | "awaiting" | "done" | "failed" | "neutral";

type StatusBadgeProps = {
  tone: StatusBadgeTone;
  label: string;
  mono?: boolean;
};

const dotTones = new Set<StatusBadgeTone>(["running", "awaiting", "done", "failed"]);

export function StatusBadge({ tone, label, mono = false }: StatusBadgeProps) {
  return (
    <span
      className={`status-badge status-badge--${tone}${mono ? " status-badge--mono" : ""}`}
    >
      {dotTones.has(tone) && <span className="status-badge__dot" aria-hidden="true" />}
      {label}
    </span>
  );
}
