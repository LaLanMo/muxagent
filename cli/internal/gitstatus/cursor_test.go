package gitstatus

import (
	"testing"
)

func TestEncodeDecodeCursor(t *testing.T) {
	c := fileCursor{Bucket: string(BucketUntracked), Path: "node_modules/foo.js"}
	enc := encodeFileCursor(c)
	if enc == "" {
		t.Fatal("empty encoding")
	}
	got, ok := decodeFileCursor(enc)
	if !ok || got != c {
		t.Fatalf("round trip mismatch: got=%+v ok=%v", got, ok)
	}
	if _, ok := decodeFileCursor(""); ok {
		t.Fatal("empty cursor should decode to not-ok")
	}
	if _, ok := decodeFileCursor("not-base64 !!!"); ok {
		t.Fatal("malformed cursor should decode to not-ok")
	}
	if _, ok := decodeFileCursor("aGVsbG8"); ok {
		// "hello" is valid base64 but not valid JSON.
		t.Fatal("non-JSON cursor should decode to not-ok")
	}
}

func TestPaginateFilesSpansAllBuckets(t *testing.T) {
	ps := parsedStatus{
		Staged: []FileChange{
			{Path: "a.txt", Bucket: BucketStaged},
		},
		Unstaged: []FileChange{
			{Path: "b.txt", Bucket: BucketUnstaged},
			{Path: "c.txt", Bucket: BucketUnstaged},
		},
		Untracked: []FileChange{
			{Path: "new1.txt", Bucket: BucketUntracked},
			{Path: "new2.txt", Bucket: BucketUntracked},
			{Path: "new3.txt", Bucket: BucketUntracked},
		},
		Conflicted: []FileChange{},
	}

	var collected []string
	cursor := ""
	for pages := 0; pages < 10; pages++ {
		page, next := paginateFiles(ps, cursor, 2)
		for _, fc := range page {
			collected = append(collected, fc.Path)
		}
		if next == "" {
			break
		}
		cursor = next
	}

	want := []string{"a.txt", "b.txt", "c.txt", "new1.txt", "new2.txt", "new3.txt"}
	if len(collected) != len(want) {
		t.Fatalf("collected=%v want=%v", collected, want)
	}
	for i, p := range want {
		if collected[i] != p {
			t.Fatalf("collected[%d]=%q want=%q (all=%v)", i, collected[i], p, collected)
		}
	}
}

func TestPaginateFilesHandlesMalformedCursor(t *testing.T) {
	ps := parsedStatus{
		Staged: []FileChange{
			{Path: "a.txt", Bucket: BucketStaged},
			{Path: "b.txt", Bucket: BucketStaged},
		},
	}
	page, next := paginateFiles(ps, "not-a-valid-cursor", 10)
	if len(page) != 2 || page[0].Path != "a.txt" || page[1].Path != "b.txt" {
		t.Fatalf("malformed cursor should produce first page, got=%+v", page)
	}
	if next != "" {
		t.Fatalf("single-page result should have no next cursor, got=%q", next)
	}
}

func TestPaginateFilesReturnsEmptyWhenCursorPastEnd(t *testing.T) {
	ps := parsedStatus{
		Staged: []FileChange{{Path: "a.txt", Bucket: BucketStaged}},
	}
	cursor := encodeFileCursor(fileCursor{Bucket: string(BucketConflicted), Path: "zzz"})
	page, next := paginateFiles(ps, cursor, 10)
	if len(page) != 0 || next != "" {
		t.Fatalf("cursor past end should produce empty page, got page=%v next=%q", page, next)
	}
}
