package taskruntime

import (
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskstore"
)

const (
	inputArtifactName          = "input.md"
	outputArtifactName         = "output.json"
	manifestArtifactName       = "manifest.json"
	attachmentDirName          = "attachments"
	attachmentManifestName     = "attachments.json"
	clarificationHistoryMarker = "<!-- muxagent:clarification-history -->"
	maxImageAttachmentCount    = 6
	maxImageAttachmentBytes    = 8 * 1024 * 1024
)

var unsafeAttachmentNameChars = regexp.MustCompile(`[^A-Za-z0-9._-]+`)

type runManifest struct {
	TaskID      string                   `json:"task_id"`
	NodeRunID   string                   `json:"node_run_id"`
	NodeName    string                   `json:"node_name"`
	Sequence    int                      `json:"sequence,omitempty"`
	Status      taskdomain.NodeRunStatus `json:"status"`
	SessionID   string                   `json:"session_id,omitempty"`
	StartedAt   time.Time                `json:"started_at"`
	CompletedAt *time.Time               `json:"completed_at,omitempty"`
}

type imageAttachmentManifest struct {
	Images []ImageAttachmentArtifact `json:"images"`
}

type ImageAttachmentArtifact struct {
	OriginalFilename string `json:"original_filename"`
	MIMEType         string `json:"mime_type"`
	SizeBytes        int64  `json:"size_bytes"`
	SHA256           string `json:"sha256"`
	RelativePath     string `json:"relative_path"`
	AbsolutePath     string `json:"absolute_path"`
}

type imageAttachmentContextEntry struct {
	Run    taskdomain.NodeRun
	Images []ImageAttachmentArtifact
}

func runArtifactDirPath(task taskdomain.Task, _ []taskdomain.NodeRun, run taskdomain.NodeRun) (string, error) {
	if strings.TrimSpace(run.ID) == "" {
		return "", fmt.Errorf("node run id is required")
	}
	return taskstore.RunDir(task.WorkDir, task.ID, run.ID), nil
}

func runArtifactDir(task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun) (string, error) {
	dir, err := runArtifactDirPath(task, runs, run)
	if err != nil {
		return "", err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	if err := persistRunManifest(task, runs, run); err != nil {
		return "", err
	}
	return dir, nil
}

func runArtifactPath(task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun, name string) (string, error) {
	dir, err := runArtifactDir(task, runs, run)
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, name), nil
}

func runArtifactPathForExistingRun(task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun, name string) (string, error) {
	dir, err := runArtifactDirPath(task, runs, run)
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, name), nil
}

func nodeRunSequence(runs []taskdomain.NodeRun, runID string) int {
	sorted := append([]taskdomain.NodeRun(nil), runs...)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].StartedAt.Equal(sorted[j].StartedAt) {
			return sorted[i].ID < sorted[j].ID
		}
		return sorted[i].StartedAt.Before(sorted[j].StartedAt)
	})
	for i, run := range sorted {
		if run.ID == runID {
			return i + 1
		}
	}
	return 0
}

func persistRunManifest(task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun) error {
	dir, err := runArtifactDirPath(task, runs, run)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	manifest := runManifest{
		TaskID:      task.ID,
		NodeRunID:   run.ID,
		NodeName:    run.NodeName,
		Sequence:    nodeRunSequence(runs, run.ID),
		Status:      run.Status,
		SessionID:   run.SessionID,
		StartedAt:   run.StartedAt,
		CompletedAt: run.CompletedAt,
	}
	data, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	return os.WriteFile(filepath.Join(dir, manifestArtifactName), data, 0o644)
}

