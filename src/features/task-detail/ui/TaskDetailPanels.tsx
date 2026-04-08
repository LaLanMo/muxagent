import { useEffect, useState, type ReactNode } from "react";
import { detailStatusLabel } from "@/domain/task-shell";
import type {
  ArtifactRefDto,
  BlockedStepDto,
  ConfigCatalogEntryDto,
  InputQuestionDto,
  NodeRunViewDto,
  TaskViewDto,
} from "@/rpc/types";

type OverviewPaneProps = {
  task?: TaskViewDto;
  runCount: number;
  artifactCount: number;
};

type RunPaneProps = {
  run?: NodeRunViewDto;
  streamLines: string[];
  streamSource: "live" | "replay" | "loading" | "none";
  isCurrentRun: boolean;
  artifactCount: number;
  showEmptyOutput: boolean;
};

type ArtifactPaneProps = {
  artifact?: ArtifactRefDto;
  content?: string;
  error?: string;
};

type ApprovalDockProps = {
  feedback: string;
  setFeedback: (value: string) => void;
  submittingDecision: boolean;
  submitApprove: () => Promise<void>;
  submitReject: () => Promise<void>;
  nodeName?: string;
};

type ClarificationDockProps = {
  nodeName?: string;
  requestKey?: string;
  questions: InputQuestionDto[];
  answers: Array<string | string[]>;
  setAnswer: (index: number, value: string | string[]) => void;
  submittingClarification: boolean;
  submitClarification: () => Promise<void>;
};

type RetryDockProps = {
  run?: NodeRunViewDto;
  failureReason?: string;
  submittingRetry: boolean;
  onRetry: (force?: boolean) => Promise<void>;
};

type FollowUpDockProps = {
  configEntries: ConfigCatalogEntryDto[];
  followUpConfigAlias: string;
  followUpDescription: string;
  setFollowUpDescription: (value: string) => void;
  onConfigChange: (alias: string) => void;
  submittingFollowUp: boolean;
  onStartFollowUp: () => Promise<void>;
};

type BlockedDockProps = {
  blockedStep?: BlockedStepDto;
  submittingContinue: boolean;
  onContinue: () => Promise<void>;
};

function PanelHeader({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  return (
    <div className="detail-pane__header">
      <div className="detail-pane__titles">
        <h3>{title}</h3>
        <p>{subtitle}</p>
      </div>
    </div>
  );
}

function DetailInfoCard({
  label,
  value,
  detail,
}: {
  label: string;
  value: string | number;
  detail?: string;
}) {
  return (
    <div className="detail-info-card">
      <span className="detail-info-card__label">{label}</span>
      <strong className="detail-info-card__value">{value}</strong>
      {detail ? <p className="detail-info-card__detail">{detail}</p> : null}
    </div>
  );
}

function DetailSection({
  label,
  children,
  className = "",
}: {
  label: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`detail-section${className ? ` ${className}` : ""}`}>
      <span className="detail-section__label">{label}</span>
      {children}
    </section>
  );
}

function DetailSurface({
  label,
  children,
  className = "",
  bodyClassName = "",
  testId,
}: {
  label: string;
  children: ReactNode;
  className?: string;
  bodyClassName?: string;
  testId?: string;
}) {
  return (
    <section
      className={`detail-surface-card${className ? ` ${className}` : ""}`}
      data-testid={testId}
    >
      <div className="detail-surface-card__header">
        <span className="detail-surface-card__label">{label}</span>
      </div>
      <div
        className={`detail-surface-card__body${
          bodyClassName ? ` ${bodyClassName}` : ""
        }`}
      >
        {children}
      </div>
    </section>
  );
}

