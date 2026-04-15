import {
  Folder,
  History,
  Inbox,
  LayoutGrid,
  ListTodo,
  Play,
  Rows3,
  ServerCog,
  Settings,
  SlidersHorizontal,
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
  tasks: ListTodo,
  active: Play,
  history: History,
  list: Rows3,
  board: LayoutGrid,
  machines: ServerCog,
  configs: SlidersHorizontal,
  settings: Settings,
  workspace: Folder,
};

export function ShellIcon({ name }: ShellIconProps) {
  const Icon: LucideIcon = iconMap[name];
  return (
    <Icon
      aria-hidden="true"
      className="shell-icon"
      size={14}
      strokeWidth={1.75}
    />
  );
}
