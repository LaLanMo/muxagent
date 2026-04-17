package gitstatus

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"strconv"
	"strings"
)

// unbornHeadSentinel is the value git status porcelain v2 writes for
// `branch.oid` when there is no HEAD yet (empty repo).
const unbornHeadSentinel = "(initial)"

type parsedStatus struct {
	Branch   string
	Detached bool
	Upstream string
	Ahead    int
	Behind   int
	Head     string

	Staged     []FileChange
	Unstaged   []FileChange
	Untracked  []FileChange
	Conflicted []FileChange
}

// parsePorcelainV2 parses the output of
// `git status --porcelain=v2 --branch -z`.
//
// Layout:
//   - Header lines prefixed with "# ":
//     "# branch.oid <sha>|(initial)"
//     "# branch.head <short-name>|(detached)"
//     "# branch.upstream <short-name>"
//     "# branch.ab +<ahead> -<behind>"
//   - Tracked entries:
//     "1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>"
//     "2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <Xscore> <path>\x00<origPath>"
//   - Unmerged entries:
//     "u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>"
//   - Untracked: "? <path>"
//   - Ignored:   "! <path>" (we ask for --ignored=no, so absent)
//
// Records are separated by \x00 (because of -z). Each record starts with a
// line-type byte (1/2/u/?/!/#) followed by " ".
func parsePorcelainV2(raw []byte) (parsedStatus, error) {
	ps := parsedStatus{
		Staged:     make([]FileChange, 0),
		Unstaged:   make([]FileChange, 0),
		Untracked:  make([]FileChange, 0),
		Conflicted: make([]FileChange, 0),
	}

	scanner := bufio.NewScanner(bytes.NewReader(raw))
	scanner.Buffer(make([]byte, 64*1024), 4*1024*1024)
	scanner.Split(splitOnNUL)

	for scanner.Scan() {
		rec := scanner.Bytes()
		if len(rec) == 0 {
			continue
		}
		switch rec[0] {
		case '#':
			parseHeader(rec, &ps)
		case '1':
			if err := parseType1(rec, &ps); err != nil {
				return ps, err
			}
		case '2':
			// Rename/copy entry. The origPath follows in the next NUL-delimited record.
			if !scanner.Scan() {
				return ps, errors.New("truncated rename record")
			}
			origPath := string(scanner.Bytes())
			if err := parseType2(rec, origPath, &ps); err != nil {
				return ps, err
			}
		case 'u':
			if err := parseUnmerged(rec, &ps); err != nil {
				return ps, err
			}
		case '?':
			if len(rec) > 2 {
				ps.Untracked = append(ps.Untracked, FileChange{
					Path:   string(rec[2:]),
					XY:     "??",
					Bucket: BucketUntracked,
				})
			}
		case '!':
			// ignored; we pass --ignored=no but be defensive.
		}
	}
	if err := scanner.Err(); err != nil {
		return ps, err
	}
	return ps, nil
}

func splitOnNUL(data []byte, atEOF bool) (int, []byte, error) {
	if atEOF && len(data) == 0 {
		return 0, nil, nil
	}
	if idx := bytes.IndexByte(data, 0); idx >= 0 {
		return idx + 1, data[:idx], nil
	}
	if atEOF {
		return len(data), data, nil
	}
	return 0, nil, nil
}

func parseHeader(rec []byte, ps *parsedStatus) {
	// rec starts with "# ".
	line := string(rec)
	if !strings.HasPrefix(line, "# ") {
		return
	}
	body := line[2:]
	switch {
	case strings.HasPrefix(body, "branch.oid "):
		ps.Head = strings.TrimSpace(strings.TrimPrefix(body, "branch.oid "))
	case strings.HasPrefix(body, "branch.head "):
		name := strings.TrimSpace(strings.TrimPrefix(body, "branch.head "))
		if name == "(detached)" {
			ps.Detached = true
			ps.Branch = ""
		} else {
			ps.Detached = false
			ps.Branch = name
		}
	case strings.HasPrefix(body, "branch.upstream "):
		ps.Upstream = strings.TrimSpace(strings.TrimPrefix(body, "branch.upstream "))
	case strings.HasPrefix(body, "branch.ab "):
		ab := strings.TrimSpace(strings.TrimPrefix(body, "branch.ab "))
		fields := strings.Fields(ab)
		for _, f := range fields {
			if len(f) < 2 {
				continue
			}
			sign := f[0]
			n, err := strconv.Atoi(f[1:])
			if err != nil {
				continue
			}
			switch sign {
			case '+':
				ps.Ahead = n
			case '-':
				ps.Behind = n
			}
		}
	}
}

