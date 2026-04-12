package taskexecutor

import (
	"bytes"
	"encoding/json"
	"strings"
)

type MCPOutputBlockType string

const (
	MCPOutputBlockTypeText  MCPOutputBlockType = "text"
	MCPOutputBlockTypeImage MCPOutputBlockType = "image"
	MCPOutputBlockTypeJSON  MCPOutputBlockType = "json"
	MCPOutputBlockTypeRaw   MCPOutputBlockType = "raw"
)

type MCPOutputBlock struct {
	Type     MCPOutputBlockType `json:"type"`
	Label    string             `json:"label,omitempty"`
	Text     string             `json:"text,omitempty"`
	JSON     string             `json:"json,omitempty"`
	DataURL  string             `json:"data_url,omitempty"`
	MIMEType string             `json:"mime_type,omitempty"`
}

type MCPToolPayload struct {
	Server                string           `json:"server,omitempty"`
	Tool                  string           `json:"tool,omitempty"`
	ArgumentsJSON         string           `json:"arguments_json,omitempty"`
	StructuredContentJSON string           `json:"structured_content_json,omitempty"`
	OutputBlocks          []MCPOutputBlock `json:"output_blocks,omitempty"`
	DebugJSON             string           `json:"debug_json,omitempty"`
}

type MCPToolCallParams struct {
	CallID            string
	ParentCallID      string
	Server            string
	Tool              string
	Status            ToolStatus
	DurationMS        int64
	Arguments         any
	Content           []any
	StructuredContent any
	ErrorText         string
}

func NewMCPToolCall(params MCPToolCallParams) ToolCall {
	payload := buildMCPToolPayload(params.Server, params.Tool, params.Arguments, params.Content, params.StructuredContent, params.Status, params.ErrorText)
	outputText := mcpOutputPreview(payload.OutputBlocks, payload.StructuredContentJSON)
	errorText := strings.TrimSpace(params.ErrorText)
	if errorText == "" && params.Status == ToolStatusFailed {
		errorText = outputText
	}
	return ToolCall{
		CallID:        strings.TrimSpace(params.CallID),
		ParentCallID:  strings.TrimSpace(params.ParentCallID),
		Name:          strings.TrimSpace(params.Tool),
		Kind:          ToolKindMCP,
		Title:         "MCP",
		Status:        params.Status,
		DurationMS:    params.DurationMS,
		InputSummary:  buildMCPInputSummary(params.Server, params.Tool),
		OutputText:    outputText,
		ErrorText:     errorText,
		RawOutputJSON: payload.DebugJSON,
		MCP:           payload,
	}
}

func buildMCPToolPayload(server, tool string, arguments any, content []any, structuredContent any, status ToolStatus, errorText string) *MCPToolPayload {
	payload := &MCPToolPayload{
		Server:                strings.TrimSpace(server),
		Tool:                  strings.TrimSpace(tool),
		ArgumentsJSON:         canonicalJSONValue(arguments),
		StructuredContentJSON: canonicalJSONValue(structuredContent),
		OutputBlocks:          normalizeMCPOutputBlocks(content),
	}
	payload.DebugJSON = canonicalJSONValue(map[string]any{
		"server":                 payload.Server,
		"tool":                   payload.Tool,
		"status":                 string(status),
		"block_count":            len(payload.OutputBlocks),
		"block_types":            mcpBlockTypes(payload.OutputBlocks),
		"mime_types":             mcpMIMETypes(payload.OutputBlocks),
		"has_structured_content": payload.StructuredContentJSON != "",
		"has_error":              strings.TrimSpace(errorText) != "" || status == ToolStatusFailed,
	})
	return payload
}

func buildMCPInputSummary(server, tool string) string {
	server = strings.TrimSpace(server)
	tool = strings.TrimSpace(tool)
	switch {
	case server != "" && tool != "":
		return server + "." + tool
	case tool != "":
		return tool
	default:
		return server
	}
}

func mcpOutputPreview(blocks []MCPOutputBlock, structuredContentJSON string) string {
	texts := make([]string, 0, len(blocks))
	for _, block := range blocks {
		if block.Type != MCPOutputBlockTypeText {
			continue
		}
		if text := collapseWhitespace(block.Text); text != "" {
			texts = append(texts, text)
		}
	}
	if len(texts) > 0 {
		return strings.Join(texts, "\n\n")
	}
	return collapseWhitespace(structuredContentJSON)
}

