package taskruntime

import (
	"encoding/json"
	"fmt"
	"html"
	"path/filepath"
	"sort"
	"strings"

	"github.com/LaLanMo/muxagent/cli/internal/taskconfig"
	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskstore"
)

const promptContextSummaryMaxLen = 240

func completedArtifactPaths(runs []taskdomain.NodeRun) []string {
	var artifacts []string
	for _, run := range runs {
		if run.Status != taskdomain.NodeRunDone {
			continue
		}
		artifacts = append(artifacts, taskdomain.ArtifactPaths(run.Result)...)
	}
	return artifacts
}

func buildPrompt(task taskdomain.Task, cfg *taskconfig.Config, configPath string, runs []taskdomain.NodeRun, run taskdomain.NodeRun, artifactDir string) (string, error) {
	return buildPromptWithInheritedContext(task, cfg, configPath, runs, run, artifactDir, nil)
}

func buildPromptWithInheritedContext(task taskdomain.Task, cfg *taskconfig.Config, configPath string, runs []taskdomain.NodeRun, run taskdomain.NodeRun, artifactDir string, inherited *inheritedContext) (string, error) {
	iteration := runIteration(runs, run)
	if shouldResumeClarificationThread(run) {
		return buildClarificationResumePrompt(task, cfg, runs, run, artifactDir, iteration, inherited)
	}
	def := cfg.NodeDefinitions[run.NodeName]
	template, err := taskconfig.ReadPromptText(configPath, def)
	if err != nil {
		return "", err
	}
	imageAttachmentContext, err := renderImageAttachmentContext(task, runs, run)
	if err != nil {
		return "", err
	}
	workflowContext := buildWorkflowContext(task, cfg, runs, run, inherited, imageAttachmentContext)
	clarificationContext := summarizeClarificationContext(run.Clarifications)
	workflowDiagram := buildWorkflowDiagram(cfg)
	runMetadataXML := buildRunMetadataXML(task, cfg, run, iteration, artifactDir)
	taskDescriptionBlock := buildPlainPromptBlock(task.Description)
	workflowContextXML := buildTaggedTextBlock("execution_context", workflowContext)
	clarificationContextXML := buildTaggedTextBlock("clarification_state", clarificationContext)
	replacer := strings.NewReplacer(
		"{{TASK_DESCRIPTION_BLOCK}}", taskDescriptionBlock,
		"{{WORKFLOW_CONTEXT_XML}}", workflowContextXML,
		"{{CLARIFICATION_CONTEXT_XML}}", clarificationContextXML,
		"{{ARTIFACT_DIR}}", artifactDir,
		"{{WORKFLOW_DIAGRAM}}", workflowDiagram,
		"{{RUN_METADATA_XML}}", runMetadataXML,
	)
	prompt := replacer.Replace(template)
	if strings.TrimSpace(imageAttachmentContext) != "" && !strings.Contains(template, "{{WORKFLOW_CONTEXT_XML}}") {
		prompt = strings.TrimRight(prompt, "\n") + "\n\n" + buildTaggedTextBlock("image_attachments", imageAttachmentContext)
	}
	return prompt, nil
}

func shouldResumeClarificationThread(run taskdomain.NodeRun) bool {
	if strings.TrimSpace(run.SessionID) == "" {
		return false
	}
	if len(run.Clarifications) == 0 {
		return false
	}
	return run.Clarifications[len(run.Clarifications)-1].Response != nil
}

