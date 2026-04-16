package worktree

import (
	"crypto/sha256"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/LaLanMo/muxagent/cli/internal/privdir"
)

func canonicalExistingPath(path string) (string, error) {
	if path == "" {
		return "", nil
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	resolved, err := filepath.EvalSymlinks(abs)
	if err != nil {
		return "", err
	}
	return filepath.Clean(resolved), nil
}

// FindRepoRoot returns the git repo root for a given path.
func FindRepoRoot(cwd string) (string, error) {
	cmd := exec.Command("git", "-C", cwd, "rev-parse", "--show-toplevel")
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("not a git repository: %s", cwd)
	}
	return strings.TrimSpace(string(out)), nil
}

func BranchName(wtID string) string {
	return "muxagent/" + wtID
}

func NormalizeRepoRelativePath(repoRoot, cwd string) (string, error) {
	canonicalRepoRoot, err := canonicalExistingPath(repoRoot)
	if err != nil {
		return "", fmt.Errorf("canonicalize repo root: %w", err)
	}
	canonicalCWD, err := canonicalExistingPath(cwd)
	if err != nil {
		return "", fmt.Errorf("canonicalize cwd: %w", err)
	}
	relPath, err := filepath.Rel(canonicalRepoRoot, canonicalCWD)
	if err != nil {
		return "", err
	}
	relPath = filepath.Clean(relPath)
	if relPath == ".." || strings.HasPrefix(relPath, ".."+string(os.PathSeparator)) {
		return "", fmt.Errorf("cwd %q escapes repo root %q", canonicalCWD, canonicalRepoRoot)
	}
	return relPath, nil
}

func WorktreeCWDPath(worktreePath, relativeCWD string) (string, error) {
	relPath, err := cleanRelativeCWD(relativeCWD)
	if err != nil {
		return "", err
	}
	if relPath == "." {
		return filepath.Clean(worktreePath), nil
	}
	return filepath.Join(filepath.Clean(worktreePath), relPath), nil
}

func ResolveWorktreeCWD(worktreePath, relativeCWD string) (string, error) {
	canonicalRoot, err := canonicalExistingPath(worktreePath)
	if err != nil {
		return "", fmt.Errorf("saved worktree path unavailable: %w", err)
	}

	relPath, err := cleanRelativeCWD(relativeCWD)
	if err != nil {
		return "", err
	}
	switch relPath {
	case ".":
		info, err := os.Stat(canonicalRoot)
		if err != nil {
			return "", fmt.Errorf("saved worktree cwd unavailable: %w", err)
		}
		if !info.IsDir() {
			return "", fmt.Errorf("saved worktree cwd is not a directory: %s", canonicalRoot)
		}
		return canonicalRoot, nil
	}
	target := filepath.Join(canonicalRoot, relPath)
	info, err := os.Stat(target)
	if err != nil {
		return "", fmt.Errorf("saved worktree cwd unavailable: %w", err)
	}
	if !info.IsDir() {
		return "", fmt.Errorf("saved worktree cwd is not a directory: %s", target)
	}
	return target, nil
}

func ResolveMappedCWD(mapping *Mapping) (string, error) {
	if mapping == nil {
		return "", errors.New("saved worktree mapping unavailable")
	}
	return ResolveWorktreeCWD(mapping.WorktreePath, mapping.RelativeCWD)
}

func Cleanup(repoRoot, worktreePath, branchName string) error {
	var cleanupErr error

	if strings.TrimSpace(worktreePath) != "" {
		if err := Remove(repoRoot, worktreePath); err != nil {
			cleanupErr = errors.Join(cleanupErr, err)
		}
	}
	if strings.TrimSpace(branchName) != "" {
		cmd := exec.Command("git", "-C", repoRoot, "branch", "-D", branchName)
		if out, err := cmd.CombinedOutput(); err != nil {
			cleanupErr = errors.Join(cleanupErr, fmt.Errorf("git branch -D: %s: %w", strings.TrimSpace(string(out)), err))
		}
	}
	return cleanupErr
}

