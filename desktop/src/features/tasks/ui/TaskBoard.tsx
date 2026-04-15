import { useState } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import {
  Link,
  useLocation,
  useNavigate,
} from "react-router-dom";
import type { TaskDetailLocationState } from "@/domain/routes";
import { useNativeContextMenu } from "@/features/shared/ui/use-native-context-menu";
import { useWorkspaceStore } from "@/state/workspace-store";

export type TaskBoardAncestorModel = {
  id: string;
  title: string;
  meta: string;
};

export type TaskBoardCardModel = {
  id: string;
  workspaceId?: string;
  href: string;
  title: string;
  meta: string;
  tone: "running" | "awaiting" | "done" | "failed" | "neutral";
  ancestorCount: number;
  ancestors: TaskBoardAncestorModel[];
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

function TaskBoardCard({ card }: { card: TaskBoardCardModel }) {
  const [lineageExpanded, setLineageExpanded] = useState(false);
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
  const contextMenu = useNativeContextMenu<HTMLElement>({
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
  const hasAncestors = card.ancestorCount > 0;
  const lineageId = `board-card-lineage-${card.id}`;

  return (
    <article
      ref={contextMenu.ref}
      className={`task-board-card${
        hasAttentionAccent(card.tone) ? ` task-board-card--${card.tone}` : ""
      }`}
      data-testid={`board-card-${card.id}`}
      onContextMenu={contextMenu.onContextMenu}
    >
      <Link
        className="task-board-card__link"
        data-testid={`board-card-link-${card.id}`}
        onClick={() => {
          if (detailState.taskSurfaceReturnContext) {
            captureTaskSurfaceReturnContext(detailState.taskSurfaceReturnContext);
          }
        }}
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
      {hasAncestors ? (
        <>
          <button
            aria-controls={lineageId}
            aria-expanded={lineageExpanded}
            className="task-board-card__lineage-toggle"
            data-testid={`board-card-lineage-toggle-${card.id}`}
            onClick={() => {
              setLineageExpanded((expanded) => !expanded);
            }}
            type="button"
          >
            {lineageExpanded ? (
              <ChevronDown aria-hidden="true" size={12} strokeWidth={1.75} />
            ) : (
              <ChevronRight aria-hidden="true" size={12} strokeWidth={1.75} />
            )}
            <span>{lineageExpanded ? "PREVIOUSLY" : `${card.ancestorCount} PREVIOUS`}</span>
          </button>
          {lineageExpanded ? (
            <div
              className="task-board-card__lineage"
              data-testid={`board-card-lineage-${card.id}`}
              id={lineageId}
            >
              {card.ancestors.map((ancestor) => (
                <div
                  className="task-board-card__ancestor"
                  data-testid={`board-card-ancestor-${card.id}-${ancestor.id}`}
                  key={ancestor.id}
                >
                  <p className="task-board-card__ancestor-title">{ancestor.title}</p>
                  <p className="task-board-card__ancestor-meta">{ancestor.meta}</p>
                </div>
              ))}
            </div>
          ) : null}
        </>
      ) : null}
    </article>
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
          <TaskBoardCard
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