func buildClarificationResumePrompt(task taskdomain.Task, cfg *taskconfig.Config, runs []taskdomain.NodeRun, run taskdomain.NodeRun, artifactDir string, iteration int, inherited *inheritedContext) (string, error) {
	latest := run.Clarifications[len(run.Clarifications)-1]
	imageAttachmentContext, err := renderImageAttachmentContext(task, runs, run)
	if err != nil {
		return "", err
	}
	workflowContextXML := buildTaggedTextBlock("execution_context", buildWorkflowContext(task, cfg, runs, run, inherited, imageAttachmentContext))
	clarificationContextXML := buildTaggedTextBlock("clarification_state", summarizeClarificationContext(run.Clarifications))
	lines := []string{
		buildRunMetadataXML(task, cfg, run, iteration, artifactDir),
	}
	lines = appendPrimaryTaskSection(lines, task.Description)
	lines = append(lines,
		"",
		fmt.Sprintf("You are resuming the `%s` step after the user answered your clarification request.", run.NodeName),
		"Stay in the same thread or session and continue this step from where it paused.",
		"",
		"Workflow for this config:",
		"```text",
		buildWorkflowDiagram(cfg),
		"```",
	)
	lines = append(lines, "", workflowContextXML, "", clarificationContextXML)
	if inheritedSummary := summarizeInheritedWorkflowContext(inherited); inheritedSummary != "" {
		lines = append(lines, "", buildTaggedTextBlock("follow_up_lineage", inheritedSummary))
	}
	lines = append(lines, "", "<clarification_exchange>")
	for qi, question := range latest.Request.Questions {
		lines = append(lines, fmt.Sprintf("Question %d: %s", qi+1, question.Question))
		if len(question.Options) > 0 {
			lines = append(lines, "Options offered:")
			for _, opt := range question.Options {
				if opt.Description != "" {
					lines = append(lines, fmt.Sprintf("  - %s: %s", opt.Label, opt.Description))
				} else {
					lines = append(lines, fmt.Sprintf("  - %s", opt.Label))
				}
			}
		}
		if latest.Response != nil && qi < len(latest.Response.Answers) {
			answerData, err := json.Marshal(latest.Response.Answers[qi].Selected)
			if err == nil {
				lines = append(lines, fmt.Sprintf("User selected: %s", string(answerData)))
			}
		}
		lines = append(lines, "")
	}
	lines = append(lines, "</clarification_exchange>")
	lines = append(lines,
		"",
		"What to do",
		"",
		"- Stay in the same thread context and continue from where this node paused.",
		"- Use the new clarification answers instead of restating the previous question.",
		"- Check the current node artifacts and any newest relevant prior artifacts before deciding what to do next.",
		"- Return the next structured output for this same step.",
		"",
		"Only ask for clarification again if the user's latest answer still leaves a genuinely blocking decision unresolved.",
	)
	return strings.Join(lines, "\n"), nil
}

func buildRunMetadataXML(task taskdomain.Task, cfg *taskconfig.Config, run taskdomain.NodeRun, iteration int, artifactDir string) string {
	taskDir := taskstore.TaskDir(task.WorkDir, task.ID)
	runsDir := filepath.Join(taskDir, "runs")
	lines := []string{
		"<task_metadata>",
		xmlLine("config_alias", firstNonEmptyPromptValue(task.ConfigAlias, "custom")),
		xmlLine("workflow_description", strings.TrimSpace(cfg.Description)),
		xmlLine("current_step", run.NodeName),
		xmlLine("current_iteration", fmt.Sprintf("%d", iteration)),
		xmlLine("task_dir", taskDir),
		xmlLine("runs_dir", runsDir),
		xmlLine("current_run_dir", artifactDir),
		xmlLine("artifact_dir", artifactDir),
		xmlLine("execution_dir", task.ExecutionWorkDir()),
		"</task_metadata>",
	}
	return strings.Join(lines, "\n")
}

func buildPlainPromptBlock(content string) string {
	content = strings.TrimSpace(content)
	if content == "" {
		return "(none)"
	}
	return content
}

func appendPrimaryTaskSection(lines []string, taskDescription string) []string {
	return append(lines,
		"",
		"Primary task for this step:",
		"<<< PRIMARY TASK >>>",
		buildPlainPromptBlock(taskDescription),
		"<<< END PRIMARY TASK >>>",
		"",
		"Task priority rules",
		"- Treat the primary task above as the highest-priority requirement for this step.",
		"- Use artifacts, review notes, and workflow history as context, not as silent overrides of the primary task.",
		"- If prior artifacts conflict with the primary task, call out the conflict and resolve it in favor of the primary task unless a human decision clearly changed scope.",
	)
}

func buildTaggedTextBlock(tagName, content string) string {
	content = strings.TrimSpace(content)
	if content == "" {
		content = "(none)"
	}
	return fmt.Sprintf("<%s>\n%s\n</%s>", tagName, escapePromptXML(content), tagName)
}

func xmlLine(tagName, value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		value = "(none)"
	}
	return fmt.Sprintf("  <%s>%s</%s>", tagName, escapePromptXML(value), tagName)
}

func escapePromptXML(value string) string {
	return html.EscapeString(value)
}

