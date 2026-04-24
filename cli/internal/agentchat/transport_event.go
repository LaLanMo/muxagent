package agentchat

import "github.com/LaLanMo/muxagent/cli/internal/appwire"

const (
	DefaultEventBufferByteBudget = 2 * 1024 * 1024

	transportToolOutputPreviewBytes = 64 * 1024
	transportToolErrorPreviewBytes  = 64 * 1024
	transportToolInputPreviewBytes  = 8 * 1024
	transportToolDiffTextMaxBytes   = 16 * 1024
	transportToolDiffCountLimit     = 8

	transportTextTruncationSuffix = "\n...[truncated]"
)

func NormalizeEventForTransport(event appwire.Event) appwire.Event {
	normalized := event

	if event.MessagePart != nil {
		part := *event.MessagePart
		part.ACP = nil
		part.App.FullText = ""
		normalized.MessagePart = &part
	}

	if event.Tool != nil {
		tool := *event.Tool
		tool.ACP = nil

		app := tool.App
		if app.Input != nil {
			app.Input = cloneToolInput(app.Input)
			app.Input.RawInputJSON, app.InputTruncated = truncateStringBytes(
				app.Input.RawInputJSON,
				transportToolInputPreviewBytes,
			)
			if app.Input.RawInputJSON == "" && app.Input.Description == "" && app.Input.Command == nil &&
				app.Input.FilePath == "" && app.Input.SourcePath == "" && app.Input.TargetPath == "" &&
				app.Input.Pattern == "" && app.Input.URL == "" && app.Input.Mode == "" && app.Input.Edit == nil {
				app.Input = nil
			}
		}

		app.Output, app.OutputTruncated = truncateStringBytes(
			app.Output,
			transportToolOutputPreviewBytes,
		)
		app.Error, app.ErrorTruncated = truncateStringBytes(
			app.Error,
			transportToolErrorPreviewBytes,
		)
		app.Diffs, app.DiffsTruncated = normalizeToolDiffs(app.Diffs)

		tool.App = app
		normalized.Tool = &tool
	}

	return normalized
}

func cloneToolInput(input *appwire.ToolInput) *appwire.ToolInput {
	if input == nil {
		return nil
	}
	cloned := *input
	if input.Command != nil {
		command := *input.Command
		command.Argv = append([]string(nil), input.Command.Argv...)
		cloned.Command = &command
	}
	if input.Edit != nil {
		edit := *input.Edit
		cloned.Edit = &edit
	}
	return &cloned
}

func normalizeToolDiffs(diffs []appwire.ToolDiff) ([]appwire.ToolDiff, bool) {
	if len(diffs) == 0 {
		return nil, false
	}
	truncated := false
	if len(diffs) > transportToolDiffCountLimit {
		diffs = diffs[:transportToolDiffCountLimit]
		truncated = true
	}

	normalized := make([]appwire.ToolDiff, 0, len(diffs))
	for _, diff := range diffs {
		next := diff
		if diff.OldText != nil {
			oldText, didTruncate := truncateStringBytes(*diff.OldText, transportToolDiffTextMaxBytes)
			if didTruncate {
				truncated = true
			}
			next.OldText = &oldText
		}
		next.NewText, truncated = truncateAndMergeFlag(
			diff.NewText,
			transportToolDiffTextMaxBytes,
			truncated,
		)
		normalized = append(normalized, next)
	}
	return normalized, truncated
}

func truncateAndMergeFlag(value string, maxBytes int, truncated bool) (string, bool) {
	next, didTruncate := truncateStringBytes(value, maxBytes)
	return next, truncated || didTruncate
}

func truncateStringBytes(value string, maxBytes int) (string, bool) {
	if value == "" || maxBytes <= 0 || len(value) <= maxBytes {
		return value, false
	}
	if maxBytes <= len(transportTextTruncationSuffix) {
		return transportTextTruncationSuffix[:maxBytes], true
	}
	limit := maxBytes - len(transportTextTruncationSuffix)
	for limit > 0 && (value[limit]&0xC0) == 0x80 {
		limit--
	}
	if limit <= 0 {
		limit = maxBytes - len(transportTextTruncationSuffix)
	}
	return value[:limit] + transportTextTruncationSuffix, true
}
