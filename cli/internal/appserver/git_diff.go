package appserver

import (
	"context"
	"strings"
	"time"

	"github.com/LaLanMo/muxagent/cli/internal/gitdiff"
)

// buildFileDiff validates the checkout belongs to the workspace and returns a
// file-level patch for the given path + bucket.
func buildFileDiff(ctx context.Context, workspace workspaceRecord, checkoutPath, filePath, bucket string, now func() time.Time) (workspaceFileDiffResult, *rpcError) {
	if now == nil {
		now = time.Now
	}
	checkoutPath = strings.TrimSpace(checkoutPath)
	filePath = strings.TrimSpace(filePath)
	if checkoutPath == "" {
		return workspaceFileDiffResult{}, &rpcError{Code: errorCodeInvalidParams, Message: "checkout_path is required"}
	}
	if filePath == "" {
		return workspaceFileDiffResult{}, &rpcError{Code: errorCodeInvalidParams, Message: "file_path is required"}
	}

	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	if _, ok := validateCheckoutBelongs(ctx, workspace, checkoutPath); !ok {
		return workspaceFileDiffResult{}, &rpcError{
			Code:    errorCodeInvalidParams,
			Message: "checkout_path is not part of this workspace",
		}
	}

	patch, _ := gitdiff.FileDiff(ctx, checkoutPath, filePath, gitdiff.FileDiffOpts{
		Bucket: gitdiff.FileBucket(bucket),
	})

	return workspaceFileDiffResult{
		Diff:        patchToDTO(patch),
		CollectedAt: now().UTC(),
	}, nil
}

// buildCommitDiff returns the multi-file patch for one commit hash.
func buildCommitDiff(ctx context.Context, workspace workspaceRecord, checkoutPath, hash string, now func() time.Time) (workspaceCommitDiffResult, *rpcError) {
	if now == nil {
		now = time.Now
	}
	checkoutPath = strings.TrimSpace(checkoutPath)
	hash = strings.TrimSpace(hash)
	if checkoutPath == "" {
		return workspaceCommitDiffResult{}, &rpcError{Code: errorCodeInvalidParams, Message: "checkout_path is required"}
	}
	if hash == "" {
		return workspaceCommitDiffResult{}, &rpcError{Code: errorCodeInvalidParams, Message: "commit_hash is required"}
	}

	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	if _, ok := validateCheckoutBelongs(ctx, workspace, checkoutPath); !ok {
		return workspaceCommitDiffResult{}, &rpcError{
			Code:    errorCodeInvalidParams,
			Message: "checkout_path is not part of this workspace",
		}
	}

	patch, _ := gitdiff.CommitDiff(ctx, checkoutPath, hash, gitdiff.CommitDiffOpts{})

	return workspaceCommitDiffResult{
		Diff:        patchToDTO(patch),
		CollectedAt: now().UTC(),
	}, nil
}

func patchToDTO(p gitdiff.Patch) gitDiffDTO {
	dto := gitDiffDTO{
		Reachable:         p.Reachable,
		UnreachableReason: p.UnreachableReason,
		Patch:             p.Patch,
		Truncated:         p.Truncated,
		Binary:            p.Binary,
		FileCount:         p.FileCount,
		Subject:           p.Subject,
		Author:            p.Author,
		AuthorMail:        p.AuthorMail,
		Hash:              p.Hash,
	}
	if p.AuthoredAt != nil {
		dto.AuthoredAt = p.AuthoredAt
	}
	return dto
}