func summarizeWorkflowHistory(runs []taskdomain.NodeRun) string {
	entries := make([]string, 0, len(runs))
	ordinals := map[string]int{}
	step := 0
	for _, run := range sortedRunsByStart(runs) {
		ordinals[run.NodeName]++
		if run.Status != taskdomain.NodeRunDone {
			continue
		}
		step++
		label := fmt.Sprintf("%s (#%d)", run.NodeName, ordinals[run.NodeName])
		entryLines := []string{fmt.Sprintf("%d. %s", step, label)}
		if len(run.Result) > 0 {
			if data, err := json.Marshal(run.Result); err == nil {
				entryLines = append(entryLines, fmt.Sprintf("   Result JSON: %s", string(data)))
			}
		} else {
			entryLines = append(entryLines, "   Result JSON: (none)")
		}
		entries = append(entries, strings.Join(entryLines, "\n"))
	}
	return joinLines(entries)
}

func runIteration(runs []taskdomain.NodeRun, current taskdomain.NodeRun) int {
	ordinal := 0
	for _, run := range sortedRunsByStart(runs) {
		if run.NodeName == current.NodeName {
			ordinal++
		}
		if run.ID == current.ID {
			if ordinal < 1 {
				return 1
			}
			return ordinal
		}
	}
	ordinal++
	if ordinal < 1 {
		return 1
	}
	return ordinal
}

func buildWorkflowContext(task taskdomain.Task, cfg *taskconfig.Config, runs []taskdomain.NodeRun, current taskdomain.NodeRun, inherited *inheritedContext, imageAttachmentContext string) string {
	lines := []string{
		"- Use the directory paths in `<task_metadata>` when you need to locate the task, run, or current artifact directories.",
		"- Unless the user explicitly says otherwise, do all project edits, builds, tests, and commands in `<execution_dir>`.",
		"- Use the filesystem as the detailed source of truth. Each run directory can contain `manifest.json`, `input.md`, `output.json`, plus any supporting files the node wrote for handoff, evidence, screenshots, logs, or notes.",
		"- Run directories are ordered by creation via `manifest.json.sequence` and `started_at`.",
		"- Do not replay the entire task history by default. Read only the runs that matter for this step.",
	}
	if previous := previousRunForNode(runs, current); previous != nil {
		lines = append(lines, fmt.Sprintf("- This is iteration %d for `%s`. Previous same-step run: %s.", runIteration(runs, current), current.NodeName, describeRunLocation(task, runs, *previous)))
	}
	if latest := latestCompletedRun(runs); latest != nil {
		lines = append(lines, fmt.Sprintf("- Latest completed run overall: %s.", describeRunContext(task, runs, *latest)))
	} else {
		lines = append(lines, "- No completed runs exist yet for this task.")
	}
	lines = append(lines, "", "Latest completed runs by step:")
	stepLines := summarizeLatestCompletedRunsByStep(task, cfg, runs)
	if len(stepLines) == 0 {
		lines = append(lines, "(none)")
	} else {
		lines = append(lines, stepLines...)
	}
	if inheritedSummary := summarizeInheritedWorkflowContext(inherited); inheritedSummary != "" {
		lines = append(lines, "", "Follow-up lineage:", inheritedSummary)
	}
	if strings.TrimSpace(imageAttachmentContext) != "" {
		lines = append(lines, "", imageAttachmentContext)
	}
	return strings.Join(lines, "\n")
}

func buildWorkflowDiagram(cfg *taskconfig.Config) string {
	if diagram, ok := builtinWorkflowDiagram(cfg); ok {
		return diagram
	}
	selected := mainPathEdges(cfg)
	selectedKeys := map[string]struct{}{}
	lines := []string{
		fmt.Sprintf("Entry: [%s]", workflowNodeLabel(cfg, cfg.Topology.Entry)),
		"",
		"Main path:",
	}
	if len(selected) == 0 {
		lines = append(lines, "  (none)")
	} else {
		for _, edge := range selected {
			lines = append(lines, "  "+renderWorkflowEdge(cfg, edge))
			selectedKeys[workflowEdgeKey(edge)] = struct{}{}
		}
	}
	alternates := make([]string, 0)
	for _, edge := range cfg.Topology.Edges {
		if _, ok := selectedKeys[workflowEdgeKey(edge)]; ok {
			continue
		}
		alternates = append(alternates, "  "+renderWorkflowEdge(cfg, edge))
	}
	lines = append(lines, "", "Other transitions:")
	if len(alternates) == 0 {
		lines = append(lines, "  (none)")
	} else {
		lines = append(lines, alternates...)
	}
	return strings.Join(lines, "\n")
}

