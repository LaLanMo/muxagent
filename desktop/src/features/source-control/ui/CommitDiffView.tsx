import { GitCommit } from "lucide-react";
import { useParams } from "react-router-dom";
import { useCommitDiff } from "@/features/source-control/model/use-diff-data";
import { UnifiedDiff } from "@/features/source-control/ui/UnifiedDiff";

const commitDateFormatter = new Intl.DateTimeFormat("en-US", {
  dateStyle: "medium",
  timeStyle: "short",
});

function decode(param: string | undefined): string | undefined {
  if (!param) return undefined;
  try {
    return decodeURIComponent(param);
  } catch {
    return param;
  }
}

function formatAuthoredAt(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return undefined;
  return commitDateFormatter.format(date);
}

function formatFileCount(count: number | undefined): string | undefined {
  if (typeof count !== "number") return undefined;
  return `${count} ${count === 1 ? "file" : "files"}`;
}

export function CommitDiffView() {
  const params = useParams<{
    workspaceId: string;
    checkoutPath: string;
    commitHash: string;
  }>();
  const workspaceId = decode(params.workspaceId);
  const checkoutPath = decode(params.checkoutPath);
  const commitHash = decode(params.commitHash);

  const { loading, data, error } = useCommitDiff(
    workspaceId,
    checkoutPath,
    commitHash,
  );
  const authoredAt = formatAuthoredAt(data?.authored_at);
  const fileCount = formatFileCount(data?.file_count);

  return (
    <section
      className="diff-pane"
      data-testid="source-control-commit-diff"
    >
      <header className="diff-pane__header">
        <span className="diff-pane__header-icon" aria-hidden="true">
          <GitCommit size={16} strokeWidth={1.8} />
        </span>
        <div className="diff-pane__title-group">
          <h1
            className="diff-pane__title"
            data-testid="source-control-commit-diff-title"
          >
            {data?.subject ?? commitHash ?? "Commit"}
          </h1>
          {data ? (
            <p className="diff-pane__meta">
              <span>{data.hash?.slice(0, 10) ?? commitHash}</span>
              {data.author ? <span>{data.author}</span> : null}
              {authoredAt ? <span>{authoredAt}</span> : null}
              {fileCount ? <span>{fileCount}</span> : null}
            </p>
          ) : null}
        </div>
      </header>
      <UnifiedDiff
        diff={data}
        error={error}
        loading={loading}
        placeholder="Select a commit to see its diff."
      />
    </section>
  );
}
