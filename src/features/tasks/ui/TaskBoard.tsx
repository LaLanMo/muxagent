import { Link } from "react-router-dom";
export type TaskBoardCardModel = {
  id: string;
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

function TaskBoardColumn({ column }: { column: TaskBoardColumnModel }) {
  return (
    <section className="board-column">
      <header className="board-column__header">
        <span className="board-column__label">{column.label}</span>
        <span className="board-column__count">{column.cards.length}</span>
      </header>
      <div className="board-column__stack">
        {column.cards.map((card) => (
          <Link
            className="task-board-card"
            data-testid={`board-card-${card.id}`}
            key={card.id}
            to={card.href}
          >
            <span
              className={`task-board-card__rail task-board-card__rail--${card.tone}`}
              aria-hidden="true"
            />
            <div className="task-board-card__body">
              <div className="task-board-card__header">
                <h3>{card.title}</h3>
                <span
                  className={`task-board-card__stamp task-board-card__stamp--${card.tone}`}
                >
                  {card.time}
                </span>
              </div>
              <p className="task-board-card__meta">{card.meta}</p>
            </div>
          </Link>
        ))}
      </div>
    </section>
  );
}

export function TaskBoard({ columns }: TaskBoardProps) {
  return (
    <div className="board-grid">
      {columns.map((column) => (
        <TaskBoardColumn column={column} key={column.key} />
      ))}
    </div>
  );
}
