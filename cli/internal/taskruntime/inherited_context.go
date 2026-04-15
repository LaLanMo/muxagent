package taskruntime

import (
	"context"
	"fmt"
	"os"
	"strings"

	"github.com/LaLanMo/muxagent/cli/internal/taskdomain"
	"github.com/LaLanMo/muxagent/cli/internal/taskstore"
)

type inheritedContext struct {
	DirectParent     *inheritedTaskReference
	EarlierAncestors []inheritedTaskReference
}

type inheritedTaskReference struct {
	Description string
	TaskDir     string
}

func (s *Service) loadInheritedContext(ctx context.Context, task taskdomain.Task) (*inheritedContext, error) {
	parentTaskID, err := s.store.GetFollowUpParentTaskID(ctx, task.ID)
	if err != nil {
		return nil, err
	}
	if parentTaskID == "" {
		return nil, nil
	}

	parentTask, err := s.store.GetTask(ctx, parentTaskID)
	if err != nil {
		return nil, err
	}

	ancestorIDs, err := s.store.ListAncestorTaskIDs(ctx, task.ID)
	if err != nil {
		return nil, err
	}
	ancestorReferences := make([]string, 0, len(ancestorIDs))
	ancestorTasks := make([]inheritedTaskReference, 0, len(ancestorIDs))
	for _, ancestorTaskID := range ancestorIDs {
		if ancestorTaskID == parentTaskID {
			continue
		}
		ancestorTask, err := s.store.GetTask(ctx, ancestorTaskID)
		if err != nil {
			return nil, err
		}
		ancestorReferences = append(ancestorReferences, formatAncestorTaskReference(ancestorTask))
		ancestorTasks = append(ancestorTasks, makeInheritedTaskReference(ancestorTask))
	}

	return &inheritedContext{
		DirectParent:     inheritedTaskReferencePtr(makeInheritedTaskReference(parentTask)),
		EarlierAncestors: ancestorTasks,
	}, nil
}

func (s *Service) loadInheritedInputArtifacts(ctx context.Context, task taskdomain.Task) ([]string, error) {
	parentTaskID, err := s.store.GetFollowUpParentTaskID(ctx, task.ID)
	if err != nil {
		return nil, err
	}
	if parentTaskID == "" {
		return nil, nil
	}
	parentTask, err := s.store.GetTask(ctx, parentTaskID)
	if err != nil {
		return nil, err
	}
	parentRuns, err := s.store.ListNodeRunsByTask(ctx, parentTaskID)
	if err != nil {
		return nil, err
	}
	return existingArtifactPaths(resolveArtifactPaths(parentTask, parentRuns)), nil
}

func completedRuns(runs []taskdomain.NodeRun) []taskdomain.NodeRun {
	completed := make([]taskdomain.NodeRun, 0, len(runs))
	for _, run := range runs {
		if run.Status == taskdomain.NodeRunDone {
			completed = append(completed, run)
		}
	}
	return completed
}

func existingArtifactPaths(paths []string) []string {
	seen := map[string]struct{}{}
	reversed := make([]string, 0, len(paths))
	for i := len(paths) - 1; i >= 0; i-- {
		path := strings.TrimSpace(paths[i])
		if path == "" {
			continue
		}
		if _, ok := seen[path]; ok {
			continue
		}
		if _, err := os.Stat(path); err != nil {
			continue
		}
		seen[path] = struct{}{}
		reversed = append(reversed, path)
	}
	result := make([]string, 0, len(reversed))
	for i := len(reversed) - 1; i >= 0; i-- {
		result = append(result, reversed[i])
	}
	return result
}

func formatAncestorTaskReference(task taskdomain.Task) string {
	description := normalizeInheritedTaskDescription(task.Description)
	return strings.Join([]string{
		fmt.Sprintf("- %s", description),
		fmt.Sprintf("  Task directory: %s", taskstore.TaskDir(task.WorkDir, task.ID)),
	}, "\n")
}

func makeInheritedTaskReference(task taskdomain.Task) inheritedTaskReference {
	return inheritedTaskReference{
		Description: normalizeInheritedTaskDescription(task.Description),
		TaskDir:     taskstore.TaskDir(task.WorkDir, task.ID),
	}
}

func inheritedTaskReferencePtr(ref inheritedTaskReference) *inheritedTaskReference {
	return &ref
}

func normalizeInheritedTaskDescription(description string) string {
	description = strings.TrimSpace(description)
	if description == "" {
		return "(no description)"
	}
	return description
}

func resolveArtifactPaths(task taskdomain.Task, runs []taskdomain.NodeRun) []string {
	resolved := make([]string, 0)
	for _, run := range runs {
		if run.Status != taskdomain.NodeRunDone {
			continue
		}
		for _, rawPath := range taskdomain.ArtifactPaths(run.Result) {
			path := strings.TrimSpace(rawPath)
			if path == "" {
				continue
			}
			path = taskstore.ResolveRunPath(task.WorkDir, task.ID, run.ID, path)
			resolved = append(resolved, path)
		}
	}
	return resolved
}

func mergeArtifactPaths(current, inherited []string) []string {
	merged := make([]string, 0, len(current)+len(inherited))
	seen := map[string]struct{}{}
	for _, group := range [][]string{current, inherited} {
		for _, path := range group {
			path = strings.TrimSpace(path)
			if path == "" {
				continue
			}
			if _, ok := seen[path]; ok {
				continue
			}
			seen[path] = struct{}{}
			merged = append(merged, path)
		}
	}
	return merged
}