func Remove(repoRoot, worktreePath string) error {
	cmd := exec.Command("git", "-C", repoRoot, "worktree", "remove", "--force", worktreePath)
	if out, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("git worktree remove: %s: %w", strings.TrimSpace(string(out)), err)
	}
	return nil
}

func cleanRelativeCWD(relativeCWD string) (string, error) {
	relPath := filepath.Clean(strings.TrimSpace(relativeCWD))
	switch relPath {
	case "", ".":
		return ".", nil
	}
	if filepath.IsAbs(relPath) || relPath == ".." || strings.HasPrefix(relPath, ".."+string(os.PathSeparator)) {
		return "", fmt.Errorf("saved worktree cwd is invalid: %s", relativeCWD)
	}
	return relPath, nil
}

// Create creates a git worktree at ~/.muxagent/worktrees/<repoHash>/<wtID>/
// with branch muxagent/<wtID>, based on HEAD.
func Create(repoRoot string, wtID string) (string, error) {
	return CreateFromRef(repoRoot, wtID, "HEAD")
}

// CreateFromRef creates a git worktree at ~/.muxagent/worktrees/<repoHash>/<wtID>/
// with branch muxagent/<wtID>, based on the requested ref.
func CreateFromRef(repoRoot string, wtID string, ref string) (string, error) {
	h := sha256.Sum256([]byte(repoRoot))
	repoHash := fmt.Sprintf("%x", h[:4]) // first 8 hex chars

	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("user home dir: %w", err)
	}

	wtPath := filepath.Join(home, ".muxagent", "worktrees", repoHash, wtID)
	if err := privdir.EnsureWithin(filepath.Dir(wtPath), filepath.Join(home, ".muxagent")); err != nil {
		return "", fmt.Errorf("mkdir: %w", err)
	}

	branchName := BranchName(wtID)
	cmd := exec.Command("git", "-C", repoRoot, "worktree", "add", "-b", branchName, wtPath, ref)
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("git worktree add: %s: %w", strings.TrimSpace(string(out)), err)
	}

	return wtPath, nil
}

func HeadCommit(checkoutRoot string) (string, error) {
	cmd := exec.Command("git", "-C", checkoutRoot, "rev-parse", "HEAD")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("git rev-parse HEAD: %s: %w", strings.TrimSpace(string(out)), err)
	}
	return strings.TrimSpace(string(out)), nil
}

func DirtyChangeCount(checkoutRoot string) (int, error) {
	cmd := exec.Command("git", "-C", checkoutRoot, "status", "--porcelain")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return 0, fmt.Errorf("git status --porcelain: %s: %w", strings.TrimSpace(string(out)), err)
	}
	trimmed := strings.TrimSpace(string(out))
	if trimmed == "" {
		return 0, nil
	}
	return len(strings.Split(trimmed, "\n")), nil
}

