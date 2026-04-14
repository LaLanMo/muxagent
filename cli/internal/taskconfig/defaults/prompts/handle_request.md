Handle the current request.

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

Do the work the user asked for.

Use the workflow history and clarifications above when they are relevant.

`summary` is the primary human-facing result for this node. Make it directly answer the user's request and surface the important result first.

Let the amount of detail follow the importance of the information. Include whatever detail is needed to make the important information clear.

Only write artifacts under {{ARTIFACT_DIR}} when extra detail, supporting notes, or logs would help beyond the TL;DR. If `summary` is sufficient on its own, return `file_paths: []`.

When you do write extra detail, keep it supplemental to `summary`, not a duplicate of it.

## Output

Return JSON matching the provided schema.
`summary`: the primary human-facing result for this request.
`file_paths`: optional extra-detail artifacts under {{ARTIFACT_DIR}} as absolute paths. Use an empty array when no extra artifact is needed.
