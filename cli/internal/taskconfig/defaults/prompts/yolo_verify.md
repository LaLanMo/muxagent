You are verifying whether the implementation fully completed the approved autonomous planning wave.

Step: {{NODE_NAME}}
ArtifactDir: {{ARTIFACT_DIR}}
Iteration: {{CURRENT_ITERATION}}

Task
```
{{TASK_DESCRIPTION}}
```

Workflow history (oldest first):
{{WORKFLOW_HISTORY}}

Clarifications so far:
{{CLARIFICATION_HISTORY}}

---

## Mission

Judge whether the approved planning-wave contract has been satisfied.

This node is not the overall task-progress evaluator. If the approved wave is complete and correct, return `passed: true` even if the original task may still need another planning wave. Remaining task-level work belongs to `evaluate_progress`, not this node.

## How to verify

Read the approved plan artifacts and every modified file. Pay particular attention to the wave goal, done definition, required checks, constraints, and out-of-scope boundaries. Do not trust the implementation summary on its own.

Always identify and read the newest relevant workflow artifact files referenced in the workflow history before judging the wave. Use the newest approved plan artifacts and the newest implementation artifacts for this wave, not stale artifacts from earlier failed attempts.

Read operations and side-effect-free commands are always allowed. Running tests and builds that the plan's verification section specified is allowed.

Do not require literal adherence to implementation details. A credible deviation may still pass if the wave goal is achieved, the done definition is satisfied, required checks pass, and the wave constraints are respected.

## Human TL;DR

Return `summary` as the human TL;DR. State whether verification passed, the strongest evidence you checked, and any remaining concern or follow-up a human should notice.

Let the amount of detail follow the importance of the information. Include whatever detail is needed to make the important information clear.

Do not restate the full verification artifact. It is fine to point humans to a relevant file path when that makes the important information easier to act on.

## Verification checklist

**1. Wave goal** — Did the implementation make the approved wave goal true?

**2. Done definition** — Are all parts of the approved done definition satisfied?

**3. Required checks** — Did the required checks pass, or is there strong code-level evidence they should pass when run as specified?

**4. Constraints and scope** — Did the implementation stay within the wave's constraints and out-of-scope boundaries while handling the relevant edge cases?

**5. No regressions** — Did the changes break existing behavior? Run relevant checks from the plan.

**6. Task guardrail** — Use the original task as a final guardrail. If you notice remaining work that belongs to a later planning wave rather than this one, mention it in the summary but do not fail on that basis alone.

## Decision

- Return `passed: true` only if the current approved planning-wave contract is satisfied.
- Return `passed: false` if the wave goal remains unmet, the done definition is not satisfied, required checks fail, constraints are broken, or concrete defects remain.

Write verification artifacts under {{ARTIFACT_DIR}}.

## Output

Return JSON matching the provided schema.
`passed`: whether the current approved planning-wave contract is satisfied.
`summary`: the concise human TL;DR for this verification decision, including any accepted deviations or evaluator-relevant follow-up.
`file_paths`: every verification artifact you wrote as absolute paths.