func materializeHumanNodeArtifact(task taskdomain.Task, run taskdomain.NodeRun, runs []taskdomain.NodeRun, payload map[string]interface{}, submittedAt time.Time, attachments ...[]ImageAttachmentArtifact) (map[string]interface{}, error) {
	outputPath, err := runArtifactPath(task, runs, run, outputArtifactName)
	if err != nil {
		return nil, err
	}
	if _, err := writeHumanInputArtifact(task, run, runs, payload, submittedAt, optionalImageAttachmentArtifacts(attachments)); err != nil {
		return nil, err
	}
	envelope := map[string]interface{}{
		"kind":         "human_node_result",
		"task_id":      task.ID,
		"node_run_id":  run.ID,
		"node_name":    run.NodeName,
		"submitted_at": submittedAt.Format(time.RFC3339Nano),
		"result":       cloneMap(payload),
	}
	data, err := json.MarshalIndent(envelope, "", "  ")
	if err != nil {
		return nil, err
	}
	data = append(data, '\n')
	if err := os.WriteFile(outputPath, data, 0o644); err != nil {
		return nil, err
	}
	return cloneMap(payload), nil
}

func cloneMap(src map[string]interface{}) map[string]interface{} {
	if len(src) == 0 {
		return map[string]interface{}{}
	}
	dst := make(map[string]interface{}, len(src))
	for key, value := range src {
		dst[key] = value
	}
	return dst
}

func writeHumanInputArtifact(task taskdomain.Task, run taskdomain.NodeRun, runs []taskdomain.NodeRun, payload map[string]interface{}, submittedAt time.Time, attachments []ImageAttachmentArtifact) (string, error) {
	body, err := renderHumanInputMarkdown(payload, submittedAt, attachments)
	if err != nil {
		return "", err
	}
	return writeInputArtifact(task, run, runs, body)
}

func ensureAgentInputArtifact(task taskdomain.Task, run taskdomain.NodeRun, runs []taskdomain.NodeRun, prompt string) (string, error) {
	path, err := runArtifactPath(task, runs, run, inputArtifactName)
	if err != nil {
		return "", err
	}
	if len(run.Clarifications) > 0 {
		info, statErr := os.Stat(path)
		if statErr == nil && !info.IsDir() {
			return path, nil
		}
		if statErr != nil && !errors.Is(statErr, os.ErrNotExist) {
			return "", statErr
		}
	}
	if err := os.WriteFile(path, renderAgentInputMarkdown(prompt), 0o644); err != nil {
		return "", err
	}
	return path, nil
}

func writeClarificationInputArtifact(task taskdomain.Task, run taskdomain.NodeRun, runs []taskdomain.NodeRun) (string, error) {
	path, err := runArtifactPath(task, runs, run, inputArtifactName)
	if err != nil {
		return "", err
	}
	base, err := readClarificationInputBase(path)
	if err != nil {
		return "", err
	}
	history, err := renderClarificationInputMarkdown(run.Clarifications)
	if err != nil {
		return "", err
	}
	if err := os.WriteFile(path, mergeClarificationInputMarkdown(base, history), 0o644); err != nil {
		return "", err
	}
	return path, nil
}

func writeInputArtifact(task taskdomain.Task, run taskdomain.NodeRun, runs []taskdomain.NodeRun, body []byte) (string, error) {
	path, err := runArtifactPath(task, runs, run, inputArtifactName)
	if err != nil {
		return "", err
	}
	if err := os.WriteFile(path, body, 0o644); err != nil {
		return "", err
	}
	return path, nil
}

func persistImageAttachments(task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun, inputs []ImageAttachmentInput) ([]ImageAttachmentArtifact, error) {
	if len(inputs) == 0 {
		return nil, nil
	}
	if len(inputs) > maxImageAttachmentCount {
		return nil, fmt.Errorf("too many image attachments: got %d, max %d", len(inputs), maxImageAttachmentCount)
	}
	dir, err := runArtifactDir(task, runs, run)
	if err != nil {
		return nil, err
	}
	attachmentDir := filepath.Join(dir, attachmentDirName)
	if err := os.MkdirAll(attachmentDir, 0o755); err != nil {
		return nil, err
	}
	images := make([]ImageAttachmentArtifact, 0, len(inputs))
	for i, input := range inputs {
		data, mimeType, err := decodeImageAttachmentInput(input)
		if err != nil {
			return nil, fmt.Errorf("image attachment %d: %w", i+1, err)
		}
		filename := managedAttachmentFilename(input.Name, mimeType, i+1)
		relativePath := filepath.ToSlash(filepath.Join(attachmentDirName, filename))
		absolutePath := filepath.Join(dir, filepath.FromSlash(relativePath))
		sum := sha256.Sum256(data)
		if err := os.WriteFile(absolutePath, data, 0o644); err != nil {
			return nil, err
		}
		images = append(images, ImageAttachmentArtifact{
			OriginalFilename: displayAttachmentName(input.Name),
			MIMEType:         mimeType,
			SizeBytes:        int64(len(data)),
			SHA256:           hex.EncodeToString(sum[:]),
			RelativePath:     relativePath,
			AbsolutePath:     absolutePath,
		})
	}
	manifest := imageAttachmentManifest{Images: images}
	payload, err := json.MarshalIndent(manifest, "", "  ")
	if err != nil {
		return nil, err
	}
	payload = append(payload, '\n')
	if err := os.WriteFile(filepath.Join(dir, attachmentManifestName), payload, 0o644); err != nil {
		return nil, err
	}
	return images, nil
}

