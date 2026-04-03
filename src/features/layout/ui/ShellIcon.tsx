export type ShellIconName =
  | "inbox"
  | "tasks"
  | "active"
  | "history"
  | "machines"
  | "configs"
  | "settings";

type ShellIconProps = {
  name: ShellIconName;
};

const iconPaths: Record<ShellIconName, string[]> = {
  inbox: [
    "M3.75 5.25h8.5l1.5 3v4h-11v-4l1-3Z",
    "M5.5 8.75h2.25c.2.68.75 1.1 1.5 1.1.75 0 1.3-.42 1.5-1.1H13",
  ],
  tasks: [
    "M4 4.75h8",
    "M4 7.75h8",
    "M4 10.75h6",
    "M2.75 4.75h.5",
    "M2.75 7.75h.5",
    "M2.75 10.75h.5",
  ],
  active: [
    "M7.5 2.75v9.5",
    "M3.5 6.75 7.5 2.75l4 4",
  ],
  history: [
    "M7.5 3.25a4.25 4.25 0 1 1-3.75 2.25",
    "M3.75 3.75v2.5h2.5",
    "M7.5 5.5v2.5l1.5 1",
  ],
  machines: [
    "M2.75 4.5h10.5v5.5H2.75Z",
    "M5.5 12h5",
  ],
  configs: [
    "M4.5 3.5h5l2 2v5.5h-7Z",
    "M9.5 3.5v2h2",
  ],
  settings: [
    "M7.5 3.25v1.5",
    "M7.5 10.75v1.5",
    "M3.25 7.5h1.5",
    "M10.75 7.5h1.5",
    "M4.65 4.65l1.05 1.05",
    "M9.3 9.3l1.05 1.05",
    "M10.35 4.65 9.3 5.7",
    "M5.7 9.3 4.65 10.35",
    "M9 7.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Z",
  ],
};

export function ShellIcon({ name }: ShellIconProps) {
  return (
    <svg
      aria-hidden="true"
      className="shell-icon"
      fill="none"
      height="14"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="1.2"
      viewBox="0 0 15 15"
      width="14"
    >
      {iconPaths[name].map((path) => (
        <path d={path} key={path} />
      ))}
    </svg>
  );
}
