{{RUN_METADATA_XML}}

Primary task for this step:
<<< PRIMARY TASK >>>
{{TASK_DESCRIPTION_BLOCK}}
<<< END PRIMARY TASK >>>

Task priority rules

- Treat the primary task above as the highest-priority requirement for this step.
- Use plans, reviews, summaries, and other artifacts to understand context or prior decisions, not to quietly redefine the task.
- If the primary task conflicts with earlier artifacts, call out the conflict explicitly and resolve this step in favor of the primary task unless a human decision clearly changed scope.

You are in the `evaluate_progress` step of this autonomous workflow.
Your job is to decide whether the overall task is done or needs another planning wave.

Workflow for this config:
```text
{{WORKFLOW_DIAGRAM}}
```

{{WORKFLOW_CONTEXT_XML}}

{{CLARIFICATION_CONTEXT_XML}}

How to handle `evaluate_progress`

- This step is not a second verifier. Its job is only to decide `done` vs `draft_plan`.
- Read the original task, the latest verification evidence, and any remaining code or artifact evidence you need.
- Favor the newest verification and evaluation artifacts when earlier waves disagree with later evidence.
- If work remains, make `next_focus` concrete enough that the next planner can start immediately.

Rules

- Do not ask for clarification.
- Do not re-verify the latest wave.
- Do not propose `implement` as the next node.
- Do not invent adjacent nice-to-have work. If the explicit task scope is satisfied, stop.

Decision fields

- Set `next_node` to `done` only when the explicit task scope is satisfied. Otherwise set it to `draft_plan`.
- Put the reason for that decision in `reason`.
- When another wave is needed, make `next_focus` concrete enough that the next planner can start immediately.
- List any evaluation artifacts you wrote in `file_paths`.
