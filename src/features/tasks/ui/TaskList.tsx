import { Link } from "react-router-dom";
import type { BoardBucket, TaskListRow } from "@/domain/task-shell";

export type TaskListRowModel = TaskListRow & {
  href: string;
  workspaceId?: string;
};

type TaskListProps = {
  rows: TaskListRowModel[];
};

type ListBucket = "attention" | "running" | "completed";

const bucketConfig: Record<ListBucket, { label: string; dot: string }> = {
  attention: { label: "Needs Attention", dot: "attention" },
  running: { label: "Running", dot: "running" },
  completed: { label: "Completed", dot: "completed" },
};

function toListBucket(bucket: BoardBucket): ListBucket {
  if (bucket === "awaiting" || bucket === "failed") return "attention";
  if (bucket === "done") return "completed";
  return "running";
}

function needsAccent(tone: string): boolean {
  return tone === "awaiting" || tone === "failed";
}

export function TaskList({ rows }: TaskListProps) {
  const groups = (["attention", "running", "completed"] as const)
    .map((key) => ({
      key,
      ...bucketConfig[key],
      rows: rows.filter((row) => toListBucket(row.bucket) === key),
    }))
    .filter((group) => group.rows.length > 0);

  return (
    <div className="task-list" data-testid="task-list">
      {groups.map((group) => (
        <section className="task-list-section" key={group.key}>
          <header className="task-list-section__header">
            <span
              className={`task-list-section__dot task-list-section__dot--${group.dot}`}
              aria-hidden="true"
            />
            <span className="task-list-section__label">{group.label}</span>
            <span className="task-list-section__count">{group.rows.length}</span>
          </header>
          <div className="task-list-section__rows">
            {group.rows.map((row) => (
              <Link
                className={`task-list-row${needsAccent(row.tone) ? ` task-list-row--${row.tone}` : ""}`}
                data-testid={`list-row-${row.id}`}
                key={`${row.workspaceId ?? "global"}:${row.id}`}
                to={row.href}
              >
                <p className="task-list-row__title">{row.title}</p>
                <p className="task-list-row__path">{row.subtitle}</p>
              </Link>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
