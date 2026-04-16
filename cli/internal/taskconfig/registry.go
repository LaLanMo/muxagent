package taskconfig

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"

	appconfig "github.com/LaLanMo/muxagent/cli/internal/config"
	"github.com/LaLanMo/muxagent/cli/internal/privdir"
	"gopkg.in/yaml.v3"
)

const builtinDefaultAlias = "default"
const managedConfigFile = "config.yaml"
const managedDefaultBundleDir = builtinDefaultAlias
const managedBuiltinRevisionFile = ".muxagent-builtin-revision"
const taskConfigRootEnv = "MUXAGENT_TASKCONFIG_ROOT"

const DefaultAlias = builtinDefaultAlias

type Registry struct {
	DefaultAlias string          `json:"default_alias,omitempty"`
	Configs      []RegistryEntry `json:"configs,omitempty"`
}

type RegistryEntry struct {
	Alias     string `json:"alias"`
	Path      string `json:"path"`
	BuiltinID string `json:"starter_id,omitempty"` // JSON key kept for backward compat
}

type Catalog struct {
	DefaultAlias string
	Entries      []CatalogEntry
}

type CatalogEntry struct {
	Alias     string
	Path      string
	Config    *Config
	BuiltinID string
	Builtin   bool
}

func TaskConfigDir() (string, error) {
	root, err := taskConfigRootDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, "taskconfigs"), nil
}

func RegistryPath() (string, error) {
	root, err := taskConfigRootDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(root, "taskconfig.json"), nil
}

func taskConfigRootDir() (string, error) {
	if override := strings.TrimSpace(os.Getenv(taskConfigRootEnv)); override != "" {
		if filepath.IsAbs(override) {
			return filepath.Clean(override), nil
		}
		abs, err := filepath.Abs(override)
		if err != nil {
			return "", err
		}
		return filepath.Clean(abs), nil
	}
	if override, ok, err := appconfig.TaskHomeOverrideDir(); err != nil {
		return "", err
	} else if ok {
		return filepath.Join(override, "taskconfig"), nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".muxagent"), nil
}

func DefaultConfigPath() (string, error) {
	defaultBundlePath, err := DefaultBundlePath()
	if err != nil {
		return "", err
	}
	return filepath.Join(defaultBundlePath, managedConfigFile), nil
}

func DefaultBundlePath() (string, error) {
	taskConfigDir, err := TaskConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(taskConfigDir, managedDefaultBundleDir), nil
}

func LoadRegistry() (Registry, error) {
	path, err := RegistryPath()
	if err != nil {
		return Registry{}, err
	}
	return loadRegistryFromPath(path)
}

func loadRegistryFromPath(path string) (Registry, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return Registry{}, nil
		}
		return Registry{}, err
	}
	var reg Registry
	if err := json.Unmarshal(data, &reg); err != nil {
		return Registry{}, err
	}
	return normalizeRegistry(reg)
}

func SaveRegistry(reg Registry) (string, error) {
	normalized, err := normalizeRegistry(reg)
	if err != nil {
		return "", err
	}
	path, err := RegistryPath()
	if err != nil {
		return "", err
	}
	if err := privdir.Ensure(filepath.Dir(path)); err != nil {
		return "", err
	}
	payload, err := json.MarshalIndent(normalized, "", "  ")
	if err != nil {
		return "", err
	}
	if err := os.WriteFile(path, payload, 0o600); err != nil {
		return "", err
	}
	return path, nil
}

func LoadCatalog() (*Catalog, error) {
	reg, err := ensureBuiltinDefaults()
	if err != nil {
		return nil, err
	}
	taskConfigDir, err := TaskConfigDir()
	if err != nil {
		return nil, err
	}
	entries := make([]CatalogEntry, 0, len(reg.Configs))
	for _, entry := range reg.Configs {
		_, fullPath, err := resolveRegistryEntryPath(taskConfigDir, entry.Path)
		if err != nil {
			return nil, fmt.Errorf("registry entry %q: %w", entry.Alias, err)
		}
		entries = append(entries, CatalogEntry{
			Alias:     entry.Alias,
			Path:      fullPath,
			BuiltinID: entry.BuiltinID,
			Builtin:   isBuiltinEntry(entry),
		})
	}
	defaultAlias := firstNonEmptyAlias(reg.DefaultAlias, builtinDefaultAlias)
	catalog := &Catalog{
		DefaultAlias: defaultAlias,
		Entries:      entries,
	}
	if _, ok := catalog.Entry(defaultAlias); !ok {
		if _, ok := catalog.Entry(builtinDefaultAlias); ok {
			catalog.DefaultAlias = builtinDefaultAlias
		} else if len(entries) > 0 {
			catalog.DefaultAlias = entries[0].Alias
		}
	}
	return catalog, nil
}