func normalizeMCPOutputBlocks(content []any) []MCPOutputBlock {
	blocks := make([]MCPOutputBlock, 0, len(content))
	for _, raw := range content {
		block, ok := normalizeMCPOutputBlock(raw)
		if !ok {
			continue
		}
		blocks = append(blocks, block)
	}
	return blocks
}

func normalizeMCPOutputBlock(raw any) (MCPOutputBlock, bool) {
	item, ok := raw.(map[string]any)
	if !ok || len(item) == 0 {
		return normalizeMCPFallbackBlock(raw, "content")
	}
	label := strings.TrimSpace(mcpAsString(item["type"]))
	switch label {
	case "text":
		text := strings.TrimSpace(mcpAsString(item["text"]))
		if text == "" {
			return MCPOutputBlock{}, false
		}
		return MCPOutputBlock{
			Type: MCPOutputBlockTypeText,
			Text: text,
		}, true
	case "image":
		data := strings.TrimSpace(mcpFirstNonEmpty(mcpAsString(item["data"]), mcpAsString(item["image_url"])))
		if data == "" {
			return normalizeMCPFallbackBlock(raw, label)
		}
		mimeType := strings.TrimSpace(mcpFirstNonEmpty(mcpAsString(item["mimeType"]), mcpAsString(item["mime_type"])))
		if !strings.HasPrefix(data, "data:") {
			if mimeType == "" {
				mimeType = "application/octet-stream"
			}
			data = "data:" + mimeType + ";base64," + data
		}
		return MCPOutputBlock{
			Type:     MCPOutputBlockTypeImage,
			DataURL:  data,
			MIMEType: mimeType,
		}, true
	default:
		return normalizeMCPFallbackBlock(raw, label)
	}
}

func normalizeMCPFallbackBlock(raw any, label string) (MCPOutputBlock, bool) {
	label = strings.TrimSpace(label)
	switch item := raw.(type) {
	case string:
		text := strings.TrimSpace(item)
		if text == "" {
			return MCPOutputBlock{}, false
		}
		return MCPOutputBlock{
			Type:  MCPOutputBlockTypeRaw,
			Label: mcpFirstNonEmpty(label, "content"),
			Text:  text,
		}, true
	default:
		jsonText := canonicalJSONValue(raw)
		if jsonText == "" {
			return MCPOutputBlock{}, false
		}
		return MCPOutputBlock{
			Type:  MCPOutputBlockTypeJSON,
			Label: mcpFirstNonEmpty(label, "content"),
			JSON:  jsonText,
		}, true
	}
}

func mcpBlockTypes(blocks []MCPOutputBlock) []string {
	seen := map[string]struct{}{}
	types := make([]string, 0, len(blocks))
	for _, block := range blocks {
		if block.Type == "" {
			continue
		}
		key := string(block.Type)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		types = append(types, key)
	}
	return types
}

func mcpMIMETypes(blocks []MCPOutputBlock) []string {
	seen := map[string]struct{}{}
	types := make([]string, 0, len(blocks))
	for _, block := range blocks {
		mimeType := strings.TrimSpace(block.MIMEType)
		if mimeType == "" {
			continue
		}
		if _, ok := seen[mimeType]; ok {
			continue
		}
		seen[mimeType] = struct{}{}
		types = append(types, mimeType)
	}
	return types
}

func canonicalJSONValue(value any) string {
	if value == nil {
		return ""
	}
	switch item := value.(type) {
	case string:
		text := strings.TrimSpace(item)
		if text == "" {
			return ""
		}
		if json.Valid([]byte(text)) {
			var compact bytes.Buffer
			if err := json.Compact(&compact, []byte(text)); err == nil {
				return compact.String()
			}
		}
		encoded, err := json.Marshal(text)
		if err != nil {
			return ""
		}
		return string(encoded)
	case json.RawMessage:
		return canonicalJSONValue(string(item))
	default:
		encoded, err := json.Marshal(value)
		if err != nil {
			return ""
		}
		return string(encoded)
	}
}

func mcpFirstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func mcpAsString(value any) string {
	text, _ := value.(string)
	return text
}
