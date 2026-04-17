import { GitBranch } from "lucide-react";

export function SourceControlLanding() {
  return (
    <section className="worktree-overview" data-testid="source-control-landing">
      <div className="worktree-overview__empty">
        <GitBranch size={28} strokeWidth={1.6} />
        <h1>Pick a worktree</h1>
        <p>Select a worktree from the panel to see its branch, changes, and commits.</p>
      </div>
    </section>
  );
}