func decodeImageAttachmentInput(input ImageAttachmentInput) ([]byte, string, error) {
	mimeType := strings.ToLower(strings.TrimSpace(input.MIMEType))
	dataText := strings.TrimSpace(input.DataBase64)
	if strings.HasPrefix(strings.ToLower(dataText), "data:") {
		header, body, ok := strings.Cut(dataText, ",")
		if !ok {
			return nil, "", errors.New("data URL is missing base64 payload")
		}
		if !strings.Contains(strings.ToLower(header), ";base64") {
			return nil, "", errors.New("data URL must be base64 encoded")
		}
		if mimeType == "" {
			mimeType = strings.TrimPrefix(strings.ToLower(strings.TrimSpace(strings.TrimSuffix(header, ";base64"))), "data:")
		}
		dataText = body
	}
	if !isAllowedImageMIMEType(mimeType) {
		return nil, "", fmt.Errorf("unsupported MIME type %q", mimeType)
	}
	if dataText == "" {
		return nil, "", errors.New("base64 data is required")
	}
	if input.SizeBytes > maxImageAttachmentBytes {
		return nil, "", fmt.Errorf("image is too large: %d bytes exceeds %d", input.SizeBytes, maxImageAttachmentBytes)
	}
	data, err := base64.StdEncoding.DecodeString(dataText)
	if err != nil {
		return nil, "", fmt.Errorf("decode base64: %w", err)
	}
	if len(data) == 0 {
		return nil, "", errors.New("image data is empty")
	}
	if len(data) > maxImageAttachmentBytes {
		return nil, "", fmt.Errorf("image is too large: %d bytes exceeds %d", len(data), maxImageAttachmentBytes)
	}
	if input.SizeBytes > 0 && input.SizeBytes != int64(len(data)) {
		return nil, "", fmt.Errorf("declared size %d does not match decoded size %d", input.SizeBytes, len(data))
	}
	return data, mimeType, nil
}

func isAllowedImageMIMEType(mimeType string) bool {
	switch strings.ToLower(strings.TrimSpace(mimeType)) {
	case "image/png", "image/jpeg", "image/gif", "image/webp":
		return true
	default:
		return false
	}
}

func managedAttachmentFilename(originalName, mimeType string, index int) string {
	name := displayAttachmentName(originalName)
	stem := strings.TrimSuffix(name, filepath.Ext(name))
	stem = unsafeAttachmentNameChars.ReplaceAllString(stem, "-")
	stem = strings.Trim(stem, ".-_ ")
	if stem == "" {
		stem = "image"
	}
	if len(stem) > 56 {
		stem = stem[:56]
		stem = strings.Trim(stem, ".-_ ")
		if stem == "" {
			stem = "image"
		}
	}
	return fmt.Sprintf("%03d-%s%s", index, stem, imageExtensionForMIMEType(mimeType))
}

func displayAttachmentName(originalName string) string {
	name := strings.TrimSpace(strings.ReplaceAll(originalName, "\x00", ""))
	if name == "" {
		return "image"
	}
	name = filepath.Base(filepath.ToSlash(name))
	name = strings.TrimSpace(name)
	if name == "." || name == string(filepath.Separator) || name == "" {
		return "image"
	}
	return name
}