func MirrorCheckout(sourceRoot, destinationRoot string, excludePrefixes ...string) error {
	sourceRoot, err := canonicalExistingPath(sourceRoot)
	if err != nil {
		return fmt.Errorf("canonicalize source checkout: %w", err)
	}
	destinationRoot, err = canonicalExistingPath(destinationRoot)
	if err != nil {
		return fmt.Errorf("canonicalize destination checkout: %w", err)
	}
	exclusions, err := normalizeMirrorExcludePrefixes(excludePrefixes)
	if err != nil {
		return err
	}

	sourceEntries := map[string]struct{}{}
	if err := filepath.Walk(sourceRoot, func(sourcePath string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		relPath, err := filepath.Rel(sourceRoot, sourcePath)
		if err != nil {
			return err
		}
		if relPath == "." {
			return nil
		}
		if isGitMetadataPath(relPath) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if shouldExcludeMirrorPath(relPath, exclusions) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		sourceEntries[relPath] = struct{}{}
		return mirrorEntry(sourcePath, filepath.Join(destinationRoot, relPath), info)
	}); err != nil {
		return fmt.Errorf("mirror checkout into %q: %w", destinationRoot, err)
	}

	destinationEntries := make([]string, 0)
	if err := filepath.Walk(destinationRoot, func(destinationPath string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		relPath, err := filepath.Rel(destinationRoot, destinationPath)
		if err != nil {
			return err
		}
		if relPath == "." {
			return nil
		}
		if isGitMetadataPath(relPath) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if shouldExcludeMirrorPath(relPath, exclusions) {
			if info.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		destinationEntries = append(destinationEntries, relPath)
		return nil
	}); err != nil {
		return fmt.Errorf("scan mirrored checkout %q: %w", destinationRoot, err)
	}
	sort.Slice(destinationEntries, func(i, j int) bool {
		return pathDepth(destinationEntries[i]) > pathDepth(destinationEntries[j])
	})
	for _, relPath := range destinationEntries {
		if _, ok := sourceEntries[relPath]; ok {
			continue
		}
		if err := os.RemoveAll(filepath.Join(destinationRoot, relPath)); err != nil {
			return fmt.Errorf("remove stale checkout path %q: %w", relPath, err)
		}
	}
	return nil
}

func mirrorEntry(sourcePath, destinationPath string, info os.FileInfo) error {
	switch mode := info.Mode(); {
	case mode.IsDir():
		if err := ensureDirectory(destinationPath, mode.Perm()); err != nil {
			return err
		}
	case mode&os.ModeSymlink != 0:
		target, err := os.Readlink(sourcePath)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(destinationPath), 0o755); err != nil {
			return err
		}
		if err := os.RemoveAll(destinationPath); err != nil {
			return err
		}
		if err := os.Symlink(target, destinationPath); err != nil {
			return err
		}
	case mode.IsRegular():
		if err := copyFile(sourcePath, destinationPath, mode.Perm()); err != nil {
			return err
		}
	default:
		return fmt.Errorf("unsupported file mode %s at %q", mode.String(), sourcePath)
	}
	return nil
}

func ensureDirectory(path string, mode os.FileMode) error {
	info, err := os.Lstat(path)
	switch {
	case err == nil && !info.IsDir():
		if err := os.RemoveAll(path); err != nil {
			return err
		}
	case err != nil && !errors.Is(err, os.ErrNotExist):
		return err
	}
	if err := os.MkdirAll(path, mode); err != nil {
		return err
	}
	return os.Chmod(path, mode)
}

func copyFile(sourcePath, destinationPath string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(destinationPath), 0o755); err != nil {
		return err
	}
	if err := os.RemoveAll(destinationPath); err != nil {
		return err
	}
	source, err := os.Open(sourcePath)
	if err != nil {
		return err
	}
	defer source.Close()

	destination, err := os.OpenFile(destinationPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, mode)
	if err != nil {
		return err
	}
	defer destination.Close()

	if _, err := io.Copy(destination, source); err != nil {
		return err
	}
	return destination.Chmod(mode)
}

func isGitMetadataPath(relPath string) bool {
	return relPath == ".git" || strings.HasPrefix(relPath, ".git"+string(os.PathSeparator))
}

func normalizeMirrorExcludePrefixes(prefixes []string) ([]string, error) {
	if len(prefixes) == 0 {
		return nil, nil
	}
	cleaned := make([]string, 0, len(prefixes))
	for _, prefix := range prefixes {
		next, err := cleanRelativeCWD(prefix)
		if err != nil {
			return nil, fmt.Errorf("normalize mirror exclusion %q: %w", prefix, err)
		}
		if next == "." {
			return nil, errors.New("mirror exclusion cannot target the checkout root")
		}
		cleaned = append(cleaned, next)
	}
	sort.Strings(cleaned)
	return cleaned, nil
}

func shouldExcludeMirrorPath(relPath string, exclusions []string) bool {
	for _, exclusion := range exclusions {
		if relPath == exclusion || strings.HasPrefix(relPath, exclusion+string(os.PathSeparator)) {
			return true
		}
	}
	return false
}

func pathDepth(relPath string) int {
	return strings.Count(relPath, string(os.PathSeparator))
}
