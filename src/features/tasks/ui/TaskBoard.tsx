import {
  Link,
  useLocation,
  useNavigate,
} from "react-router-dom";
import type { TaskDetailLocationState } from "@/domain/routes";
import { useNativeContextMenu } from "@/features/shared/ui/use-native-context-menu";
import { useWorkspaceStore } from "@/state/workspace-store";
export type TaskBoardCardModel = {
  id: string;
  workspaceId?: string;
  href: string;
  title: string;
  meta: string;
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

function TaskBoardCardLink({ card }: { card: TaskBoardCardModel }) {
  const location = useLocation();
  const navigate = useNavigate();
  const selectedWorkspaceId = useWorkspaceStore(
    (state) => state.selectedWorkspaceId,
  );
  const captureTaskSurfaceReturnContext = useWorkspaceStore(
    (state) => state.captureTaskSurfaceReturnContext,
  );
  const detailState: TaskDetailLocationState = {
    taskSurfaceReturnContext: {
      path: location.search ? `${location.pathname}${location.search}` : location.pathname,
      workspaceId: selectedWorkspaceId,
    },
  };
  const contextMenu = useNativeContextMenu<HTMLAnchorElement>({
    actions: [
      {
        id: `open-task:${card.workspaceId ?? "global"}:${card.id}`,
        label: "Open Task",
        onSelect: () => {
          if (detailState.taskSurfaceReturnContext) {
            captureTaskSurfaceReturnContext(detailState.taskSurfaceReturnContext);
          }
          navigate(card.href, { state: detailState });
        },
      },
    ],
  });

  return (
    <Link
      ref={contextMenu.ref}
      className={`task-board-card${
        hasAttentionAccent(card.tone) ? ` task-board-card--${card.tone}` : ""
      }`}
      data-testid={`board-card-${card.id}`}
      onClick={() => {
        if (detailState.taskSurfaceReturnContext) {
          captureTaskSurfaceReturnContext(detailState.taskSurfaceReturnContext);
        }
      }}
      onContextMenu={contextMenu.onContextMenu}
      state={detailState}
      to={card.href}
    >
      <div className="task-board-card__body">
        <h3>{card.title}</h3>
        <p className={`task-board-card__meta task-board-card__meta--${card.tone}`}>
          {card.meta}
        </p>
      </div>
    </Link>
  );
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
          <TaskBoardCardLink
            card={card}
            key={`${card.workspaceId ?? "global"}:${card.id}`}
          />
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