func (c *Catalog) Entry(alias string) (CatalogEntry, bool) {
	if c == nil {
		return CatalogEntry{}, false
	}
	for _, entry := range c.Entries {
		if entry.Alias == alias {
			return entry, true
		}
	}
	return CatalogEntry{}, false
}

func (c *Catalog) DefaultEntry() (CatalogEntry, error) {
	entry, ok := c.Entry(firstNonEmptyAlias(c.DefaultAlias, builtinDefaultAlias))
	if !ok {
		entry, ok = c.Entry(builtinDefaultAlias)
	}
	if !ok && len(c.Entries) > 0 {
		return c.Entries[0], nil
	}
	if !ok {
		return CatalogEntry{}, fmt.Errorf("default task config alias %q does not exist", firstNonEmptyAlias(c.DefaultAlias, builtinDefaultAlias))
	}
	return entry, nil
}

func (e CatalogEntry) LoadConfig() (*Config, error) {
	if e.Config != nil {
		return e.Config, nil
	}
	path := strings.TrimSpace(e.Path)
	if path == "" {
		return nil, errors.New("task config path is required")
	}
	return Load(path)
}

func normalizeRegistry(reg Registry) (Registry, error) {
	result := Registry{
		DefaultAlias: strings.TrimSpace(reg.DefaultAlias),
		Configs:      make([]RegistryEntry, 0, len(reg.Configs)),
	}
	seenAliases := map[string]struct{}{}
	seenPaths := map[string]struct{}{}
	seenBuiltins := map[string]struct{}{}
	for _, entry := range reg.Configs {
		alias := strings.TrimSpace(entry.Alias)
		if alias == "" {
			return Registry{}, errors.New("task config alias is required")
		}
		if _, exists := seenAliases[alias]; exists {
			return Registry{}, fmt.Errorf("duplicate task config alias %q", alias)
		}
		seenAliases[alias] = struct{}{}

		path, err := normalizeRegistryBundlePath(entry.Path)
		if err != nil {
			return Registry{}, fmt.Errorf("task config %q: %w", alias, err)
		}
		pathKey := canonicalRegistryBundlePathKey(path)
		if _, exists := seenPaths[pathKey]; exists {
			return Registry{}, fmt.Errorf("task config path %q is duplicated", path)
		}
		seenPaths[pathKey] = struct{}{}

		normalized := RegistryEntry{
			Alias: alias,
			Path:  path,
		}
		if IsBuiltinID(entry.BuiltinID) {
			if _, exists := seenBuiltins[entry.BuiltinID]; exists {
				return Registry{}, fmt.Errorf("builtin %q is duplicated in the registry", entry.BuiltinID)
			}
			seenBuiltins[entry.BuiltinID] = struct{}{}
			normalized.BuiltinID = entry.BuiltinID
		}
		result.Configs = append(result.Configs, normalized)
	}

	sort.Slice(result.Configs, func(i, j int) bool {
		return compareRegistryEntries(result.Configs[i], result.Configs[j])
	})

	if result.DefaultAlias == "" {
		result.DefaultAlias = builtinDefaultAlias
	}
	if _, exists := seenAliases[result.DefaultAlias]; !exists {
		if result.DefaultAlias == builtinDefaultAlias {
			return result, nil
		}
		if _, exists := seenAliases[builtinDefaultAlias]; exists {
			result.DefaultAlias = builtinDefaultAlias
		} else if len(result.Configs) > 0 {
			result.DefaultAlias = result.Configs[0].Alias
		} else {
			result.DefaultAlias = builtinDefaultAlias
		}
	}
	return result, nil
}

