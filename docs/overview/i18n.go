package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
)

type LocaleInfo struct {
	Code string
	Name string
}

type I18n struct {
	packs     map[string]map[string]any
	languages []LocaleInfo

	mu       sync.RWMutex
	autoDesc map[string]map[string]TranslatedEntry
}

func loadI18n() (*I18n, error) {
	entries, err := fs.ReadDir(embeddedI18n, "i18n")
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
	res := &I18n{
		packs:    make(map[string]map[string]any),
		autoDesc: make(map[string]map[string]TranslatedEntry),
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		raw, err := embeddedI18n.ReadFile("i18n/" + entry.Name())
		if err != nil {
			return nil, err
		}
		var doc map[string]any
		if err := json.Unmarshal(raw, &doc); err != nil {
			return nil, fmt.Errorf("i18n/%s: %w", entry.Name(), err)
		}
		meta, _ := doc["__meta"].(map[string]any)
		code, _ := meta["code"].(string)
		name, _ := meta["name"].(string)
		if code == "" {
			code = strings.TrimSuffix(entry.Name(), ".json")
		}
		if name == "" {
			name = code
		}
		res.packs[code] = doc
		res.languages = append(res.languages, LocaleInfo{Code: code, Name: name})
	}
	if len(res.languages) == 0 {
		return nil, fmt.Errorf("no language packs loaded")
	}
	return res, nil
}

func (tr *I18n) Languages() []LocaleInfo {
	return tr.languages
}

func (tr *I18n) HasLocale(code string) bool {
	_, ok := tr.packs[code]
	return ok
}

func (tr *I18n) DefaultLocale() string {
	if tr.HasLocale("zh") {
		return "zh"
	}
	return tr.languages[0].Code
}

func (tr *I18n) T(locale, key string, vars map[string]any) string {
	raw := tr.lookup(locale, key)
	if raw == "" && locale != "en" {
		raw = tr.lookup("en", key)
	}
	if raw == "" {
		return key
	}
	for k, v := range vars {
		raw = strings.ReplaceAll(raw, "{"+k+"}", fmt.Sprint(v))
	}
	return raw
}

func (tr *I18n) lookup(locale, key string) string {
	node := any(tr.packs[locale])
	for _, part := range strings.Split(key, ".") {
		m, ok := node.(map[string]any)
		if !ok {
			return ""
		}
		node = m[part]
	}
	s, _ := node.(string)
	return s
}

// TS looks up flat setting keys (e.g. "git.user.name") under the pack's
// "settings" map without splitting on dots.
func (tr *I18n) TS(locale, key string) string {
	if pack := tr.packs[locale]; pack != nil {
		if settings, ok := pack["settings"].(map[string]any); ok {
			if s, ok := settings[key].(string); ok && s != "" {
				return s
			}
		}
	}
	if locale != "en" {
		if pack := tr.packs["en"]; pack != nil {
			if settings, ok := pack["settings"].(map[string]any); ok {
				if s, ok := settings[key].(string); ok && s != "" {
					return s
				}
			}
		}
	}
	return key
}

func (tr *I18n) staticDescription(locale, pname string) string {
	if pack := tr.packs[locale]; pack != nil {
		if descs, ok := pack["descriptions"].(map[string]any); ok {
			if s, ok := descs[pname].(string); ok && strings.TrimSpace(s) != "" {
				return s
			}
		}
	}
	return ""
}

func (tr *I18n) LoadAutoDescriptions(locale, path string) {
	loaded := loadTranslationCache(path)
	if len(loaded) == 0 {
		return
	}
	tr.mu.Lock()
	defer tr.mu.Unlock()
	if tr.autoDesc[locale] == nil {
		tr.autoDesc[locale] = make(map[string]TranslatedEntry)
	}
	for k, v := range loaded {
		tr.autoDesc[locale][k] = v
	}
}

func (tr *I18n) SetAutoDescription(locale, pname, source, text string) {
	tr.mu.Lock()
	defer tr.mu.Unlock()
	if tr.autoDesc[locale] == nil {
		tr.autoDesc[locale] = make(map[string]TranslatedEntry)
	}
	tr.autoDesc[locale][pname] = TranslatedEntry{Source: source, Text: text}
}

func (tr *I18n) SnapshotAutoDescriptions(locale string) map[string]TranslatedEntry {
	tr.mu.RLock()
	defer tr.mu.RUnlock()
	src := tr.autoDesc[locale]
	out := make(map[string]TranslatedEntry, len(src))
	for k, v := range src {
		out[k] = v
	}
	return out
}

// MissingAutoDescriptions returns packages lacking both a static description
// override in i18n/<locale>.json and an up-to-date cached auto-translation.
func (tr *I18n) MissingAutoDescriptions(locale string, sections []Section) []Package {
	if locale == "en" {
		return nil
	}
	tr.mu.RLock()
	defer tr.mu.RUnlock()
	cached := tr.autoDesc[locale]
	var missing []Package
	for _, sec := range sections {
		for _, pkg := range sec.Items {
			src := strings.TrimSpace(strVal(pkg.Description))
			if src == "" || tr.staticDescription(locale, pkg.Pname) != "" {
				continue
			}
			if entry, ok := cached[pkg.Pname]; ok && entry.Source == src && strings.TrimSpace(entry.Text) != "" {
				continue
			}
			missing = append(missing, pkg)
		}
	}
	return missing
}

// Describe returns the localized description for pkg, keeping upstream English
// descriptions on the English locale unless upstream provides none.
func (tr *I18n) Describe(locale string, pkg Package) string {
	src := strings.TrimSpace(strVal(pkg.Description))
	if locale == "en" && src != "" {
		return *pkg.Description
	}
	if s := tr.staticDescription(locale, pkg.Pname); s != "" {
		return s
	}
	if locale != "en" && src != "" {
		tr.mu.RLock()
		entry, ok := tr.autoDesc[locale][pkg.Pname]
		tr.mu.RUnlock()
		if ok && entry.Source == src && strings.TrimSpace(entry.Text) != "" {
			return entry.Text
		}
	}
	if src != "" {
		return *pkg.Description
	}
	return tr.T(locale, "card.noDescription", nil)
}

type UserPrefs struct {
	Locale string    `json:"locale"`
	Theme  ThemeMode `json:"theme"`
}

func prefsPath() string {
	dir, err := os.UserConfigDir()
	if err != nil || dir == "" {
		return ""
	}
	return filepath.Join(dir, "overview", "prefs.json")
}

func loadPrefs() UserPrefs {
	p := prefsPath()
	if p == "" {
		return UserPrefs{Theme: ThemeAuto}
	}
	raw, err := os.ReadFile(p)
	if err != nil {
		return UserPrefs{Theme: ThemeAuto}
	}
	var out UserPrefs
	if json.Unmarshal(raw, &out) != nil {
		return UserPrefs{Theme: ThemeAuto}
	}
	if out.Theme != ThemeAuto && out.Theme != ThemeLight && out.Theme != ThemeDark {
		out.Theme = ThemeAuto
	}
	return out
}

func savePrefs(prefs UserPrefs) {
	p := prefsPath()
	if p == "" {
		return
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return
	}
	raw, err := json.MarshalIndent(prefs, "", "  ")
	if err != nil {
		return
	}
	_ = os.WriteFile(p, raw, 0o644)
}
