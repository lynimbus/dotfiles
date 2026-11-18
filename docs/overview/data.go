package main

import (
	"bytes"
	"context"
	"embed"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/egoist/mygo/ui"
)

//go:embed snapshot.json
var embeddedSnapshot []byte

//go:embed icon.svg
var embeddedAppIcon []byte

//go:embed i18n/*.json
var embeddedI18n embed.FS

// Snapshot matches the JSON emitted by `nix eval --json -f docs/overview/data.nix`.
type Snapshot struct {
	Meta      Meta              `json:"meta"`
	Sections  []Section         `json:"sections"`
	Total     int               `json:"total"`
	Programs  Programs          `json:"programs"`
	Desktop   DesktopConfig     `json:"desktop"`
	Toolchain map[string]string `json:"toolchain"`
}

type Meta struct {
	Hostname       string `json:"hostname"`
	System         string `json:"system"`
	StateVersion   string `json:"stateVersion"`
	NixpkgsRev     string `json:"nixpkgsRev"`
	HomeManagerRev string `json:"homeManagerRev"`
	PackageCount   int    `json:"packageCount"`
	LocalCount     int    `json:"localCount"`
}

type Section struct {
	ID    string    `json:"id"`
	Label string    `json:"label"`
	Items []Package `json:"items"`
}

type Package struct {
	Pname       string   `json:"pname"`
	Version     *string  `json:"version"`
	Description *string  `json:"description"`
	Homepage    *string  `json:"homepage"`
	License     []string `json:"license"`
	Local       bool     `json:"local"`
	Section     string   `json:"section"`
	Icon        *string  `json:"icon"`
}

type Programs struct {
	Fish    FishConfig    `json:"fish"`
	Git     GitConfig     `json:"git"`
	Jujutsu JujutsuConfig `json:"jujutsu"`
	SSH     SSHConfig     `json:"ssh"`
	Ghostty GhosttyConfig `json:"ghostty"`
	Zoxide  ZoxideConfig  `json:"zoxide"`
	Direnv  DirenvConfig  `json:"direnv"`
}

type FishConfig struct {
	Enable               bool              `json:"enable"`
	Aliases              map[string]string `json:"aliases"`
	InteractiveShellInit string            `json:"interactiveShellInit"`
}

type GitConfig struct {
	Enable   bool           `json:"enable"`
	Settings map[string]any `json:"settings"`
}

type JujutsuConfig struct {
	Enable   bool           `json:"enable"`
	Settings map[string]any `json:"settings"`
}

type SSHConfig struct {
	Enable bool     `json:"enable"`
	Hosts  []string `json:"hosts"`
}

type GhosttyConfig struct {
	Enable   bool           `json:"enable"`
	Settings map[string]any `json:"settings"`
}

type ZoxideConfig struct {
	Enable  bool     `json:"enable"`
	Options []string `json:"options"`
}

type DirenvConfig struct {
	Enable    bool `json:"enable"`
	NixDirenv bool `json:"nixDirenv"`
}

type DesktopConfig struct {
	WindowManagers   []WindowManager   `json:"windowManagers"`
	Shell            string            `json:"shell"`
	SessionVariables map[string]string `json:"sessionVariables"`
	UserServices     []string          `json:"userServices"`
	UserTimers       []string          `json:"userTimers"`
	InputMethod      string            `json:"inputMethod"`
	Fonts            []string          `json:"fonts"`
}

type WindowManager struct {
	Name   string `json:"name"`
	Enable bool   `json:"enable"`
	Mode   string `json:"mode"`
}

func parseSnapshot(raw []byte) (*Snapshot, error) {
	var s Snapshot
	if err := json.Unmarshal(raw, &s); err != nil {
		return nil, err
	}
	if s.Meta.Hostname == "" {
		return nil, errors.New("snapshot missing meta.hostname")
	}
	return &s, nil
}

func snapshotCachePath() string {
	dir, err := os.UserCacheDir()
	if err != nil || dir == "" {
		return ""
	}
	return filepath.Join(dir, "overview", "snapshot.json")
}

// loadInitialSnapshot returns the best available snapshot immediately without
// blocking startup on `nix eval`. If dataPath is set it is read exclusively;
// otherwise a newer cached live refresh wins over the embedded build snapshot.
func loadInitialSnapshot(dataPath string) (*Snapshot, time.Time, bool, error) {
	if dataPath != "" {
		raw, err := os.ReadFile(dataPath)
		if err != nil {
			return nil, time.Time{}, false, err
		}
		snap, err := parseSnapshot(raw)
		if err != nil {
			return nil, time.Time{}, false, err
		}
		info, _ := os.Stat(dataPath)
		var mod time.Time
		if info != nil {
			mod = info.ModTime()
		}
		return snap, mod, true, nil
	}

	if cachePath := snapshotCachePath(); cachePath != "" {
		if raw, err := os.ReadFile(cachePath); err == nil {
			if snap, err := parseSnapshot(raw); err == nil {
				info, _ := os.Stat(cachePath)
				var mod time.Time
				if info != nil {
					mod = info.ModTime()
				}
				return snap, mod, true, nil
			}
		}
	}

	snap, err := parseSnapshot(embeddedSnapshot)
	if err != nil {
		return nil, time.Time{}, false, err
	}
	return snap, time.Time{}, false, nil
}