func compareRegistryEntries(left, right RegistryEntry) bool {
	leftBuiltin := isBuiltinEntry(left)
	rightBuiltin := isBuiltinEntry(right)
	switch {
	case leftBuiltin && !rightBuiltin:
		return true
	case !leftBuiltin && rightBuiltin:
		return false
	case leftBuiltin && rightBuiltin:
		leftOrder := builtinDisplayOrder(left.BuiltinID)
		rightOrder := builtinDisplayOrder(right.BuiltinID)
		if leftOrder != rightOrder {
			return leftOrder < rightOrder
		}
	}
	leftKey := strings.ToLower(left.Alias)
	rightKey := strings.ToLower(right.Alias)
	if leftKey != rightKey {
		return leftKey < rightKey
	}
	return left.Alias < right.Alias
}

func resolveRegistryEntryPath(taskConfigDir, relPath string) (string, string, error) {
	clean, err := normalizeRegistryBundlePath(relPath)
	if err != nil {
		return "", "", err
	}
	fullPath := filepath.Join(taskConfigDir, clean)
	rel, err := filepath.Rel(taskConfigDir, fullPath)
	if err != nil {
		return "", "", err
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", "", errors.New("path must stay within taskconfigs directory")
	}
	return clean, filepath.Join(fullPath, managedConfigFile), nil
}

func normalizeRegistryBundlePath(rawPath string) (string, error) {
	clean := filepath.Clean(strings.TrimSpace(rawPath))
	if clean == "." || clean == "" {
		return "", errors.New("path is required")
	}
	if filepath.IsAbs(clean) {
		return "", errors.New("path must be relative")
	}
	if clean == ".." || strings.HasPrefix(clean, ".."+string(filepath.Separator)) {
		return "", errors.New("path must stay within taskconfigs directory")
	}
	switch strings.ToLower(filepath.Ext(clean)) {
	case ".yaml", ".yml":
		return "", errors.New("path must point to a bundle directory")
	}
	return filepath.ToSlash(clean), nil
}

func EnsureManagedDefaultAssets() (string, error) {
	reg, err := ensureBuiltinDefaults()
	if err != nil {
		return "", err
	}
	entry, ok := registryEntryByBuiltinID(reg.Configs, BuiltinIDDefault)
	if !ok {
		return "", fmt.Errorf("builtin %q is unavailable", BuiltinIDDefault)
	}
	taskConfigDir, err := TaskConfigDir()
	if err != nil {
		return "", err
	}
	_, fullPath, err := resolveRegistryEntryPath(taskConfigDir, entry.Path)
	if err != nil {
		return "", err
	}
	return fullPath, nil
}

func EnsureExplicitDefaultRegistryEntry() error {
	_, err := ensureBuiltinDefaults()
	return err
}

func registryEntryByAlias(entries []RegistryEntry, alias string) (RegistryEntry, bool) {
	for _, entry := range entries {
		if entry.Alias == alias {
			return entry, true
		}
	}
	return RegistryEntry{}, false
}

func registryEntryByBuiltinID(entries []RegistryEntry, builtinID string) (RegistryEntry, bool) {
	for _, entry := range entries {
		if entry.BuiltinID == builtinID {
			return entry, true
		}
	}
	return RegistryEntry{}, false
}

func canonicalRegistryBundlePathKey(path string) string {
	return strings.ToLower(filepath.ToSlash(strings.TrimSpace(path)))
}

func ensureManagedAssetFile(destPath string, data []byte) error {
	if _, err := os.Stat(destPath); err == nil {
		return nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return writeManagedAssetFile(destPath, data)
}

func writeManagedAssetFile(destPath string, data []byte) error {
	if err := os.MkdirAll(filepath.Dir(destPath), 0o755); err != nil {
		return err
	}
	return os.WriteFile(destPath, data, 0o644)
}

func firstNonEmptyAlias(values ...string) string {
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			return value
		}
	}
	return ""
}