function renderDocumentLine(line: string, index: number): ReactNode {
  const trimmed = line.trim();
  if (!trimmed) {
    return <div className="detail-document-preview__spacer" key={`spacer-${index}`} />;
  }

  if (trimmed.startsWith("### ")) {
    return (
      <h4
        className="detail-document-preview__heading detail-document-preview__heading--minor"
        key={index}
      >
        {trimmed.slice(4)}
      </h4>
    );
  }

  if (trimmed.startsWith("## ")) {
    return (
      <h3 className="detail-document-preview__heading" key={index}>
        {trimmed.slice(3)}
      </h3>
    );
  }

  if (trimmed.startsWith("# ")) {
    return (
      <h2 className="detail-document-preview__title" key={index}>
        {trimmed.slice(2)}
      </h2>
    );
  }

  if (trimmed.startsWith("- ")) {
    return (
      <div className="detail-document-preview__bullet" key={index}>
        <span className="detail-document-preview__bullet-mark">•</span>
        <span>{trimmed.slice(2)}</span>
      </div>
    );
  }

  return (
    <p className="detail-document-preview__paragraph" key={index}>
      {line}
    </p>
  );
}

function DocumentPreview({ content }: { content: string }) {
  return (
    <article className="detail-document-preview">
      {content.split("\n").map((line, index) => renderDocumentLine(line, index))}
    </article>
  );
}

function formatRunSubtitle(run: NodeRunViewDto) {
  const started = run.started_at ? run.started_at.slice(11, 16) : undefined;
  const completed = run.completed_at ? run.completed_at.slice(11, 16) : undefined;
  const status = detailStatusLabel(run.status);
  const pieces: string[] = [status];
  if (started) {
    pieces.push(`started ${started}`);
  }
  if (completed) {
    pieces.push(`${status.includes("await") ? "paused" : "ended"} ${completed}`);
  }
  return pieces.join(" · ");
}

function prettyResult(result: Record<string, unknown> | undefined) {
  if (!result || Object.keys(result).length === 0) {
    return undefined;
  }
  return JSON.stringify(result, null, 2);
}

function formatClarificationAnswer(selected: unknown): string {
  if (Array.isArray(selected)) {
    return selected.join(", ");
  }
  return typeof selected === "string" ? selected : "";
}

function RecoveryCard({
  tone,
  title,
  description,
  actions,
  testId,
}: {
  tone: "failed" | "blocked";
  title: string;
  description: string;
  actions: ReactNode;
  testId: string;
}) {
  return (
    <section
      className={`detail-recovery-card detail-recovery-card--${tone}`}
      data-testid={testId}
    >
      <div className="detail-recovery-card__copy">
        <strong className="detail-recovery-card__title">{title}</strong>
        <p className="detail-recovery-card__description">{description}</p>
      </div>
      <div className="detail-recovery-card__actions">{actions}</div>
    </section>
  );
}

export function TaskOverviewPane({
  task,
  runCount,
  artifactCount,
}: OverviewPaneProps) {
  return (
    <div className="detail-pane" data-testid="overview-pane">
      <PanelHeader
        subtitle="Task summary and task-level actions"
        title={task?.task.description || "Task"}
      />

      <div className="detail-info-cards">
        <DetailInfoCard
          detail={task?.current_node_name || "No active node"}
          label="Status"
          value={task ? detailStatusLabel(task.status) : "Unknown"}
        />
        <DetailInfoCard
          detail="Across task history"
          label="Runs"
          value={runCount}
        />
        <DetailInfoCard
          detail="Files and previews attached to the task"
          label="Artifacts"
          value={artifactCount}
        />
      </div>

      {task?.current_issue ? (
        <section className="detail-note-card detail-note-card--warning">
          <span className="detail-section__label">Current issue</span>
          <strong>{task.current_issue.reason}</strong>
          <p>
            {task.current_issue.node_name} · iteration {task.current_issue.iteration}
          </p>
        </section>
      ) : null}
    </div>
  );
}