// parseType1 handles ordinary tracked entries.
// Fields (space-separated): XY sub mH mI mW hH hI path
func parseType1(rec []byte, ps *parsedStatus) error {
	// rec[0] is '1', rec[1] is ' '. Strip prefix.
	body := rec[2:]
	// Split into 8 fields; the last field is the path (may contain spaces).
	fields := splitFieldsN(body, 8)
	if len(fields) < 8 {
		return fmt.Errorf("porcelain v2 type-1 record has %d fields, want 8", len(fields))
	}
	xy := fields[0]
	path := fields[7]
	appendTrackedChange(ps, string(xy), string(path), "")
	return nil
}

// parseType2 handles rename/copy entries. The path field is <Xscore> <path>
// and the next NUL-delimited record is origPath.
func parseType2(rec []byte, origPath string, ps *parsedStatus) error {
	body := rec[2:]
	fields := splitFieldsN(body, 9)
	if len(fields) < 9 {
		return fmt.Errorf("porcelain v2 type-2 record has %d fields, want 9", len(fields))
	}
	xy := fields[0]
	path := fields[8]
	appendTrackedChange(ps, string(xy), string(path), origPath)
	return nil
}

// parseUnmerged handles 'u' lines. Last field is the path.
func parseUnmerged(rec []byte, ps *parsedStatus) error {
	body := rec[2:]
	fields := splitFieldsN(body, 10)
	if len(fields) < 10 {
		return fmt.Errorf("porcelain v2 unmerged record has %d fields, want 10", len(fields))
	}
	xy := fields[0]
	path := fields[9]
	ps.Conflicted = append(ps.Conflicted, FileChange{
		Path:   string(path),
		XY:     string(xy),
		Bucket: BucketConflicted,
	})
	return nil
}

// splitFieldsN splits body on ASCII space, keeping the final field intact
// after n-1 splits so paths containing spaces survive.
func splitFieldsN(body []byte, n int) [][]byte {
	out := make([][]byte, 0, n)
	rest := body
	for i := 0; i < n-1; i++ {
		sp := bytes.IndexByte(rest, ' ')
		if sp < 0 {
			out = append(out, rest)
			return out
		}
		out = append(out, rest[:sp])
		rest = rest[sp+1:]
	}
	out = append(out, rest)
	return out
}

// appendTrackedChange interprets the XY status code and files the change in
// the right bucket(s). A file can show up in both staged and unstaged when
// both X and Y are non-"." non-"?" non-" " — we file separate FileChange
// entries in that case, matching how the desktop will want to show them.
func appendTrackedChange(ps *parsedStatus, xy, path, orig string) {
	if len(xy) < 2 {
		return
	}
	x := xy[0]
	y := xy[1]
	if x != '.' && x != ' ' && x != '?' {
		ps.Staged = append(ps.Staged, FileChange{
			Path:     path,
			OrigPath: orig,
			XY:       xy,
			Bucket:   BucketStaged,
		})
	}
	if y != '.' && y != ' ' && y != '?' {
		ps.Unstaged = append(ps.Unstaged, FileChange{
			Path:     path,
			OrigPath: orig,
			XY:       xy,
			Bucket:   BucketUnstaged,
		})
	}
}

// parseWorktreePorcelain parses `git worktree list --porcelain`.
//
// Format: paragraph-separated (blank line) records, each with key[space value]
// lines. Keys we care about: worktree <path>, HEAD <sha>, branch <refname>,
// detached, locked [reason], prunable [reason].
func parseWorktreePorcelain(raw []byte) []WorktreeEntry {
	var out []WorktreeEntry
	scanner := bufio.NewScanner(bytes.NewReader(raw))
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)
	var cur WorktreeEntry
	have := false
	flush := func() {
		if have {
			out = append(out, cur)
		}
		cur = WorktreeEntry{}
		have = false
	}
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			flush()
			continue
		}
		have = true
		key, value, _ := cutFirstSpace(line)
		switch key {
		case "worktree":
			cur.Path = value
		case "HEAD":
			cur.Head = value
		case "branch":
			// value looks like "refs/heads/<name>".
			cur.Branch = strings.TrimPrefix(value, "refs/heads/")
			cur.Detached = false
		case "detached":
			cur.Detached = true
		case "locked":
			cur.Locked = true
		case "prunable":
			cur.Prunable = true
		}
	}
	flush()
	return out
}

func cutFirstSpace(s string) (string, string, bool) {
	return strings.Cut(s, " ")
}