func ensureBuiltinDefaults() (Registry, error) {
	if err := seedTaskConfigFromLegacyIfNeeded(); err != nil {
		return Registry{}, err
	}

	taskConfigDir, err := TaskConfigDir()
	if err != nil {
		return Registry{}, err
	}
	if err := privdir.Ensure(taskConfigDir); err != nil {
		return Registry{}, err
	}

	reg, err := LoadRegistry()
	if err != nil {
		return Registry{}, err
	}

	changed := false

	// Stamp legacy default entries (alias=default, path=default, no builtin ID).
	for i, entry := range reg.Configs {
		if entry.Alias == DefaultAlias && entry.Path == managedDefaultBundleDir && !isBuiltinEntry(entry) {
			reg.Configs[i].BuiltinID = BuiltinIDDefault
			changed = true
			break
		}
	}

	// Ensure each builtin has a registry entry and bundle.
	for _, def := range builtinDefs {
		if _, ok := registryEntryByBuiltinID(reg.Configs, def.ID); ok {
			if err := syncBuiltinBundle(taskConfigDir, def.ID); err != nil {
				return Registry{}, err
			}
			continue
		}
		alias := def.ID
		if def.ID == BuiltinIDDefault {
			alias = DefaultAlias
		}
		if registryHasAlias(reg.Configs, alias) {
			alias = nextAvailableAlias(reg, "builtin-"+def.ID)
		}
		reg.Configs = append(reg.Configs, RegistryEntry{
			Alias:     alias,
			Path:      builtinBundlePath(def.ID),
			BuiltinID: def.ID,
		})
		if err := syncBuiltinBundle(taskConfigDir, def.ID); err != nil {
			return Registry{}, err
		}
		changed = true
	}

	regPath, err := RegistryPath()
	if err != nil {
		return Registry{}, err
	}
	if _, err := os.Stat(regPath); errors.Is(err, os.ErrNotExist) {
		changed = true
	}
	if changed {
		if _, err := SaveRegistry(reg); err != nil {
			return Registry{}, err
		}
		return LoadRegistry()
	}
	return normalizeRegistry(reg)
}

func seedTaskConfigFromLegacyIfNeeded() error {
	if _, ok, err := appconfig.TaskHomeOverrideDir(); err != nil {
		return err
	} else if !ok {
		return nil
	}

	targetRoot, err := taskConfigRootDir()
	if err != nil {
		return err
	}
	targetRegistryPath := filepath.Join(targetRoot, "taskconfig.json")
	if _, err := os.Stat(targetRegistryPath); err == nil {
		return nil
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}

	legacyRoot, err := appconfig.LegacyMuxagentRootDir()
	if err != nil {
		return err
	}
	sourceRegistryPath := filepath.Join(legacyRoot, "taskconfig.json")
	if filepath.Clean(sourceRegistryPath) == filepath.Clean(targetRegistryPath) {
		return nil
	}

	sourceReg, err := loadRegistryFromPath(sourceRegistryPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return nil
	}

	targetTaskConfigDir := filepath.Join(targetRoot, "taskconfigs")
	sourceTaskConfigDir := filepath.Join(legacyRoot, "taskconfigs")
	seeded := Registry{
		DefaultAlias: sourceReg.DefaultAlias,
		Configs:      make([]RegistryEntry, 0, len(sourceReg.Configs)),
	}
	for _, entry := range sourceReg.Configs {
		if isSeedableUserEntry(entry) {
			seeded.Configs = append(seeded.Configs, entry)
		}
	}
	if len(seeded.Configs) == 0 {
		return nil
	}

	for _, entry := range seeded.Configs {
		sourceBundlePath, err := normalizeRegistryBundlePath(entry.Path)
		if err != nil {
			continue
		}
		sourceBundleDir := filepath.Join(sourceTaskConfigDir, filepath.FromSlash(sourceBundlePath))
		destBundleDir := filepath.Join(targetTaskConfigDir, filepath.FromSlash(sourceBundlePath))
		if filepath.Clean(sourceBundleDir) == filepath.Clean(destBundleDir) {
			continue
		}
		if _, err := os.Stat(sourceBundleDir); errors.Is(err, os.ErrNotExist) {
			continue
		} else if err != nil {
			continue
		}
		if err := copyDir(sourceBundleDir, destBundleDir); err != nil {
			return nil
		}
	}

	_, err = SaveRegistry(seeded)
	return err
}

func isSeedableUserEntry(entry RegistryEntry) bool {
	if isBuiltinEntry(entry) {
		return false
	}
	clean, err := normalizeRegistryBundlePath(entry.Path)
	if err != nil {
		return false
	}
	for _, def := range builtinDefs {
		if clean == builtinBundlePath(def.ID) {
			return false
		}
	}
	return true
}