export function TaskRunPane({
  run,
  streamLines,
  streamSource,
  isCurrentRun,
  artifactCount,
  showEmptyOutput,
}: RunPaneProps) {
  if (!run) {
    return (
      <div className="detail-pane" data-testid="run-pane">
        <PanelHeader
          subtitle="Select a run from the navigator to inspect its detail."
          title="Run detail"
        />
        <div className="detail-empty-card">
          <strong>No run selected</strong>
          <p>Choose a run from the navigator to inspect its history, outputs, and artifacts.</p>
        </div>
      </div>
    );
  }

  const liveTitle = `Run · ${run.node_name}`;
  const resultContent = prettyResult(run.result);
  const clarificationHistory = run.clarifications ?? [];
  const hasStreamOutput = streamLines.length > 0;

  return (
    <div
      className="detail-pane detail-pane--run"
      data-testid={streamSource === "live" ? "live-pane" : "run-pane"}
    >
      <PanelHeader subtitle={formatRunSubtitle(run)} title={liveTitle} />

      <div className="detail-info-cards">
        <DetailInfoCard label="Node" value={run.node_name} />
        <DetailInfoCard label="Status" value={detailStatusLabel(run.status)} />
        <DetailInfoCard label="Artifacts" value={artifactCount} />
        {run.triggered_by ? (
          <DetailInfoCard label="Triggered by" value={run.triggered_by.reason} />
        ) : null}
      </div>

      {clarificationHistory.length > 0 ? (
        <DetailSection label="Clarifications">
          <div className="detail-list-card">
            {clarificationHistory.map((exchange, index) => {
              const request = (exchange.request ?? {}) as {
                questions?: Array<{ question?: string }>;
              };
              const response = (exchange.response ?? {}) as {
                answers?: Array<{ selected?: unknown }>;
              };
              return (
                <div className="detail-list-card__row" key={`${run.id}-clarification-${index}`}>
                  <strong>
                    {request.questions?.[0]?.question ?? `Clarification ${index + 1}`}
                  </strong>
                  <p>
                    {response.answers?.length
                      ? response.answers
                          .map((answer) => formatClarificationAnswer(answer.selected))
                          .filter(Boolean)
                          .join(" · ")
                      : "Awaiting response"}
                  </p>
                </div>
              );
            })}
          </div>
        </DetailSection>
      ) : null}

      {hasStreamOutput || resultContent || showEmptyOutput ? (
        <DetailSurface
          bodyClassName="detail-output-card"
          label="Output"
          testId="detail-output-surface"
        >
          {hasStreamOutput ? (
            <pre className="detail-code-block">{streamLines.join("\n")}</pre>
          ) : resultContent ? (
            <pre className="detail-code-block">{resultContent}</pre>
          ) : streamSource === "loading" ? (
            <div className="detail-empty-card detail-empty-card--embedded">
              <strong>Loading run history…</strong>
              <p>Fetching persisted session events for this node run.</p>
            </div>
          ) : isCurrentRun ? (
            <div className="detail-empty-card detail-empty-card--embedded">
              <strong>Waiting for live output…</strong>
              <p>
                {run.session_id
                  ? `Live stream events for session ${run.session_id} will appear here when the executor emits them.`
                  : "This run is active. Stream events will appear here when the executor emits them."}
              </p>
            </div>
          ) : (
            <div className="detail-empty-card detail-empty-card--embedded">
              <strong>No persisted stream for this run</strong>
              <p>Use the navigator artifacts or current action surface to inspect what happened in this step.</p>
            </div>
          )}
        </DetailSurface>
      ) : null}
    </div>
  );
}

export function TaskArtifactPane({
  artifact,
  content,
  error,
}: ArtifactPaneProps) {
  return (
    <div className="detail-pane" data-testid="artifact-pane">
      <PanelHeader
        subtitle={artifact?.node_name ?? "Artifact preview"}
        title={artifact?.preview_name ? `Preview · ${artifact.preview_name}` : "Preview"}
      />

      {error ? <p className="screen-error">{error}</p> : null}

      <DetailSurface
        bodyClassName="detail-output-card detail-output-card--artifact"
        label="Preview"
        testId="detail-preview-surface"
      >
        {artifact?.markdown && content ? (
          <DocumentPreview content={content} />
        ) : (
          <pre className="detail-document">{content ?? "Loading artifact..."}</pre>
        )}
      </DetailSurface>
    </div>
  );
}

