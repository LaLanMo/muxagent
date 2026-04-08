export type NavStatus = "running" | "done" | "failed" | "awaiting" | "pending";

const statusPaths: Record<NavStatus, string[]> = {
  // Lucide: loader (8 radiating segments)
  running: [
    "M12 2v4",
    "M12 18v4",
    "M4.93 4.93l2.83 2.83",
    "M16.24 16.24l2.83 2.83",
    "M2 12h4",
    "M18 12h4",
    "M4.93 19.07l2.83-2.83",
    "M16.24 7.76l2.83-2.83",
  ],
  // Lucide: check (plain checkmark)
  done: ["M20 6 9 17l-5-5"],
  // Lucide: x-circle
  failed: [
    "M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10Z",
    "M15 9l-6 6",
    "M9 9l6 6",
  ],
  // Lucide: message-circle
  awaiting: ["M7.9 20A9 9 0 1 0 4 16.1L2 22Z"],
  // Lucide: circle-dashed
  pending: [
    "M10.1 2.18a10 10 0 0 1 3.8 0",
    "M17.6 3.71a10 10 0 0 1 2.69 2.7",
    "M21.82 10.1a10 10 0 0 1 0 3.8",
    "M20.29 17.6a10 10 0 0 1-2.7 2.69",
    "M13.9 21.82a10 10 0 0 1-3.8 0",
    "M6.4 20.29a10 10 0 0 1-2.69-2.7",
    "M2.18 13.9a10 10 0 0 1 0-3.8",
    "M3.71 6.4a10 10 0 0 1 2.7-2.69",
  ],
};

export function StatusIcon({ status }: { status: NavStatus }) {
  return (
    <svg
      aria-hidden="true"
      className="detail-nav-row__status-icon"
      fill="none"
      height="12"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="2"
      viewBox="0 0 24 24"
      width="12"
    >
      {statusPaths[status].map((d) => (
        <path d={d} key={d} />
      ))}
    </svg>
  );
}

export function FileIcon() {
  return (
    <svg
      aria-hidden="true"
      className="detail-nav-artifact__icon"
      fill="none"
      height="11"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="2"
      viewBox="0 0 24 24"
      width="11"
    >
      <path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z" />
      <path d="M14 2v4a2 2 0 0 0 2 2h4" />
      <path d="M10 13h4" />
      <path d="M10 17h4" />
    </svg>
  );
}