func builtinWorkflowDiagram(cfg *taskconfig.Config) (string, bool) {
	switch {
	case hasWorkflowNodes(cfg, "handle_request", "done"):
		return strings.Join([]string{
			"handle_request",
			"  |",
			"  v",
			"done (terminal)",
		}, "\n"), true
	case hasWorkflowNodes(cfg, "draft_plan", "review_plan", "done") && len(cfg.Topology.Nodes) == 3:
		return strings.Join([]string{
			"draft_plan",
			"  |",
			"  v",
			"review_plan",
			"  |-- passed=false --> draft_plan",
			"  `-- passed=true --> done (terminal)",
		}, "\n"), true
	case hasWorkflowNodes(cfg, "draft_plan", "review_plan", "approve_plan", "implement", "verify", "done"):
		return strings.Join([]string{
			"draft_plan",
			"  |",
			"  v",
			"review_plan",
			"  |-- passed=false --> draft_plan",
			"  `-- passed=true --> approve_plan (human)",
			"                          |-- approved=false --> draft_plan",
			"                          `-- approved=true --> implement",
			"                                                  |",
			"                                                  v",
			"                                                verify",
			"                                                  |-- passed=false --> implement",
			"                                                  `-- passed=true --> done (terminal)",
		}, "\n"), true
	case hasWorkflowNodes(cfg, "draft_plan", "review_plan", "implement", "verify", "evaluate_progress", "done"):
		return strings.Join([]string{
			"draft_plan",
			"  |",
			"  v",
			"review_plan",
			"  |-- passed=false --> draft_plan",
			"  `-- passed=true --> implement",
			"                          |",
			"                          v",
			"                        verify",
			"                          |-- passed=false --> implement",
			"                          `-- passed=true --> evaluate_progress",
			"                                                  |-- next_node=draft_plan --> draft_plan",
			"                                                  `-- next_node=done --> done (terminal)",
		}, "\n"), true
	case hasWorkflowNodes(cfg, "draft_plan", "review_plan", "implement", "verify", "done"):
		return strings.Join([]string{
			"draft_plan",
			"  |",
			"  v",
			"review_plan",
			"  |-- passed=false --> draft_plan",
			"  `-- passed=true --> implement",
			"                          |",
			"                          v",
			"                        verify",
			"                          |-- passed=false --> implement",
			"                          `-- passed=true --> done (terminal)",
		}, "\n"), true
	default:
		return "", false
	}
}

func hasWorkflowNodes(cfg *taskconfig.Config, names ...string) bool {
	if len(cfg.Topology.Nodes) != len(names) {
		return false
	}
	seen := make(map[string]struct{}, len(cfg.Topology.Nodes))
	for _, node := range cfg.Topology.Nodes {
		seen[node.Name] = struct{}{}
	}
	for _, name := range names {
		if _, ok := seen[name]; !ok {
			return false
		}
	}
	return true
}

func mainPathEdges(cfg *taskconfig.Config) []taskconfig.Edge {
	byFrom := map[string][]taskconfig.Edge{}
	for _, edge := range cfg.Topology.Edges {
		byFrom[edge.From] = append(byFrom[edge.From], edge)
	}
	current := cfg.Topology.Entry
	seenNodes := map[string]struct{}{current: {}}
	path := make([]taskconfig.Edge, 0, len(cfg.Topology.Nodes))
	for {
		candidates := byFrom[current]
		if len(candidates) == 0 {
			return path
		}
		choice := chooseMainPathEdge(cfg, candidates, seenNodes)
		if choice == nil {
			return path
		}
		path = append(path, *choice)
		if cfg.NodeDefinitions[choice.To].Type == taskconfig.NodeTypeTerminal {
			return path
		}
		if _, ok := seenNodes[choice.To]; ok {
			return path
		}
		seenNodes[choice.To] = struct{}{}
		current = choice.To
	}
}

func chooseMainPathEdge(cfg *taskconfig.Config, candidates []taskconfig.Edge, seenNodes map[string]struct{}) *taskconfig.Edge {
	bestIndex := -1
	bestScore := -1
	for i, edge := range candidates {
		score := scoreWorkflowEdge(cfg, edge)
		if _, seen := seenNodes[edge.To]; seen {
			score -= 1000
		}
		if score > bestScore {
			bestScore = score
			bestIndex = i
		}
	}
	if bestIndex < 0 {
		return nil
	}
	edge := candidates[bestIndex]
	return &edge
}