export function TaskApprovalDock({
  feedback,
  setFeedback,
  submittingDecision,
  submitApprove,
  submitReject,
  nodeName,
}: ApprovalDockProps) {
  return (
    <section className="detail-surface-panel" data-testid="approval-pane">
      <div className="detail-surface-panel__header">
        <span className="detail-surface-panel__title">
          {nodeName ? `${nodeName} needs approval` : "Approval required"}
        </span>
      </div>
      <div className="detail-surface-panel__body">
        <label className="field-block">
          <span className="field-block__hint">Feedback (optional)</span>
          <textarea
            className="approval-feedback approval-feedback--compact"
            onChange={(event) => setFeedback(event.target.value)}
            placeholder="Add feedback…"
            rows={2}
            value={feedback}
          />
        </label>

        <div className="detail-surface-panel__footer">
          <button
            className="secondary-action secondary-action--danger"
            data-testid="approval-reject"
            disabled={submittingDecision}
            onClick={() => void submitReject()}
            type="button"
          >
            Reject
          </button>
          <button
            className="primary-action"
            data-testid="approval-approve"
            disabled={submittingDecision}
            onClick={() => void submitApprove()}
            type="button"
          >
            Approve
          </button>
        </div>
      </div>
    </section>
  );
}

function ClarificationQuestionField({
  question,
  index,
  answer,
  setAnswer,
  labelId,
  descriptionId,
}: {
  question: InputQuestionDto;
  index: number;
  answer: string | string[];
  setAnswer: (index: number, value: string | string[]) => void;
  labelId: string;
  descriptionId?: string;
}) {
  const options = question.options ?? [];
  const isMultiSelect = question.multi_select;

  if (options.length === 0) {
    return (
      <textarea
        aria-describedby={descriptionId}
        aria-labelledby={labelId}
        className="approval-feedback approval-feedback--compact"
        onChange={(event) => setAnswer(index, event.target.value)}
        placeholder="Answer this clarification…"
        rows={3}
        value={typeof answer === "string" ? answer : answer.join(", ")}
      />
    );
  }

  const isOther = !isMultiSelect
    ? typeof answer === "string" && !options.some((o) => o.label === answer) && answer !== ""
    : false;
  const [otherText, setOtherText] = useState(isOther ? (answer as string) : "");
  const otherSelected = isOther || (!isMultiSelect && answer === `__other__:${otherText}`);

  return (
    <div className={`detail-choice-list${isMultiSelect ? " detail-choice-list--multi" : ""}`}>
      {options.map((option) => {
        const checked = Array.isArray(answer)
          ? answer.includes(option.label)
          : answer === option.label;
        return (
          <label className={`detail-choice${checked ? " is-selected" : ""}`} key={option.label}>
            <input
              checked={checked}
              className="detail-choice__input"
              name={`clarification-${index}`}
              onChange={(event) => {
                if (isMultiSelect) {
                  const current = Array.isArray(answer) ? answer : [];
                  const next = event.target.checked
                    ? [...new Set([...current, option.label])]
                    : current.filter((entry) => entry !== option.label);
                  setAnswer(index, next);
                } else {
                  setAnswer(index, option.label);
                }
              }}
              type={isMultiSelect ? "checkbox" : "radio"}
            />
            <span className="detail-choice__control" aria-hidden="true" />
            <span className="detail-choice__copy">
              <strong>{option.label}</strong>
              {option.description ? <small>{option.description}</small> : null}
            </span>
          </label>
        );
      })}
      <label className={`detail-choice detail-choice--other${otherSelected ? " is-selected" : ""}`}>
        <input
          checked={otherSelected}
          className="detail-choice__input"
          name={`clarification-${index}`}
          onChange={() => {
            if (isMultiSelect) {
              const current = Array.isArray(answer) ? answer : [];
              if (!otherText) return;
              if (!current.includes(otherText)) {
                setAnswer(index, [...current, otherText]);
              }
            } else {
              setAnswer(index, otherText || "");
            }
          }}
          type={isMultiSelect ? "checkbox" : "radio"}
        />
        <span className="detail-choice__control" aria-hidden="true" />
        <span className="detail-choice__copy detail-choice__copy--other">
          <strong>Other:</strong>
          <input
            className="detail-choice__other-input"
            onChange={(event) => {
              setOtherText(event.target.value);
              if (isMultiSelect) {
                const current = Array.isArray(answer) ? answer : [];
                const withoutOld = current.filter((v) => v !== otherText);
                if (event.target.value) {
                  setAnswer(index, [...withoutOld, event.target.value]);
                } else {
                  setAnswer(index, withoutOld);
                }
              } else {
                setAnswer(index, event.target.value);
              }
            }}
            onFocus={() => {
              if (!isMultiSelect) {
                setAnswer(index, otherText || "");
              }
            }}
            placeholder="Type your own answer..."
            type="text"
            value={otherText}
          />
        </span>
      </label>
    </div>
  );
}

