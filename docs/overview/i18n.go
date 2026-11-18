package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type LocaleInfo struct {
	Code string
	Name string
}

type I18n struct {
	packs     map[string]map[string]any
	languages []LocaleInfo
}

func loadI18n() (*I18n, error) {
	entries, err := fs.ReadDir(embeddedI18n, "i18n")
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
	res := &I18n{
		packs: make(map[string]map[string]any),
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

// Describe returns the localized description for pkg, keeping upstream English
// descriptions on the English locale unless upstream provides none.
func (tr *I18n) Describe(locale string, pkg Package) string {
	if locale == "en" && pkg.Description != nil && strings.TrimSpace(*pkg.Description) != "" {
		return *pkg.Description
	}
	if pack := tr.packs[locale]; pack != nil {
		if descs, ok := pack["descriptions"].(map[string]any); ok {
			if s, ok := descs[pkg.Pname].(string); ok && strings.TrimSpace(s) != "" {
				return s
			}
		}
	}
	if pkg.Description != nil && strings.TrimSpace(*pkg.Description) != "" {
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
