import { Link } from "react-router-dom";
import type { BoardBucket, TaskListRow } from "@/domain/task-shell";

export type TaskListRowModel = TaskListRow & {
  href: string;
  workspaceId?: string;
};

type TaskListProps = {
  rows: TaskListRowModel[];
};

function bucketLabel(bucket: BoardBucket) {
  switch (bucket) {
    case "running":
      return "Running";
    case "awaiting":
      return "Needs attention";
    case "done":
      return "Completed";
    case "failed":
      return "Failed";
    default:
      return bucket;
  }
}

export function TaskList({ rows }: TaskListProps) {
  const groupedRows = (["running", "awaiting", "done", "failed"] as const)
    .map((bucket) => ({
      bucket,
      label: bucketLabel(bucket),
      rows: rows.filter((row) => row.bucket === bucket),
    }))
    .filter((group) => group.rows.length > 0);

  return (
    <div className="task-list" data-testid="task-list">
      {groupedRows.map((group) => (
        <section className="task-list-section" key={group.bucket}>
          <header className="task-list-section__header">
            <span className="task-list-section__label">{group.label}</span>
            <span className="task-list-section__count">{group.rows.length}</span>
          </header>
          <div className="task-list-section__rows">
            {group.rows.map((row) => (
              <Link
                className="task-list-row"
                data-testid={`list-row-${row.id}`}
                key={`${row.workspaceId ?? "global"}:${row.id}`}
                to={row.href}
              >
                <span className={`task-list-row__rail task-list-row__rail--${row.tone}`} />
                <div className="task-list-row__body">
                  <div className="task-list-row__heading">
                    <h3>{row.title}</h3>
                    <span className="task-list-row__time">{row.time}</span>
                  </div>
                  <div className="task-list-row__meta">
                    <span className={`task-list-row__status task-list-row__status--${row.tone}`}>
                      {bucketLabel(row.bucket)}
                    </span>
                    <span className="task-list-row__divider">•</span>
                    <span className="task-list-row__subtitle">{row.subtitle}</span>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
