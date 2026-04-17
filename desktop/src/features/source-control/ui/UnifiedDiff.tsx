import type { GitDiffDto } from "@/rpc/types";

type UnifiedDiffProps = {
  diff?: GitDiffDto;
  loading?: boolean;
  error?: string;
  placeholder?: string;
};

type Line = {
  kind: "meta" | "hunk" | "add" | "del" | "ctx";
  text: string;
  oldNo?: number;
  newNo?: number;
};

function parsePatch(patch: string): Line[] {
  const lines: Line[] = [];
  const raw = patch.split("\n");
  let oldNo = 0;
  let newNo = 0;
  let inHunk = false;

  for (const rawLine of raw) {
    if (rawLine.startsWith("diff --git") || rawLine.startsWith("index ") || rawLine.startsWith("--- ") || rawLine.startsWith("+++ ") || rawLine.startsWith("new file") || rawLine.startsWith("deleted file") || rawLine.startsWith("rename ") || rawLine.startsWith("similarity") || rawLine.startsWith("Binary files")) {
      lines.push({ kind: "meta", text: rawLine });
      continue;
    }
    if (rawLine.startsWith("@@")) {
      inHunk = true;
      const match = /@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(rawLine);
      if (match) {
        oldNo = Number(match[1]);
        newNo = Number(match[2]);
      }
      lines.push({ kind: "hunk", text: rawLine });
      continue;
    }
    if (!inHunk) {
      if (rawLine) lines.push({ kind: "meta", text: rawLine });
      continue;
    }
    if (rawLine.startsWith("+")) {
      lines.push({ kind: "add", text: rawLine.slice(1), newNo });
      newNo += 1;
    } else if (rawLine.startsWith("-")) {
      lines.push({ kind: "del", text: rawLine.slice(1), oldNo });
      oldNo += 1;
    } else if (rawLine.startsWith("\\")) {
      lines.push({ kind: "meta", text: rawLine });
    } else {
      const text = rawLine.startsWith(" ") ? rawLine.slice(1) : rawLine;
      lines.push({ kind: "ctx", text, oldNo, newNo });
      oldNo += 1;
      newNo += 1;
    }
  }
  return lines;
}

export function UnifiedDiff({ diff, loading, error, placeholder }: UnifiedDiffProps) {
  if (loading) {
    return (
      <div className="diff-view diff-view--loading" data-testid="unified-diff">
        Loading diff…
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

  const parsed = parsePatch(diff.patch);

  return (
    <div className="diff-view" data-testid="unified-diff">
      {diff.truncated ? (
        <div className="diff-view__banner">Diff truncated</div>
      ) : null}
      <pre className="diff-view__body">
        {parsed.map((line, idx) => (
          <span
            className={`diff-view__line diff-view__line--${line.kind}`}
            key={`${idx}-${line.kind}`}
          >
            <span className="diff-view__gutter">
              {line.kind === "add"
                ? "+"
                : line.kind === "del"
                  ? "-"
                  : line.kind === "hunk"
                    ? "@"
                    : line.kind === "meta"
                      ? ""
                      : " "}
            </span>
            <span className="diff-view__text">{line.text}</span>
          </span>
        ))}
      </pre>
    </div>
  );
}
