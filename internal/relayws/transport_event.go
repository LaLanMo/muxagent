package relayws

import "github.com/LaLanMo/muxagent-cli/internal/appwire"

const (
	defaultEventBufferByteBudget = 2 * 1024 * 1024

	relayToolOutputPreviewBytes = 64 * 1024
	relayToolErrorPreviewBytes  = 64 * 1024
	relayToolInputPreviewBytes  = 8 * 1024
	relayToolDiffTextMaxBytes   = 16 * 1024
	relayToolDiffCountLimit     = 8

	relayTextTruncationSuffix = "\n...[truncated]"
)

func normalizeEventForTransport(event appwire.Event) appwire.Event {
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
				relayToolInputPreviewBytes,
			)
			if app.Input.RawInputJSON == "" && app.Input.Description == "" && app.Input.Command == nil &&
				app.Input.FilePath == "" && app.Input.SourcePath == "" && app.Input.TargetPath == "" &&
				app.Input.Pattern == "" && app.Input.URL == "" && app.Input.Mode == "" && app.Input.Edit == nil {
				app.Input = nil
			}
		}

		app.Output, app.OutputTruncated = truncateStringBytes(
			app.Output,
			relayToolOutputPreviewBytes,
		)
		app.Error, app.ErrorTruncated = truncateStringBytes(
			app.Error,
			relayToolErrorPreviewBytes,
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
	if len(diffs) > relayToolDiffCountLimit {
		diffs = diffs[:relayToolDiffCountLimit]
		truncated = true
	}

	normalized := make([]appwire.ToolDiff, 0, len(diffs))
	for _, diff := range diffs {
		next := diff
		if diff.OldText != nil {
			oldText, didTruncate := truncateStringBytes(*diff.OldText, relayToolDiffTextMaxBytes)
			if didTruncate {
				truncated = true
			}
			next.OldText = &oldText
		}
		next.NewText, truncated = truncateAndMergeFlag(
			diff.NewText,
			relayToolDiffTextMaxBytes,
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
	if maxBytes <= len(relayTextTruncationSuffix) {
		return relayTextTruncationSuffix[:maxBytes], true
	}
	limit := maxBytes - len(relayTextTruncationSuffix)
	for limit > 0 && (value[limit]&0xC0) == 0x80 {
		limit--
	}
	if limit <= 0 {
		limit = maxBytes - len(relayTextTruncationSuffix)
	}
	return value[:limit] + relayTextTruncationSuffix, true
}
