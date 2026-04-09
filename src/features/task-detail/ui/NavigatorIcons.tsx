import {
  CircleCheck,
  CircleDashed,
  CircleX,
  FileText,
  Loader,
  MessageCircle,
  type LucideIcon,
} from "lucide-react";

export type NavStatus = "running" | "done" | "failed" | "awaiting" | "pending";

const statusIcons: Record<NavStatus, LucideIcon> = {
  running: Loader,
  done: CircleCheck,
  failed: CircleX,
  awaiting: MessageCircle,
  pending: CircleDashed,
};

export function StatusIcon({ status }: { status: NavStatus }) {
  const Icon = statusIcons[status];

  return (
    <Icon
      aria-hidden="true"
      className="detail-nav-row__status-icon"
      size={12}
      strokeWidth={2}
    />
  );
}

export function FileIcon() {
  return (
    <FileText
      aria-hidden="true"
      className="detail-nav-artifact__icon"
      size={11}
      strokeWidth={2}
    />
  );
}
