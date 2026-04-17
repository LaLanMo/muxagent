package gitstatus

import (
	"encoding/base64"
	"encoding/json"
)

// fileCursor marks a position in the bucket-ordered file list. Callers pass
// an encoded form back to us to resume pagination; decode failures are
// tolerated and treated as an empty cursor.
type fileCursor struct {
	Bucket string `json:"b"`
	Path   string `json:"p"`
}

func encodeFileCursor(c fileCursor) string {
	b, err := json.Marshal(c)
	if err != nil {
		return ""
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

func decodeFileCursor(s string) (fileCursor, bool) {
	if s == "" {
		return fileCursor{}, false
	}
	raw, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return fileCursor{}, false
	}
	var c fileCursor
	if err := json.Unmarshal(raw, &c); err != nil {
		return fileCursor{}, false
	}
	return c, true
}

// bucketRank determines the global ordering: staged < unstaged < untracked < conflicted.
// Unknown values sort last, keeping stray cursors tolerable.
func bucketRank(b string) int {
	switch FileBucket(b) {
	case BucketStaged:
		return 0
	case BucketUnstaged:
		return 1
	case BucketUntracked:
		return 2
	case BucketConflicted:
		return 3
	}
	return 4
}

// paginateFiles flattens the four bucket slices in order and returns the page
// starting *after* the file pointed to by startCursor (exclusive), up to limit
// entries. It also returns the next cursor, or "" if the page was the last one.
func paginateFiles(ps parsedStatus, startCursor string, limit int) ([]FileChange, string) {
	buckets := [][]FileChange{ps.Staged, ps.Unstaged, ps.Untracked, ps.Conflicted}

	cursor, haveCursor := decodeFileCursor(startCursor)
	cursorRank := -1
	if haveCursor {
		cursorRank = bucketRank(cursor.Bucket)
	}

	out := make([]FileChange, 0, limit)
	for _, bucket := range buckets {
		for _, fc := range bucket {
			if haveCursor {
				rank := bucketRank(string(fc.Bucket))
				if rank < cursorRank {
					continue
				}
				if rank == cursorRank && fc.Path <= cursor.Path {
					continue
				}
			}
			if len(out) >= limit {
				// We already have `limit` entries and another one is
				// available — resume *after* the last emitted entry.
				last := out[len(out)-1]
				return out, encodeFileCursor(fileCursor{Bucket: string(last.Bucket), Path: last.Path})
			}
			out = append(out, fc)
		}
	}
	return out, ""
}
