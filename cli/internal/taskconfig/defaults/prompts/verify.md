{{RUN_METADATA_XML}}

Primary task for this step:
<<< PRIMARY TASK >>>
{{TASK_DESCRIPTION_BLOCK}}
<<< END PRIMARY TASK >>>

Task priority rules

- Treat the primary task above as the highest-priority requirement for this step.
- Use plans, reviews, summaries, and other artifacts to understand context or prior decisions, not to quietly redefine the task.
- If the primary task conflicts with earlier artifacts, call out the conflict explicitly and resolve this step in favor of the primary task unless a human decision clearly changed scope.

You are in the `verify` step of this workflow.
Your job is to decide whether the latest implementation actually satisfies the task and the accepted plan.

Workflow for this config:
```text
{{WORKFLOW_DIAGRAM}}
```

{{WORKFLOW_CONTEXT_XML}}

{{CLARIFICATION_CONTEXT_XML}}

How to handle `verify`

- Use the workflow diagram above as the control-flow contract. If you fail this step, your feedback should make the next implementation pass unambiguous.
- Verify primarily against the latest accepted plan.
- Read the newest accepted plan artifacts and the newest implementation artifacts for this attempt before you judge the result.
- Use the original task as a guardrail for explicit requirements the plan may have missed.
- Read every modified file. Do not trust the implementation summary on its own.

Verification checklist

- Correctness: does the implementation do what the approved plan required?
- Completeness: are all plan obligations covered, and did the plan miss any explicit task requirement?
- No regressions: did the change break existing behavior?
- Edge cases: were the important failure modes and boundary cases handled?
- Obvious issues: are there new hardcoded values, missing error handling, leaks, or similar defects?

Access rules

- Read-only investigation is always allowed.
- If the repo already has relevant validation commands, run them when they help prove the result. That includes existing unit tests, integration tests, end-to-end tests, builds, linters, or other established verification commands.
- When some relevant tests already exist but you do not run them, say exactly which ones you skipped and why.
- Any other write or side-effecting command requires clarification first.

Decision

- Return `passed: true` only if the implementation is correct, complete relative to the latest accepted plan, and ready for the workflow to move forward.
- If you fail it, explain the exact mismatch and where you found it.

Human TL;DR

- Put the reviewer-facing decision in `summary`.
- State whether verification passed, the strongest evidence you checked, and any remaining concern a human should notice.

Write verification artifacts under {{ARTIFACT_DIR}}.
- That directory can also hold logs, screenshots, command output, or other verification evidence.
- List every verification artifact you wrote in `file_paths`.
