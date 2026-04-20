import { GitBranch } from "lucide-react";

export function SourceControlLanding() {
  return (
    <section className="worktree-overview" data-testid="source-control-landing">
      <div className="worktree-overview__empty">
        <GitBranch size={28} strokeWidth={1.6} />
        <h1>Pick a diff target</h1>
        <p>Expand a worktree in the panel to inspect its tasks, changes, and commits.</p>
      </div>
    </section>
  );
}