// resolveRepoRoot locates the dotfiles repository holding docs/overview/data.nix.
func resolveRepoRoot(explicit, builtIn string) string {
	candidates := []string{explicit}
	if cwd, err := os.Getwd(); err == nil {
		candidates = append(candidates, cwd, filepath.Clean(filepath.Join(cwd, "../..")))
	}
	if builtIn != "" {
		candidates = append(candidates, builtIn)
	}
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		candidates = append(candidates, filepath.Join(home, "dotfiles"))
	}
	for _, dir := range candidates {
		if dir == "" {
			continue
		}
		if st, err := os.Stat(filepath.Join(dir, "docs", "overview", "data.nix")); err == nil && !st.IsDir() {
			return dir
		}
	}
	return builtIn
}

// evalFlakeSnapshot runs `nix eval --json -f docs/overview/data.nix` inside
// repoRoot, validates the JSON, and persists it to the user cache.
func evalFlakeSnapshot(ctx context.Context, repoRoot string) (*Snapshot, error) {
	dataNix := filepath.Join(repoRoot, "docs", "overview", "data.nix")
	if _, err := os.Stat(dataNix); err != nil {
		return nil, fmt.Errorf("cannot locate %s: %w", dataNix, err)
	}
	cmd := exec.CommandContext(ctx, "nix", "eval", "--json", "-f", dataNix)
	cmd.Dir = repoRoot
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg != "" {
			return nil, fmt.Errorf("%v: %s", err, msg)
		}
		return nil, err
	}
	snap, err := parseSnapshot(out)
	if err != nil {
		return nil, err
	}
	if cachePath := snapshotCachePath(); cachePath != "" {
		if err := os.MkdirAll(filepath.Dir(cachePath), 0o755); err == nil {
			var pretty bytes.Buffer
			if json.Indent(&pretty, out, "", "  ") == nil {
				_ = os.WriteFile(cachePath, pretty.Bytes(), 0o644)
			} else {
				_ = os.WriteFile(cachePath, out, 0o644)
			}
		}
	}
	return snap, nil
}

// IconCache decodes PNG and SVG icons from Nix store paths once and reuses the
// decoded handles across frames.
type IconCache struct {
	mu    sync.RWMutex
	items map[string]ui.ImageSource
}

func newIconCache() *IconCache {
	return &IconCache{items: make(map[string]ui.ImageSource)}
}

func (ic *IconCache) Get(path string) ui.ImageSource {
	if path == "" {
		return nil
	}
	ic.mu.RLock()
	img, ok := ic.items[path]
	ic.mu.RUnlock()
	if ok {
		return img
	}
	img = decodeIconFile(path)
	ic.mu.Lock()
	ic.items[path] = img
	ic.mu.Unlock()
	return img
}

func decodeIconFile(path string) ui.ImageSource {
	raw, err := os.ReadFile(path)
	if err != nil || len(raw) == 0 {
		return nil
	}
	lower := strings.ToLower(path)
	if strings.HasSuffix(lower, ".svg") {
		svg, err := ui.ParseSVG(raw)
		if err != nil {
			return nil
		}
		return svg
	}
	bmp, err := ui.DecodeBitmap(raw)
	if err != nil {
		// Some hicolor icons carry an SVG without an .svg extension.
		if svg, serr := ui.ParseSVG(raw); serr == nil {
			return svg
		}
		return nil
	}
	return bmp
}

var nixStoreRe = regexp.MustCompile(`/nix/store/[a-z0-9]{32}-([^/\s"']+)`)

// prettyPath shortens Nix store paths to their human-readable name-version
// suffix while callers keep the full path for tooltips or copy actions.
func prettyPath(text string) string {
	return nixStoreRe.ReplaceAllString(text, "$1")
}

func strVal(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

func trimHomepage(url string) string {
	s := strings.TrimPrefix(url, "https://")
	s = strings.TrimPrefix(s, "http://")
	return strings.TrimSuffix(s, "/")
}

func monogramFor(pname string) string {
	var b strings.Builder
	for _, r := range pname {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			if b.Len() >= 2 {
				break
			}
		}
	}
	if b.Len() == 0 {
		return "?"
	}
	return strings.ToUpper(b.String())
}

func dedentCode(text string) (string, int) {
	s := strings.TrimLeft(text, " \t\r\n")
	// Preserve first line's leading indentation if the raw block started with newline + spaces.
	raw := strings.TrimRight(text, " \t\r\n")
	raw = strings.TrimPrefix(raw, "\n")
	raw = strings.TrimPrefix(raw, "\r\n")
	if raw == "" {
		return s, 0
	}
	lines := strings.Split(raw, "\n")
	minIndent := -1
	for _, ln := range lines {
		if strings.TrimSpace(ln) == "" {
			continue
		}
		indent := 0
		for indent < len(ln) && (ln[indent] == ' ' || ln[indent] == '\t') {
			indent++
		}
		if minIndent < 0 || indent < minIndent {
			minIndent = indent
		}
	}
	if minIndent > 0 {
		for i, ln := range lines {
			if len(ln) >= minIndent {
				lines[i] = ln[minIndent:]
			} else {
				lines[i] = strings.TrimLeft(ln, " \t")
			}
		}
	}
	return strings.Join(lines, "\n"), len(lines)
}

func sortedMapKeys[V any](m map[string]V) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
