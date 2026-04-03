type StatusBadgeTone = "running" | "awaiting" | "done" | "failed" | "neutral";

type StatusBadgeProps = {
  tone: StatusBadgeTone;
  label: string;
  mono?: boolean;
};

export function StatusBadge({ tone, label, mono = false }: StatusBadgeProps) {
  return (
    <span
      className={`status-badge status-badge--${tone}${mono ? " status-badge--mono" : ""}`}
    >
      {label}
    </span>
  );
}