func syncBuiltinBundle(taskConfigDir, builtinID string) error {
	bundlePath := builtinBundlePath(builtinID)
	bundleDir := filepath.Join(taskConfigDir, filepath.FromSlash(bundlePath))
	revision, err := builtinBundleRevision(builtinID)
	if err != nil {
		return err
	}
	currentRevision, err := readBuiltinBundleRevision(bundleDir)
	if err != nil {
		return err
	}
	if currentRevision == revision {
		return writeBuiltinBundle(taskConfigDir, bundlePath, builtinID, false, nil)
	}
	matchesCurrent, err := builtinBundleMatchesCurrentAssets(bundleDir, builtinID)
	if err != nil {
		return err
	}
	if matchesCurrent {
		return writeBuiltinBundle(taskConfigDir, bundlePath, builtinID, false, nil)
	}
	pinnedRuntime, err := loadExplicitBuiltinRuntime(bundleDir)
	if err != nil {
		return err
	}
	if err := backupBuiltinBundle(taskConfigDir, builtinID, bundleDir); err != nil {
		return err
	}
	return writeBuiltinBundle(taskConfigDir, bundlePath, builtinID, true, pinnedRuntime)
}

func builtinBundleRevision(builtinID string) (string, error) {
	assetFiles, err := builtinAssetFiles(builtinID)
	if err != nil {
		return "", err
	}
	hasher := sha256.New()
	for _, assetPath := range assetFiles {
		data, err := defaultsFS.ReadFile(assetPath)
		if err != nil {
			return "", err
		}
		_, _ = hasher.Write([]byte(assetPath))
		_, _ = hasher.Write([]byte{0})
		_, _ = hasher.Write(data)
		_, _ = hasher.Write([]byte{0})
	}
	return hex.EncodeToString(hasher.Sum(nil)), nil
}

func readBuiltinBundleRevision(bundleDir string) (string, error) {
	data, err := os.ReadFile(filepath.Join(bundleDir, managedBuiltinRevisionFile))
	if errors.Is(err, os.ErrNotExist) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(data)), nil
}

func writeBuiltinBundleRevision(bundleDir, revision string) error {
	return writeManagedAssetFile(filepath.Join(bundleDir, managedBuiltinRevisionFile), []byte(revision+"\n"))
}

func builtinBundleMatchesCurrentAssets(bundleDir, builtinID string) (bool, error) {
	assetFiles, err := builtinAssetFiles(builtinID)
	if err != nil {
		return false, err
	}
	for _, assetPath := range assetFiles {
		destRelPath, err := builtinPromptDestPath(builtinID, assetPath)
		if err != nil {
			return false, err
		}
		destPath := filepath.Join(bundleDir, filepath.FromSlash(destRelPath))
		currentData, err := os.ReadFile(destPath)
		if errors.Is(err, os.ErrNotExist) {
			return false, nil
		}
		if err != nil {
			return false, err
		}
		expectedData, err := defaultsFS.ReadFile(assetPath)
		if err != nil {
			return false, err
		}
		if destRelPath == managedConfigFile {
			match, err := builtinConfigMatchesEmbedded(currentData, expectedData)
			if err != nil {
				return false, err
			}
			if !match {
				return false, nil
			}
			continue
		}
		if !bytes.Equal(currentData, expectedData) {
			return false, nil
		}
	}
	return true, nil
}

func builtinConfigMatchesEmbedded(currentData, expectedData []byte) (bool, error) {
	if bytes.Equal(currentData, expectedData) {
		return true, nil
	}
	currentRaw, err := decodeRawConfig(currentData)
	if err != nil {
		return false, nil
	}
	expectedRaw, err := decodeRawConfig(expectedData)
	if err != nil {
		return false, err
	}
	currentRaw.Runtime = nil
	expectedRaw.Runtime = nil
	return reflect.DeepEqual(currentRaw, expectedRaw), nil
}

func loadExplicitBuiltinRuntime(bundleDir string) (*appconfig.RuntimeID, error) {
	configPath := filepath.Join(bundleDir, managedConfigFile)
	data, err := os.ReadFile(configPath)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	raw, err := decodeRawConfig(data)
	if err != nil || raw.Runtime == nil {
		return nil, nil
	}
	runtime := appconfig.RuntimeID(strings.TrimSpace(string(*raw.Runtime)))
	if !appconfig.IsSupportedRuntime(runtime) {
		return nil, nil
	}
	return &runtime, nil
}

func backupBuiltinBundle(taskConfigDir, builtinID, bundleDir string) error {
	info, err := os.Stat(bundleDir)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("builtin bundle %q is not a directory", bundleDir)
	}
	backupDir, err := nextAvailableBuiltinBackupDir(taskConfigDir, builtinID)
	if err != nil {
		return err
	}
	return os.Rename(bundleDir, backupDir)
}

