import { useState } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";
import {
  Link,
  useLocation,
  useNavigate,
} from "react-router-dom";
import type { BoardMetaDetails } from "@/domain/task-shell";
import {
  buildTaskBoardHref,
  parseTaskBoardPath,
  type TaskDetailLocationState,
} from "@/domain/routes";
import { WorktreeGlyph } from "@/features/shared/ui/WorktreeGlyph";
import { useNativeContextMenu } from "@/features/shared/ui/use-native-context-menu";
import { useWorkspaceStore } from "@/state/workspace-store";

export type TaskBoardAncestorModel = {
  id: string;
  title: string;
  meta: BoardMetaDetails;
};

export type TaskBoardCardModel = {
  id: string;
  workspaceId?: string;
  href: string;
  title: string;
  meta: BoardMetaDetails;
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

function TaskBoardMetaRow({
  meta,
  className,
  tone,
  workspaceTestId,
  worktreeIconTestId,
}: {
  meta: BoardMetaDetails;
  className: string;
  tone?: TaskBoardCardModel["tone"];
  workspaceTestId?: string;
  worktreeIconTestId?: string;
}) {
  const classNames = [className];
  if (tone) {
    classNames.push(`task-board-card__meta--${tone}`);
  }

  return (
    <p className={classNames.join(" ")}>
      {meta.isWorktree ? (
        <>
          <span
            className="task-board-card__meta-item task-board-card__meta-item--icon"
            data-testid={worktreeIconTestId}
          >
            <WorktreeGlyph className="task-board-card__worktree-icon" />
          </span>
          <span aria-hidden="true" className="task-board-card__meta-separator">
            ·
          </span>
        </>
      ) : null}
      <span className="task-board-card__meta-item">{meta.stage}</span>
      <span aria-hidden="true" className="task-board-card__meta-separator">
        ·
      </span>
      <span className="task-board-card__meta-item">{meta.updatedAt}</span>
      <span aria-hidden="true" className="task-board-card__meta-separator">
        ·
      </span>
      <span
        className="task-board-card__meta-item task-board-card__meta-item--workspace"
        data-testid={workspaceTestId}
      >
        {meta.workspace}
      </span>
    </p>
  );
}

function TaskBoardCard({ card }: { card: TaskBoardCardModel }) {
  const [lineageExpanded, setLineageExpanded] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();
  const captureTaskSurfaceReturnContext = useWorkspaceStore(
    (state) => state.captureTaskSurfaceReturnContext,
  );
  const boardScope = parseTaskBoardPath(location.pathname) ?? { kind: "all" as const };
  const detailState: TaskDetailLocationState = {
    taskSurfaceReturnContext: {
      path: buildTaskBoardHref(boardScope, location.search),
      workspaceId:
        boardScope.kind === "workspace" ? boardScope.workspaceId : undefined,
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
          <h3 data-testid={`board-card-title-${card.id}`}>{card.title}</h3>
          <TaskBoardMetaRow
            className="task-board-card__meta"
            meta={card.meta}
            tone={card.tone}
            workspaceTestId={`board-card-workspace-meta-${card.id}`}
            worktreeIconTestId={`board-card-worktree-icon-${card.id}`}
          />
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
                  <TaskBoardMetaRow
                    className="task-board-card__ancestor-meta"
                    meta={ancestor.meta}
                  />
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
