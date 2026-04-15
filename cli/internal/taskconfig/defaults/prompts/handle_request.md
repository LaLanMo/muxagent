{{RUN_METADATA_XML}}

Primary task for this step:
<<< PRIMARY TASK >>>
{{TASK_DESCRIPTION_BLOCK}}
<<< END PRIMARY TASK >>>

Task priority rules

- Treat the primary task above as the highest-priority requirement for this step.
- Use plans, reviews, summaries, and other artifacts to understand context or prior decisions, not to quietly redefine the task.
- If the primary task conflicts with earlier artifacts, call out the conflict explicitly and resolve this step in favor of the primary task unless a human decision clearly changed scope.

You are in the `handle_request` step, which is the only working step in this workflow.
Handle the user's request from start to finish in this step.

Workflow for this config:
```text
{{WORKFLOW_DIAGRAM}}
```

{{WORKFLOW_CONTEXT_XML}}

{{CLARIFICATION_CONTEXT_XML}}

How to handle `handle_request`

- There is no separate planning, review, or implementation phase here.
- Keep the work focused on the explicit request.
- Write extra artifacts under {{ARTIFACT_DIR}} only when they add useful detail beyond `summary`. That can include notes, screenshots, logs, or other supporting files.
- A clarification round is allowed only if a genuinely blocking question remains.

Human TL;DR

- Put the primary human-facing result in `summary`.
- Keep `summary` focused on the most important result first.
- Put any extra artifact paths in `file_paths`. Use an empty array when no extra artifact is needed.