func scoreWorkflowEdge(cfg *taskconfig.Config, edge taskconfig.Edge) int {
	score := 0
	if cfg.NodeDefinitions[edge.To].Type == taskconfig.NodeTypeTerminal {
		score += 100
	}
	switch edge.When.Kind {
	case taskconfig.ConditionNone:
		score += 90
	case taskconfig.ConditionElse:
		score += 10
	default:
		switch value := edge.When.Equals.(type) {
		case bool:
			if value {
				score += 80
			} else {
				score += 40
			}
		case string:
			if strings.EqualFold(strings.TrimSpace(value), "done") {
				score += 85
			} else {
				score += 50
			}
		default:
			score += 50
		}
	}
	return score
}

func renderWorkflowEdge(cfg *taskconfig.Config, edge taskconfig.Edge) string {
	from := fmt.Sprintf("[%s]", workflowNodeLabel(cfg, edge.From))
	to := fmt.Sprintf("[%s]", workflowNodeLabel(cfg, edge.To))
	condition := workflowEdgeCondition(edge)
	if condition == "" {
		return fmt.Sprintf("%s -> %s", from, to)
	}
	return fmt.Sprintf("%s -- %s --> %s", from, condition, to)
}

func workflowNodeLabel(cfg *taskconfig.Config, nodeName string) string {
	label := nodeName
	if def, ok := cfg.NodeDefinitions[nodeName]; ok {
		switch def.Type {
		case taskconfig.NodeTypeHuman:
			label += " (human)"
		case taskconfig.NodeTypeTerminal:
			label += " (terminal)"
		}
	}
	return label
}

func workflowEdgeCondition(edge taskconfig.Edge) string {
	switch edge.When.Kind {
	case taskconfig.ConditionNone:
		return ""
	case taskconfig.ConditionElse:
		return "else"
	default:
		return fmt.Sprintf("%s=%v", edge.When.Field, edge.When.Equals)
	}
}

func workflowEdgeKey(edge taskconfig.Edge) string {
	return fmt.Sprintf("%s|%s|%s|%v", edge.From, edge.To, edge.When.Kind, edge.When.Equals)
}

func summarizeClarificationContext(exchanges []taskdomain.ClarificationExchange) string {
	entries := make([]string, 0, len(exchanges))
	for _, exchange := range exchanges {
		for qi, question := range exchange.Request.Questions {
			lines := []string{fmt.Sprintf("- %s", question.Question)}
			if question.WhyItMatters != "" {
				lines = append(lines, fmt.Sprintf("  Why it matters: %s", question.WhyItMatters))
			}
			if exchange.Response != nil && qi < len(exchange.Response.Answers) {
				answerData, err := json.Marshal(exchange.Response.Answers[qi].Selected)
				if err == nil {
					lines = append(lines, fmt.Sprintf("  User answer: %s", string(answerData)))
				}
			} else {
				lines = append(lines, "  User answer: pending")
			}
			entries = append(entries, strings.Join(lines, "\n"))
		}
	}
	return joinLines(entries)
}

func joinLines(items []string) string {
	if len(items) == 0 {
		return "(none)"
	}
	return strings.Join(items, "\n")
}

func sortedRunsByStart(runs []taskdomain.NodeRun) []taskdomain.NodeRun {
	sorted := append([]taskdomain.NodeRun(nil), runs...)
	sort.SliceStable(sorted, func(i, j int) bool {
		if sorted[i].StartedAt.Equal(sorted[j].StartedAt) {
			return false
		}
		return sorted[i].StartedAt.Before(sorted[j].StartedAt)
	})
	return sorted
}

func latestCompletedRun(runs []taskdomain.NodeRun) *taskdomain.NodeRun {
	sorted := sortedRunsByStart(runs)
	for i := len(sorted) - 1; i >= 0; i-- {
		if sorted[i].Status == taskdomain.NodeRunDone {
			run := sorted[i]
			return &run
		}
	}
	return nil
}

func previousRunForNode(runs []taskdomain.NodeRun, current taskdomain.NodeRun) *taskdomain.NodeRun {
	sorted := sortedRunsByStart(runs)
	currentIndex := -1
	for i, run := range sorted {
		if run.ID == current.ID {
			currentIndex = i
			break
		}
	}
	if currentIndex < 0 {
		currentIndex = len(sorted)
	}
	for i := currentIndex - 1; i >= 0; i-- {
		if sorted[i].NodeName == current.NodeName {
			run := sorted[i]
			return &run
		}
	}
	return nil
}

