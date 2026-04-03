import type { ReactNode } from "react";
import type { ArtifactRefDto, BlockedStepDto, NodeRunViewDto } from "@/rpc/types";

type ApprovalPaneProps = {
  feedback: string;
  setFeedback: (value: string) => void;
  submittingDecision: boolean;
  submitApprove: () => Promise<void>;
  submitReject: () => Promise<void>;
  inputRequest?: {
    node_name: string;
  };
};

type ArtifactPaneProps = {
  artifact?: ArtifactRefDto;
  content?: string;
  error?: string;
  onBack: () => void;
};

type LivePaneProps = {
  title: string;
  lines: string[];
};

type FailedPaneProps = {
  latestFailure?: NodeRunViewDto;
  failureReason?: string;
  submittingRetry: boolean;
  onRetry: (force?: boolean) => Promise<void>;
};

type CompletePaneProps = {
  configLabel: string;
  followUpDescription: string;
  setFollowUpDescription: (value: string) => void;
  submittingFollowUp: boolean;
  onStartFollowUp: () => Promise<void>;
};

type BlockedPaneProps = {
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
      <h4 className="detail-document-preview__heading detail-document-preview__heading--minor" key={index}>
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

export function TaskApprovalPane({
  feedback,
  setFeedback,
  submittingDecision,
  submitApprove,
  submitReject,
  inputRequest,
}: ApprovalPaneProps) {
  return (
    <div className="detail-pane" data-testid="approval-pane">
      <PanelHeader subtitle="execute command" title="Bash" />
      <div className="approval-command">
        <span className="approval-command__label">Proposed command</span>
        <pre className="detail-command-line">
{`cd /workspace && muxagent exec ${inputRequest?.node_name ?? "current-node"}`}
        </pre>
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
          className="approval-feedback"
          onChange={(event) => setFeedback(event.target.value)}
          placeholder="Add feedback…"
          rows={3}
          value={feedback}
        />
      </label>
    </div>
  );
}

export function TaskArtifactPane({
  artifact,
  content,
  error,
  onBack,
}: ArtifactPaneProps) {
  return (
    <div className="detail-pane" data-testid="artifact-pane">
      <PanelHeader
        action={
          <button className="text-action" onClick={onBack} type="button">
            Back to live
          </button>
        }
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

export function TaskLivePane({ title, lines }: LivePaneProps) {
  return (
    <div className="detail-pane detail-pane--live" data-testid="live-pane">
      <PanelHeader subtitle="Live runtime output" title={title} />
      <div className="live-output-surface">
        <pre className="detail-code-block">
          {lines.length > 0
            ? lines.join("\n")
            : "$ Waiting for runtime output...\n$ Live progress will stream here once the node emits events."}
        </pre>
      </div>
    </div>
  );
}

export function TaskFailedPane({
  latestFailure,
  failureReason,
  submittingRetry,
  onRetry,
}: FailedPaneProps) {
  return (
    <div className="detail-pane detail-pane--failed" data-testid="failed-pane">
      <div className="detail-state-head detail-state-head--failed">
        <span className="detail-state-head__icon">×</span>
        <span>Task failed</span>
      </div>
      <div className="failure-panel">
        <div className="failure-panel__summary">
          <strong>{failureReason ?? "The current task requires intervention."}</strong>
          <p>
            {latestFailure?.completed_at
              ? `Completed at ${latestFailure.completed_at.slice(11, 16)}`
              : "Review the latest node failure before retrying."}
          </p>
        </div>
        <div className="failure-panel__divider" />
        <div className="detail-pane__section">
          <span className="field-block__label">Recovery</span>
          <div className="failure-panel__actions">
            <button
              className="primary-action"
              data-testid="retry-step"
              disabled={submittingRetry || !latestFailure}
              onClick={() => void onRetry(false)}
              type="button"
            >
              Retry step
            </button>
            <button
              className="secondary-action"
              data-testid="force-retry-step"
              disabled={submittingRetry || !latestFailure}
              onClick={() => void onRetry(true)}
              type="button"
            >
              Force retry
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function TaskCompletePane({
  configLabel,
  followUpDescription,
  setFollowUpDescription,
  submittingFollowUp,
  onStartFollowUp,
}: CompletePaneProps) {
  return (
    <div className="detail-pane detail-pane--complete" data-testid="complete-pane">
      <div className="detail-state-head detail-state-head--done">
        <span className="detail-state-head__icon">✓</span>
        <span>Task completed</span>
      </div>
      <div className="complete-panel">
        <div className="complete-panel__summary">
          <strong>Complete</strong>
          <p>Create a linked task that carries over context from this run.</p>
        </div>
        <div className="complete-panel__divider" />
        <div className="detail-pane__section">
          <span className="field-block__label">Follow up</span>
          <div className="complete-panel__composer">
            <textarea
              className="approval-feedback approval-feedback--compact"
              data-testid="follow-up-description"
              onChange={(event) => setFollowUpDescription(event.target.value)}
              placeholder="Continue from here..."
              rows={3}
              value={followUpDescription}
            />
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
        </div>
      </div>
    </div>
  );
}

export function TaskBlockedPane({
  blockedStep,
  submittingContinue,
  onContinue,
}: BlockedPaneProps) {
  return (
    <div className="detail-pane" data-testid="blocked-pane">
      <div className="blocked-callout">
        <div className="blocked-callout__eyebrow">Task blocked</div>
        <strong>{blockedStep?.reason ?? "The current task is waiting to continue."}</strong>
        <p>
          {blockedStep?.node_name
            ? `Continue from ${blockedStep.node_name}.`
            : "Resume the blocked task from its current node."}
        </p>
      </div>
      <div className="detail-pane__section">
        <span className="field-block__label">Recovery</span>
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
    </div>
  );
}