func imageExtensionForMIMEType(mimeType string) string {
	switch strings.ToLower(strings.TrimSpace(mimeType)) {
	case "image/jpeg":
		return ".jpg"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	default:
		return ".png"
	}
}

func readImageAttachmentManifest(task taskdomain.Task, runs []taskdomain.NodeRun, run taskdomain.NodeRun) ([]ImageAttachmentArtifact, error) {
	path, err := runArtifactPathForExistingRun(task, runs, run, attachmentManifestName)
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	var manifest imageAttachmentManifest
	if err := json.Unmarshal(data, &manifest); err != nil {
		return nil, fmt.Errorf("read image attachment manifest %s: %w", path, err)
	}
	return manifest.Images, nil
}

func collectImageAttachmentContext(task taskdomain.Task, runs []taskdomain.NodeRun, current taskdomain.NodeRun) ([]imageAttachmentContextEntry, error) {
	ordered := sortedRunsByStart(runs)
	if !containsRunID(ordered, current.ID) {
		ordered = append(ordered, current)
	}
	entries := make([]imageAttachmentContextEntry, 0)
	for _, run := range ordered {
		if strings.TrimSpace(run.ID) == "" {
			continue
		}
		if run.ID != current.ID && run.Status != taskdomain.NodeRunDone {
			continue
		}
		if run.ID != current.ID && current.StartedAt.IsZero() == false && run.StartedAt.After(current.StartedAt) {
			continue
		}
		images, err := readImageAttachmentManifest(task, runs, run)
		if err != nil {
			return nil, err
		}
		if len(images) == 0 {
			continue
		}
		entries = append(entries, imageAttachmentContextEntry{Run: run, Images: images})
		if run.ID == current.ID {
			break
		}
	}
	return entries, nil
}

func containsRunID(runs []taskdomain.NodeRun, runID string) bool {
	for _, run := range runs {
		if run.ID == runID {
			return true
		}
	}
	return false
}

func imageAttachmentPaths(task taskdomain.Task, runs []taskdomain.NodeRun, current taskdomain.NodeRun) ([]string, error) {
	entries, err := collectImageAttachmentContext(task, runs, current)
	if err != nil {
		return nil, err
	}
	var paths []string
	for _, entry := range entries {
		for _, image := range entry.Images {
			if strings.TrimSpace(image.AbsolutePath) != "" {
				paths = append(paths, image.AbsolutePath)
			}
		}
	}
	return paths, nil
}

func renderImageAttachmentContext(task taskdomain.Task, runs []taskdomain.NodeRun, current taskdomain.NodeRun) (string, error) {
	entries, err := collectImageAttachmentContext(task, runs, current)
	if err != nil {
		return "", err
	}
	if len(entries) == 0 {
		return "", nil
	}
	lines := []string{
		"Image attachments are available as managed local files. Use these paths when image contents matter:",
	}
	for _, entry := range entries {
		label := fmt.Sprintf("- %s (#%d), run %s", entry.Run.NodeName, runIteration(runs, entry.Run), entry.Run.ID)
		lines = append(lines, label)
		for _, image := range entry.Images {
			lines = append(lines, fmt.Sprintf("  - %s: `%s` (%s, %d bytes, sha256:%s)", image.OriginalFilename, image.AbsolutePath, image.MIMEType, image.SizeBytes, image.SHA256))
		}
	}
	return strings.Join(lines, "\n"), nil
}

func appendAttachmentMarkdown(lines []string, attachments []ImageAttachmentArtifact) []string {
	if len(attachments) == 0 {
		return lines
	}
	lines = append(lines, "", "## Image Attachments", "")
	for _, image := range attachments {
		lines = append(lines, fmt.Sprintf("- %s", image.OriginalFilename))
		lines = append(lines, fmt.Sprintf("  - MIME type: %s", image.MIMEType))
		lines = append(lines, fmt.Sprintf("  - Size: %d bytes", image.SizeBytes))
		lines = append(lines, fmt.Sprintf("  - SHA-256: %s", image.SHA256))
		lines = append(lines, fmt.Sprintf("  - Relative path: `%s`", image.RelativePath))
		lines = append(lines, fmt.Sprintf("  - Absolute path: `%s`", image.AbsolutePath))
	}
	return lines
}