func summarizeLatestCompletedRunsByStep(task taskdomain.Task, cfg *taskconfig.Config, runs []taskdomain.NodeRun) []string {
	latestByNode := map[string]taskdomain.NodeRun{}
	for _, run := range sortedRunsByStart(runs) {
		if run.Status != taskdomain.NodeRunDone {
			continue
		}
		latestByNode[run.NodeName] = run
	}
	lines := make([]string, 0, len(cfg.Topology.Nodes))
	seen := map[string]struct{}{}
	for _, node := range cfg.Topology.Nodes {
		if _, ok := seen[node.Name]; ok {
			continue
		}
		seen[node.Name] = struct{}{}
		def, ok := cfg.NodeDefinitions[node.Name]
		if !ok || def.Type == taskconfig.NodeTypeTerminal {
			continue
		}
		run, ok := latestByNode[node.Name]
		if !ok {
			continue
		}
		lines = append(lines, fmt.Sprintf("- %s: %s", node.Name, describeRunContext(task, runs, run)))
	}
	return lines
}

func describeRunLocation(task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun) string {
	return fmt.Sprintf("run directory `%s` (`%s` iteration %d)", taskstore.RunDir(task.WorkDir, task.ID, run.ID), run.NodeName, runIteration(runs, run))
}

func describeRunContext(task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun) string {
	parts := []string{
		fmt.Sprintf("iteration %d", runIteration(runs, run)),
		fmt.Sprintf("run directory `%s`", taskstore.RunDir(task.WorkDir, task.ID, run.ID)),
	}
	if decision := summarizeRunDecision(run.Result); decision != "" {
		parts = append(parts, decision)
	}
	if summary := summarizeRunSummary(run.Result); summary != "" {
		parts = append(parts, fmt.Sprintf("summary: %s", summary))
	}
	if len(taskdomain.ArtifactPaths(run.Result)) > 0 {
		parts = append(parts, "extra files are listed in `output.json.result.file_paths`")
	}
	return strings.Join(parts, "; ")
}

func summarizeRunDecision(result map[string]interface{}) string {
	if result == nil {
		return ""
	}
	if passed, ok := result["passed"].(bool); ok {
		return fmt.Sprintf("decision: passed=%t", passed)
	}
	if approved, ok := result["approved"].(bool); ok {
		return fmt.Sprintf("decision: approved=%t", approved)
	}
	if nextNode, ok := result["next_node"].(string); ok && strings.TrimSpace(nextNode) != "" {
		return fmt.Sprintf("next_node: %s", nextNode)
	}
	return ""
}

func summarizeRunSummary(result map[string]interface{}) string {
	if result == nil {
		return ""
	}
	for _, key := range []string{"summary", "reason", "feedback"} {
		text, ok := result[key].(string)
		if !ok {
			continue
		}
		text = normalizePromptContextText(text)
		if text != "" {
			return text
		}
	}
	return ""
}

func normalizePromptContextText(text string) string {
	text = strings.Join(strings.Fields(strings.TrimSpace(text)), " ")
	if len(text) <= promptContextSummaryMaxLen {
		return text
	}
	return text[:promptContextSummaryMaxLen-3] + "..."
}

func summarizeInheritedWorkflowContext(inherited *inheritedContext) string {
	if inherited == nil {
		return ""
	}
	lines := make([]string, 0, 6)
	if inherited.DirectParent != nil {
		lines = append(lines,
			fmt.Sprintf("- Direct parent task: %s", inherited.DirectParent.Description),
			fmt.Sprintf("  Task directory: `%s`", inherited.DirectParent.TaskDir),
			fmt.Sprintf("  If you need parent outputs, inspect the newest relevant run directories under `%s` first.", filepath.Join(inherited.DirectParent.TaskDir, "runs")),
		)
	}
	if len(inherited.EarlierAncestors) > 0 {
		lines = append(lines, "- Earlier ancestors are available only if the direct parent is not enough:")
		for _, ancestor := range inherited.EarlierAncestors {
			lines = append(lines, fmt.Sprintf("  - %s (task directory: `%s`)", ancestor.Description, ancestor.TaskDir))
		}
	}
	return strings.Join(lines, "\n")
}

func firstNonEmptyPromptValue(values ...string) string {
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			return value
		}
	}
	return ""
}
