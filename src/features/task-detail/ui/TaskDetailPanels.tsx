import type { ReactNode } from "react";
import type {
  ArtifactRefDto,
  BlockedStepDto,
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
  liveLines: string[];
  isCurrentRun: boolean;
  artifactCount: number;
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
  configLabel: string;
  followUpDescription: string;
  setFollowUpDescription: (value: string) => void;
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
  action,
}: {
  title: string;
  subtitle: string;
  action?: ReactNode;
}) {
  return (
    <div className="detail-pane__header">
      <div className="detail-pane__titles">
        <h3>{title}</h3>
        <p>{subtitle}</p>
      </div>
      {action}
    </div>
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
  const pieces = [run.status.toLowerCase()];
  if (started) {
    pieces.push(`started ${started}`);
  }
  if (completed) {
    pieces.push(`ended ${completed}`);
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

export function TaskOverviewPane({
  task,
  runCount,
  artifactCount,
}: OverviewPaneProps) {
  return (
    <div className="detail-pane" data-testid="overview-pane">
      <PanelHeader
        subtitle="Overview"
        title={task?.task.description || "Task"}
      />
      <div className="detail-overview-grid">
        <div className="detail-overview-card">
          <span className="field-block__label">Status</span>
          <strong>{task?.status ?? "Unknown"}</strong>
          <p>Current node: {task?.current_node_name || "None"}</p>
        </div>
        <div className="detail-overview-card">
          <span className="field-block__label">Runs</span>
          <strong>{runCount}</strong>
          <p>Recorded node runs for this task.</p>
        </div>
        <div className="detail-overview-card">
          <span className="field-block__label">Artifacts</span>
          <strong>{artifactCount}</strong>
          <p>Outputs produced across the recorded runs.</p>
        </div>
      </div>
      {task?.current_issue ? (
        <div className="detail-callout detail-callout--issue">
          <div className="detail-callout__eyebrow">Current issue</div>
          <strong>{task.current_issue.reason}</strong>
          <p>
            {task.current_issue.node_name} · iteration {task.current_issue.iteration}
          </p>
        </div>
      ) : null}
    </div>
  );
}

export function TaskRunPane({
  run,
  liveLines,
  isCurrentRun,
  artifactCount,
}: RunPaneProps) {
  if (!run) {
    return (
      <div className="detail-pane" data-testid="run-pane">
        <PanelHeader
          subtitle="Run detail"
          title="Select a run"
        />
        <div className="live-output-empty">
          <strong>No run selected</strong>
          <p>Choose a run from the navigator to inspect its history, outputs, and artifacts.</p>
        </div>
      </div>
    );
  }

  const liveTitle = `Run · ${run.node_name}`;
  const resultContent = prettyResult(run.result);
  const clarificationHistory = run.clarifications ?? [];
  const hasLiveOutput = isCurrentRun && liveLines.length > 0;

  return (
    <div
      className="detail-pane detail-pane--run"
      data-testid={hasLiveOutput ? "live-pane" : "run-pane"}
    >
      <PanelHeader subtitle={formatRunSubtitle(run)} title={liveTitle} />

      <div className="detail-record-list">
        <div className="detail-record-row">
          <span className="field-block__label">Node</span>
          <span>{run.node_name}</span>
        </div>
        <div className="detail-record-row">
          <span className="field-block__label">Status</span>
          <span>{run.status}</span>
        </div>
        <div className="detail-record-row">
          <span className="field-block__label">Artifacts</span>
          <span>{artifactCount}</span>
        </div>
        {run.triggered_by ? (
          <div className="detail-record-row">
            <span className="field-block__label">Triggered by</span>
            <span>{run.triggered_by.reason}</span>
          </div>
        ) : null}
      </div>

      {run.failure_reason ? (
        <div className="detail-callout detail-callout--issue">
          <div className="detail-callout__eyebrow">Failure reason</div>
          <strong>{run.failure_reason}</strong>
        </div>
      ) : null}

      {clarificationHistory.length > 0 ? (
        <div className="detail-pane__section">
          <span className="field-block__label">Clarification history</span>
          <div className="clarification-history">
            {clarificationHistory.map((exchange, index) => {
              const request = (exchange.request ?? {}) as {
                questions?: Array<{ question?: string }>;
              };
              const response = (exchange.response ?? {}) as {
                answers?: Array<{ selected?: unknown }>;
              };
              return (
                <div className="clarification-history__item" key={`${run.id}-clarification-${index}`}>
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
        </div>
      ) : null}

      {hasLiveOutput ? (
        <div className="live-output-surface">
          <pre className="detail-code-block">{liveLines.join("\n")}</pre>
        </div>
      ) : resultContent ? (
        <pre className="detail-code-block">{resultContent}</pre>
      ) : (
        <div className="live-output-empty">
          <strong>No persisted stream for this run</strong>
          <p>Use the navigator artifacts or current action surface to inspect what happened in this step.</p>
        </div>
      )}
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
        subtitle={artifact?.source_label ?? "artifact"}
        title={artifact?.preview_name ? `Preview · ${artifact.preview_name}` : "Preview"}
      />
      {error ? <p className="screen-error">{error}</p> : null}
      {artifact?.markdown && content ? (
        <DocumentPreview content={content} />
      ) : (
        <pre className="detail-document">{content ?? "Loading artifact..."}</pre>
      )}
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
    <div className="detail-action-card" data-testid="approval-pane">
      <div className="detail-action-card__meta">
        <span>{nodeName ? `${nodeName} needs approval` : "Approval required"}</span>
      </div>
      <div className="approval-actions">
        <button
          className="primary-action"
          data-testid="approval-approve"
          disabled={submittingDecision}
          onClick={() => void submitApprove()}
          type="button"
        >
          Approve
        </button>
        <button
          className="secondary-action secondary-action--danger"
          data-testid="approval-reject"
          disabled={submittingDecision}
          onClick={() => void submitReject()}
          type="button"
        >
          Reject
        </button>
      </div>
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
    </div>
  );
}

function ClarificationQuestionField({
  question,
  index,
  answer,
  setAnswer,
}: {
  question: InputQuestionDto;
  index: number;
  answer: string | string[];
  setAnswer: (index: number, value: string | string[]) => void;
}) {
  const options = question.options ?? [];
  const isMultiSelect = question.multi_select;

  return (
    <div className="clarification-question">
      <div className="clarification-question__copy">
        <strong>{question.question}</strong>
        {question.why_it_matters ? <p>{question.why_it_matters}</p> : null}
      </div>
      {options.length > 0 ? (
        <div className="clarification-question__options">
          {options.map((option) => {
            const checked = Array.isArray(answer)
              ? answer.includes(option.label)
              : answer === option.label;
            return (
              <label className="clarification-option" key={option.label}>
                <input
                  checked={checked}
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
                <span>
                  <strong>{option.label}</strong>
                  {option.description ? <small>{option.description}</small> : null}
                </span>
              </label>
            );
          })}
        </div>
      ) : (
        <textarea
          className="approval-feedback approval-feedback--compact"
          onChange={(event) => setAnswer(index, event.target.value)}
          placeholder="Answer this clarification…"
          rows={2}
          value={typeof answer === "string" ? answer : answer.join(", ")}
        />
      )}
    </div>
  );
}

export function TaskClarificationDock({
  nodeName,
  questions,
  answers,
  setAnswer,
  submittingClarification,
  submitClarification,
}: ClarificationDockProps) {
  return (
    <div className="detail-action-card" data-testid="clarification-pane">
      <div className="detail-action-card__meta">
        <span>
          {nodeName ? `${nodeName} needs clarification` : "Clarification required"}
        </span>
      </div>
      <div className="clarification-form">
        {questions.map((question, index) => (
          <ClarificationQuestionField
            answer={answers[index] ?? (question.multi_select ? [] : "")}
            index={index}
            key={`${question.question}-${index}`}
            question={question}
            setAnswer={setAnswer}
          />
        ))}
      </div>
      <div className="approval-actions">
        <button
          className="primary-action"
          disabled={submittingClarification}
          onClick={() => void submitClarification()}
          type="button"
        >
          {submittingClarification ? "Sending…" : "Send response"}
        </button>
      </div>
    </div>
  );
}

export function TaskRetryDock({
  run,
  failureReason,
  submittingRetry,
  onRetry,
}: RetryDockProps) {
  return (
    <div className="detail-action-card" data-testid="failed-pane">
      <div className="detail-action-card__meta">
        <span>{run?.node_name ? `Retry ${run.node_name}` : "Retry this run"}</span>
      </div>
      <div className="failure-panel__summary">
        <strong>{failureReason ?? "The current task requires intervention."}</strong>
      </div>
      <div className="failure-panel__actions">
        <button
          className="primary-action"
          data-testid="retry-step"
          disabled={submittingRetry || !run}
          onClick={() => void onRetry(false)}
          type="button"
        >
          Retry step
        </button>
        <button
          className="secondary-action"
          data-testid="force-retry-step"
          disabled={submittingRetry || !run}
          onClick={() => void onRetry(true)}
          type="button"
        >
          Force retry
        </button>
      </div>
    </div>
  );
}

export function TaskFollowUpDock({
  configLabel,
  followUpDescription,
  setFollowUpDescription,
  submittingFollowUp,
  onStartFollowUp,
}: FollowUpDockProps) {
  return (
    <div className="detail-action-card" data-testid="complete-pane">
      <div className="detail-action-card__meta">
        <span>Follow-up task</span>
      </div>
      <label className="field-block">
        <textarea
          className="approval-feedback approval-feedback--compact"
          data-testid="follow-up-description"
          onChange={(event) => setFollowUpDescription(event.target.value)}
          placeholder="Continue from here..."
          rows={2}
          value={followUpDescription}
        />
      </label>
      <div className="complete-panel__footer">
        <span className="status-badge status-badge--neutral status-badge--mono">
          {configLabel}
        </span>
        <button
          className="primary-action"
          data-testid="start-follow-up"
          disabled={submittingFollowUp || !followUpDescription.trim()}
          onClick={() => void onStartFollowUp()}
          type="button"
        >
          {submittingFollowUp ? "Starting…" : "Start"}
        </button>
      </div>
    </div>
  );
}

export function TaskBlockedDock({
  blockedStep,
  submittingContinue,
  onContinue,
}: BlockedDockProps) {
  return (
    <div className="detail-action-card" data-testid="blocked-pane">
      <div className="detail-action-card__meta">
        <span>
          {blockedStep?.node_name
            ? `Continue ${blockedStep.node_name}`
            : "Continue task"}
        </span>
      </div>
      <div className="blocked-callout">
        <strong>{blockedStep?.reason ?? "The current task is waiting to continue."}</strong>
      </div>
      <div className="failure-panel__actions">
        <button
          className="primary-action"
          data-testid="continue-blocked"
          disabled={submittingContinue}
          onClick={() => void onContinue()}
          type="button"
        >
          {submittingContinue ? "Continuing…" : "Continue"}
        </button>
      </div>
    </div>
  );
}
