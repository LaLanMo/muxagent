import { useMemo, useState } from "react";
import {
  Decoration,
  Diff,
  Hunk,
  parseDiff,
  type DiffType,
  type FileData,
  type HunkData,
  type ViewType,
} from "react-diff-view";
import type { GitDiffDto } from "@/rpc/types";

type UnifiedDiffProps = {
  diff?: GitDiffDto;
  loading?: boolean;
  error?: string;
  placeholder?: string;
};

const viewModes: ViewType[] = ["split", "unified"];

const diffTypeLabels: Record<DiffType, string> = {
  add: "Added",
  copy: "Copied",
  delete: "Deleted",
  modify: "Modified",
  rename: "Renamed",
};

function defaultViewType(): ViewType {
  if (
    typeof window !== "undefined" &&
    window.matchMedia("(max-width: 860px)").matches
  ) {
    return "unified";
  }
  return "split";
}

function cleanPatchForParser(patch: string): string {
  const trimmed = patch.trimEnd();
  const firstFile = trimmed.indexOf("diff --git ");
  return firstFile > 0 ? trimmed.slice(firstFile) : trimmed;
}

function parsePatch(patch: string): { files: FileData[]; error?: string } {
  try {
    return {
      files: parseDiff(cleanPatchForParser(patch), { nearbySequences: "zip" }),
    };
  } catch {
    return { files: [], error: "Unable to parse this diff." };
  }
}

function renderHunks(hunks: HunkData[]) {
  return hunks.flatMap((hunk) => {
    const key = `${hunk.oldStart}-${hunk.newStart}-${hunk.content}`;
    return [
      <Decoration key={`decoration-${key}`}>{hunk.content}</Decoration>,
      <Hunk hunk={hunk} key={`hunk-${key}`} />,
    ];
  });
}

function fileTitle(file: FileData): string {
  if (file.type === "rename" && file.oldPath !== file.newPath) {
    return `${file.oldPath} -> ${file.newPath}`;
  }
  return file.newPath || file.oldPath || "Unknown file";
}

function revisionLabel(file: FileData): string | undefined {
  if (!file.oldRevision || !file.newRevision) return undefined;
  return `${file.oldRevision.slice(0, 7)} -> ${file.newRevision.slice(0, 7)}`;
}

function formatFileCount(count: number): string {
  return `${count} ${count === 1 ? "file" : "files"}`;
}

export function UnifiedDiff({ diff, loading, error, placeholder }: UnifiedDiffProps) {
  const [viewType, setViewType] = useState<ViewType>(() => defaultViewType());
  const parsed = useMemo(
    () => (diff?.patch ? parsePatch(diff.patch) : { files: [] }),
    [diff?.patch],
  );

  if (loading) {
    return (
      <div className="diff-view diff-view--loading" data-testid="unified-diff">
        Loading diff...
      </div>
    );
  }
  if (error) {
    return (
      <div
        className="diff-view diff-view--error"
        data-testid="unified-diff-error"
      >
        {error}
      </div>
    );
  }
  if (!diff) {
    return (
      <div className="diff-view diff-view--empty" data-testid="unified-diff-empty">
        {placeholder ?? "No diff to display."}
      </div>
    );
  }
  if (!diff.reachable) {
    return (
      <div className="diff-view diff-view--error" data-testid="unified-diff-error">
        {diff.unreachable_reason ?? "Diff is unreachable."}
      </div>
    );
  }
  if (diff.binary) {
    return (
      <div className="diff-view diff-view--empty" data-testid="unified-diff-binary">
        Binary files differ.
      </div>
    );
  }
  if (!diff.patch) {
    return (
      <div className="diff-view diff-view--empty" data-testid="unified-diff-empty">
        No textual diff available.
      </div>
    );
  }
  if (parsed.error) {
    return (
      <div className="diff-view diff-view--error" data-testid="unified-diff-error">
        {parsed.error}
      </div>
    );
  }
  if (parsed.files.length === 0) {
    return (
      <div className="diff-view diff-view--empty" data-testid="unified-diff-empty">
        No textual diff available.
      </div>
    );
  }

  return (
    <div className="diff-view" data-testid="unified-diff">
      {diff.truncated ? (
        <div className="diff-view__banner">Diff truncated at the preview limit.</div>
      ) : null}
      <div className="diff-view__toolbar">
        <span>{formatFileCount(diff.file_count ?? parsed.files.length)}</span>
        <div
          aria-label="Diff view mode"
          className="diff-view__mode-toggle"
          role="group"
        >
          {viewModes.map((mode) => (
            <button
              aria-pressed={viewType === mode}
              className={`diff-view__mode-button${
                viewType === mode ? " is-active" : ""
              }`}
              key={mode}
              onClick={() => setViewType(mode)}
              type="button"
            >
              {mode === "split" ? "Split" : "Unified"}
            </button>
          ))}
        </div>
      </div>
      <div className="diff-view__files">
        {parsed.files.map((file, index) => {
          const revisions = revisionLabel(file);
          return (
            <section
              className="diff-view__file"
              data-testid="unified-diff-file"
              key={`${file.oldPath}-${file.newPath}-${index}`}
            >
              <header className="diff-view__file-header">
                <span
                  className={`diff-view__file-status diff-view__file-status--${file.type}`}
                >
                  {diffTypeLabels[file.type]}
                </span>
                <span className="diff-view__file-path">{fileTitle(file)}</span>
                {revisions ? (
                  <span className="diff-view__file-revisions">{revisions}</span>
                ) : null}
              </header>
              {file.isBinary ? (
                <div className="diff-view__file-empty">Binary file changed.</div>
              ) : file.hunks.length > 0 ? (
                <div className="diff-view__file-body">
                  <Diff
                    className="diff-view__table"
                    diffType={file.type}
                    gutterType="default"
                    hunks={file.hunks}
                    optimizeSelection={viewType === "split"}
                    viewType={viewType}
                  >
                    {renderHunks}
                  </Diff>
                </div>
              ) : (
                <div className="diff-view__file-empty">
                  No textual changes in this file.
                </div>
              )}
            </section>
          );
        })}
      </div>
    </div>
  );
}
