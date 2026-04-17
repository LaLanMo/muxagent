import { FileDiff as FileDiffIcon } from "lucide-react";
import { useParams } from "react-router-dom";
import { useFileDiff } from "@/features/source-control/model/use-diff-data";
import { UnifiedDiff } from "@/features/source-control/ui/UnifiedDiff";

function decode(param: string | undefined): string | undefined {
  if (!param) return undefined;
  try {
    return decodeURIComponent(param);
  } catch {
    return param;
  }
}

export function FileDiffView() {
  const params = useParams<{
    workspaceId: string;
    checkoutPath: string;
    fileId: string;
  }>();
  const workspaceId = decode(params.workspaceId);
  const checkoutPath = decode(params.checkoutPath);
  const fileId = decode(params.fileId);

  const { loading, data, error } = useFileDiff(
    workspaceId,
    checkoutPath,
    fileId,
  );

  const filePath = fileId ? fileId.split(":").slice(1).join(":") || fileId : "";

  return (
    <section
      className="diff-pane"
      data-testid="source-control-file-diff"
    >
      <header className="diff-pane__header">
        <FileDiffIcon size={16} strokeWidth={1.8} />
        <h1 className="diff-pane__title" data-testid="source-control-file-diff-title">
          {filePath || "File diff"}
        </h1>
      </header>
      <UnifiedDiff
        diff={data}
        error={error}
        loading={loading}
        placeholder="Select a changed file to see its diff."
      />
    </section>
  );
}