export function TaskClarificationDock({
  nodeName,
  requestKey,
  questions,
  answers,
  setAnswer,
  submittingClarification,
  submitClarification,
}: ClarificationDockProps) {
  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
    setActiveIndex(0);
  }, [requestKey]);

  useEffect(() => {
    setActiveIndex((current) =>
      Math.min(current, Math.max(questions.length - 1, 0)),
    );
  }, [questions.length]);

  const activeQuestion = questions[activeIndex];
  const activeAnswer = answers[activeIndex] ?? (activeQuestion?.multi_select ? [] : "");
  const questionId = `clarification-question-${requestKey ?? "task"}-${activeIndex}`;
  const descriptionId = activeQuestion?.why_it_matters
    ? `clarification-why-${requestKey ?? "task"}-${activeIndex}`
    : undefined;

  return (
    <section className="detail-surface-panel" data-testid="clarification-pane">
      <div className="detail-surface-panel__header detail-surface-panel__header--attention">
        <span className="detail-surface-panel__title">
          <svg
            aria-hidden="true"
            className="detail-surface-panel__title-icon"
            fill="none"
            height="14"
            viewBox="0 0 14 14"
            width="14"
          >
            <path
              d="M4.667 10.5 2.333 11.667V3.5a1.167 1.167 0 0 1 1.167-1.167h7a1.167 1.167 0 0 1 1.167 1.167v5.833A1.167 1.167 0 0 1 10.5 10.5H4.667Z"
              stroke="currentColor"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="1.1"
            />
          </svg>
          {nodeName ? `${nodeName} needs clarification` : "Clarification needed"}
        </span>
        {questions.length > 1 ? (
          <div className="detail-clarification__nav">
            <button
              aria-label="Previous clarification"
              className="detail-clarification__nav-button"
              disabled={activeIndex === 0}
              onClick={() => setActiveIndex((current) => Math.max(current - 1, 0))}
              type="button"
            >
              <svg aria-hidden="true" fill="none" height="14" viewBox="0 0 14 14" width="14">
                <path
                  d="M8.75 3.5 5.25 7l3.5 3.5"
                  stroke="currentColor"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="1.2"
                />
              </svg>
            </button>
            <span className="detail-clarification__nav-count">
              {activeIndex + 1} / {questions.length}
            </span>
            <button
              aria-label="Next clarification"
              className="detail-clarification__nav-button"
              disabled={activeIndex === questions.length - 1}
              onClick={() =>
                setActiveIndex((current) => Math.min(current + 1, questions.length - 1))
              }
              type="button"
            >
              <svg aria-hidden="true" fill="none" height="14" viewBox="0 0 14 14" width="14">
                <path
                  d="M5.25 3.5 8.75 7l-3.5 3.5"
                  stroke="currentColor"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth="1.2"
                />
              </svg>
            </button>
          </div>
        ) : null}
      </div>

      <div className="detail-surface-panel__body">
        {activeQuestion ? (
          <div className="detail-clarification__question">
            <div className="detail-clarification__copy">
              <strong id={questionId}>{activeQuestion.question}</strong>
              {activeQuestion.why_it_matters ? (
                <p id={descriptionId}>{activeQuestion.why_it_matters}</p>
              ) : null}
            </div>
            <ClarificationQuestionField
              answer={activeAnswer}
              index={activeIndex}
              descriptionId={descriptionId}
              labelId={questionId}
              question={activeQuestion}
              setAnswer={setAnswer}
            />
          </div>
        ) : (
          <p className="muted-copy">No clarification questions were provided.</p>
        )}

        <div className="detail-surface-panel__footer">
          <button
            className="primary-action"
            disabled={submittingClarification}
            onClick={() => void submitClarification()}
            type="button"
          >
            {submittingClarification ? "Sending…" : "Submit"}
          </button>
        </div>
      </div>
    </section>
  );
}

