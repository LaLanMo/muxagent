import {
  Folder,
  History,
  Inbox,
  LayoutGrid,
  ListChecks,
  Play,
  Rows3,
  ServerCog,
  Settings,
  Workflow,
  type LucideIcon,
} from "lucide-react";

export type ShellIconName =
  | "inbox"
  | "tasks"
  | "active"
  | "history"
  | "list"
  | "board"
  | "machines"
  | "configs"
  | "settings"
  | "workspace";

type ShellIconProps = {
  name: ShellIconName;
};

const iconMap: Record<ShellIconName, LucideIcon> = {
  inbox: Inbox,
  tasks: ListChecks,
  active: Play,
  history: History,
  list: Rows3,
  board: LayoutGrid,
  machines: ServerCog,
  configs: Workflow,
  settings: Settings,
  workspace: Folder,
};

const glyphMap: Partial<Record<ShellIconName, string>> = {
  tasks: "◫",
  configs: "⌘",
  settings: "◔",
};

export function ShellIcon({ name }: ShellIconProps) {
  const glyph = glyphMap[name];
  if (glyph) {
    return (
      <span aria-hidden="true" className="shell-icon shell-icon--glyph">
        {glyph}
      </span>
    );
  }

  const Icon: LucideIcon = iconMap[name];
  const size = name === "workspace" ? 13 : 14;
  const strokeWidth = name === "workspace" ? 1.5 : 1.75;

  return (
    <Icon
      aria-hidden="true"
      className="shell-icon"
      size={size}
      strokeWidth={strokeWidth}
    />
  );
}