func optionalImageAttachmentArtifacts(values [][]ImageAttachmentArtifact) []ImageAttachmentArtifact {
	if len(values) == 0 {
		return nil
	}
	return values[0]
}

func readClarificationInputBase(path string) ([]byte, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, nil
		}
		return nil, err
	}
	if idx := bytes.Index(data, []byte(clarificationHistoryMarker)); idx >= 0 {
		data = data[:idx]
	}
	return append([]byte(nil), data...), nil
}

func mergeClarificationInputMarkdown(base []byte, history []byte) []byte {
	out := append([]byte(nil), base...)
	if len(out) > 0 {
		switch {
		case bytes.HasSuffix(out, []byte("\n\n")):
		case bytes.HasSuffix(out, []byte("\n")):
			out = append(out, '\n')
		default:
			out = append(out, '\n', '\n')
		}
	}
	out = append(out, clarificationHistoryMarker...)
	out = append(out, '\n', '\n')
	out = append(out, bytes.TrimRight(history, "\n")...)
	out = append(out, '\n')
	return out
}

func renderHumanInputMarkdown(payload map[string]interface{}, submittedAt time.Time, attachments []ImageAttachmentArtifact) ([]byte, error) {
	data, err := json.MarshalIndent(cloneMap(payload), "", "  ")
	if err != nil {
		return nil, err
	}
	lines := []string{
		"# Input",
		"",
		fmt.Sprintf("Submitted: %s", submittedAt.Format(time.RFC3339Nano)),
		"",
		"```json",
		string(data),
		"```",
	}
	lines = appendAttachmentMarkdown(lines, attachments)
	return []byte(strings.Join(lines, "\n") + "\n"), nil
}

func renderAgentInputMarkdown(prompt string) []byte {
	return []byte(prompt)
}

func renderClarificationInputMarkdown(exchanges []taskdomain.ClarificationExchange) ([]byte, error) {
	lines := []string{"## Clarification History", ""}
	for i, exchange := range exchanges {
		lines = append(lines, fmt.Sprintf("### Exchange %d", i+1), "")
		lines = append(lines, fmt.Sprintf("Requested: %s", exchange.RequestedAt.Format(time.RFC3339Nano)))
		if exchange.AnsweredAt != nil {
			lines = append(lines, fmt.Sprintf("Answered: %s", exchange.AnsweredAt.Format(time.RFC3339Nano)))
		} else {
			lines = append(lines, "Status: awaiting_user")
		}
		lines = append(lines, "")
		for qi, question := range exchange.Request.Questions {
			lines = append(lines, fmt.Sprintf("#### Question %d", qi+1), "", question.Question, "")
			if question.WhyItMatters != "" {
				lines = append(lines, fmt.Sprintf("Why it matters: %s", question.WhyItMatters), "")
			}
			if question.MultiSelect {
				lines = append(lines, "Selection mode: multi-select", "")
			}
			if len(question.Options) > 0 {
				lines = append(lines, "Options:")
				for _, option := range question.Options {
					if option.Description != "" {
						lines = append(lines, fmt.Sprintf("- `%s`: %s", option.Label, option.Description))
					} else {
						lines = append(lines, fmt.Sprintf("- `%s`", option.Label))
					}
				}
				lines = append(lines, "")
			}
			if exchange.Response != nil && qi < len(exchange.Response.Answers) {
				selected, err := json.MarshalIndent(exchange.Response.Answers[qi].Selected, "", "  ")
				if err != nil {
					return nil, err
				}
				lines = append(lines, "Answer:", "", "```json", string(selected), "```", "")
				continue
			}
			lines = append(lines, "Answer: pending", "")
		}
	}
	return []byte(strings.Join(lines, "\n") + "\n"), nil
}