export function TaskRetryDock({
  run,
  failureReason,
  submittingRetry,
  onRetry,
}: RetryDockProps) {
  return (
    <RecoveryCard
      actions={
        <button
          className="primary-action"
          data-testid="retry-step"
          disabled={submittingRetry || !run}
          onClick={() => void onRetry(false)}
          type="button"
        >
          {submittingRetry ? "Retrying…" : "Retry"}
        </button>
      }
      description={failureReason ?? "The current task requires intervention."}
      testId="failed-pane"
      title={run?.node_name ? `Task failed at ${run.node_name} node` : "Task failed"}
      tone="failed"
    />
  );
}

export function TaskFollowUpDock({
  configEntries,
  followUpConfigAlias,
  followUpDescription,
  setFollowUpDescription,
  onConfigChange,
  submittingFollowUp,
  onStartFollowUp,
}: FollowUpDockProps) {
  const launchable = configEntries.filter((e) => e.launchable);
  const selectedDescription = launchable.find((e) => e.alias === followUpConfigAlias)?.description;

  return (
    <section className="detail-surface-panel" data-testid="complete-pane">
      <div className="detail-surface-panel__header">
        <span className="detail-surface-panel__title">Follow-up task</span>
      </div>
      <div className="detail-surface-panel__body">
        {launchable.length > 1 ? (
          <div className="follow-up-config">
            <div className="follow-up-config__pills">
              {launchable.map((entry) => (
                <button
                  className={`follow-up-config__pill${entry.alias === followUpConfigAlias ? " is-selected" : ""}`}
                  key={entry.alias}
                  onClick={() => onConfigChange(entry.alias)}
                  type="button"
                >
                  {entry.alias}
                </button>
              ))}
            </div>
            {selectedDescription ? (
              <span className="follow-up-config__desc">{selectedDescription}</span>
            ) : null}
          </div>
        ) : null}
        <label className="field-block">
          <span className="field-block__label">Describe the follow-up</span>
          <textarea
            aria-label="Describe the follow-up"
            className="approval-feedback approval-feedback--compact"
            data-testid="follow-up-description"
            onChange={(event) => setFollowUpDescription(event.target.value)}
            placeholder="Continue from here..."
            rows={3}
            value={followUpDescription}
          />
        </label>
        <div className="detail-surface-panel__footer">
          <button
            className="primary-action"
            data-testid="start-follow-up"
            disabled={submittingFollowUp || !followUpDescription.trim()}
            onClick={() => void onStartFollowUp()}
            type="button"
          >
            {submittingFollowUp ? "Starting…" : "Start follow-up"}
          </button>
        </div>
      </div>
    </section>
  );
}

export function TaskBlockedDock({
  blockedStep,
  submittingContinue,
  onContinue,
}: BlockedDockProps) {
  return (
    <RecoveryCard
      actions={
        <button
          className="primary-action"
          data-testid="continue-blocked"
          disabled={submittingContinue}
          onClick={() => void onContinue()}
          type="button"
        >
          {submittingContinue ? "Continuing…" : "Continue"}
        </button>
      }
      description={blockedStep?.reason ?? "The current task is waiting to continue."}
      testId="blocked-pane"
      title={
        blockedStep?.node_name
          ? `Task paused at ${blockedStep.node_name}`
          : "Task is waiting to continue"
      }
      tone="blocked"
    />
  );
}
