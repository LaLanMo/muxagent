import { Link } from "react-router-dom";
export type TaskBoardCardModel = {
  id: string;
  workspaceId?: string;
  href: string;
  title: string;
  meta: string;
  time: string;
  tone: "running" | "awaiting" | "done" | "failed" | "neutral";
};

export type TaskBoardColumnModel = {
  key: string;
  label: string;
  cards: TaskBoardCardModel[];
};

type TaskBoardProps = {
  columns: TaskBoardColumnModel[];
};

function hasAttentionAccent(tone: TaskBoardCardModel["tone"]) {
  return tone === "awaiting" || tone === "failed";
}

function TaskBoardColumn({ column }: { column: TaskBoardColumnModel }) {
  return (
    <section className="board-column">
      <header className="board-column__header">
        <span className="board-column__heading">
          <span
            aria-hidden="true"
            className={`board-column__dot board-column__dot--${column.key}`}
          />
          <span className="board-column__label">{column.label}</span>
          <span className="board-column__count">{column.cards.length}</span>
        </span>
      </header>
      <div className="board-column__stack">
        {column.cards.map((card) => (
          <Link
            className={`task-board-card${
              hasAttentionAccent(card.tone) ? ` task-board-card--${card.tone}` : ""
            }`}
            data-testid={`board-card-${card.id}`}
            key={`${card.workspaceId ?? "global"}:${card.id}`}
            to={card.href}
          >
            <div className="task-board-card__body">
              <div className="task-board-card__header">
                <h3>{card.title}</h3>
              </div>
              <div className="task-board-card__footer">
                <p className="task-board-card__meta">{card.meta}</p>
                <span
                  className={`task-board-card__stamp task-board-card__stamp--${card.tone}`}
                >
                  {card.time}
                </span>
              </div>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}

export function TaskBoard({ columns }: TaskBoardProps) {
  return (
    <div className="board-surface" data-testid="task-board">
      <div className="board-grid">
        {columns.map((column) => (
          <TaskBoardColumn column={column} key={column.key} />
        ))}
      </div>
    </div>
  );
}
