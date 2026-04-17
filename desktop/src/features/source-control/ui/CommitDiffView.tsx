import { GitCommit } from "lucide-react";
import { useParams } from "react-router-dom";
import { useCommitDiff } from "@/features/source-control/model/use-diff-data";
import { UnifiedDiff } from "@/features/source-control/ui/UnifiedDiff";

function decode(param: string | undefined): string | undefined {
  if (!param) return undefined;
  try {
    return decodeURIComponent(param);
  } catch {
    return param;
  }
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

  return (
    <section
      className="diff-pane"
      data-testid="source-control-commit-diff"
    >
      <header className="diff-pane__header">
        <GitCommit size={16} strokeWidth={1.8} />
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
              {data.author ? <span>· {data.author}</span> : null}
              {data.authored_at ? <span>· {data.authored_at}</span> : null}
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