func nextAvailableBuiltinBackupDir(taskConfigDir, builtinID string) (string, error) {
	base := "backup-" + builtinID
	candidate := filepath.Join(taskConfigDir, base)
	for suffix := 2; ; suffix++ {
		if _, err := os.Stat(candidate); errors.Is(err, os.ErrNotExist) {
			return candidate, nil
		} else if err != nil {
			return "", err
		}
		candidate = filepath.Join(taskConfigDir, fmt.Sprintf("%s-%d", base, suffix))
	}
}

func builtinAssetDataForWrite(assetPath, builtinID string, pinnedRuntime *appconfig.RuntimeID) ([]byte, error) {
	if assetPath != builtinConfigAsset(builtinID) {
		return defaultsFS.ReadFile(assetPath)
	}
	data, err := builtinConfigBytes(builtinID)
	if err != nil {
		return nil, err
	}
	if pinnedRuntime == nil {
		return data, nil
	}
	return applyRuntimeToConfigYAML(data, *pinnedRuntime)
}

func applyRuntimeToConfigYAML(data []byte, runtimeID appconfig.RuntimeID) ([]byte, error) {
	var doc yaml.Node
	dec := yaml.NewDecoder(bytes.NewReader(data))
	if err := dec.Decode(&doc); err != nil {
		return nil, err
	}
	if len(doc.Content) == 0 || doc.Content[0].Kind != yaml.MappingNode {
		return nil, fmt.Errorf("config yaml must decode to a mapping document")
	}
	root := doc.Content[0]
	for i := 0; i < len(root.Content); i += 2 {
		if root.Content[i].Value != "runtime" {
			continue
		}
		root.Content[i+1].Kind = yaml.ScalarNode
		root.Content[i+1].Tag = "!!str"
		root.Content[i+1].Value = string(runtimeID)
		return encodeYAMLDocument(&doc)
	}
	keyNode := &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: "runtime"}
	valueNode := &yaml.Node{Kind: yaml.ScalarNode, Tag: "!!str", Value: string(runtimeID)}
	insertAt := len(root.Content)
	for i := 0; i < len(root.Content); i += 2 {
		switch root.Content[i].Value {
		case "description", "version":
			insertAt = i + 2
		}
	}
	root.Content = append(root.Content, nil, nil)
	copy(root.Content[insertAt+2:], root.Content[insertAt:])
	root.Content[insertAt] = keyNode
	root.Content[insertAt+1] = valueNode
	return encodeYAMLDocument(&doc)
}

func encodeYAMLDocument(doc *yaml.Node) ([]byte, error) {
	var buffer bytes.Buffer
	encoder := yaml.NewEncoder(&buffer)
	encoder.SetIndent(2)
	if err := encoder.Encode(doc); err != nil {
		_ = encoder.Close()
		return nil, err
	}
	if err := encoder.Close(); err != nil {
		return nil, err
	}
	return buffer.Bytes(), nil
}

func writeBuiltinBundle(taskConfigDir, bundlePath, builtinID string, overwrite bool, pinnedRuntime *appconfig.RuntimeID) error {
	bundleDir := filepath.Join(taskConfigDir, filepath.FromSlash(bundlePath))
	assetFiles, err := builtinAssetFiles(builtinID)
	if err != nil {
		return err
	}
	revision, err := builtinBundleRevision(builtinID)
	if err != nil {
		return err
	}
	for _, assetPath := range assetFiles {
		destRelPath, err := builtinPromptDestPath(builtinID, assetPath)
		if err != nil {
			return err
		}
		destPath := filepath.Join(bundleDir, filepath.FromSlash(destRelPath))
		data, err := builtinAssetDataForWrite(assetPath, builtinID, pinnedRuntime)
		if err != nil {
			return err
		}
		if overwrite {
			if err := writeManagedAssetFile(destPath, data); err != nil {
				return err
			}
			continue
		}
		if err := ensureManagedAssetFile(destPath, data); err != nil {
			return err
		}
	}
	return writeBuiltinBundleRevision(bundleDir, revision)
}

func registryHasAlias(entries []RegistryEntry, alias string) bool {
	_, ok := registryEntryByAlias(entries, alias)
	return ok
}
