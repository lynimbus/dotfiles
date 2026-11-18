package main

import (
	"math"
	"os"
	"regexp"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"
)

func mustTestApp(t *testing.T) *OverviewApp {
	t.Helper()
	tr, err := loadI18n()
	if err != nil {
		t.Fatalf("loadI18n: %v", err)
	}
	snap, err := parseSnapshot(embeddedSnapshot)
	if err != nil {
		t.Fatalf("parseSnapshot: %v", err)
	}
	return newOverviewApp(snap, tr, "", time.Time{}, false, false)
}

func TestI18nCompleteness(t *testing.T) {
	tr, err := loadI18n()
	if err != nil {
		t.Fatalf("loadI18n: %v", err)
	}
	snap, err := parseSnapshot(embeddedSnapshot)
	if err != nil {
		t.Fatalf("parseSnapshot: %v", err)
	}

	var collectKeys func(prefix string, m map[string]any, out map[string]bool)
	collectKeys = func(prefix string, m map[string]any, out map[string]bool) {
		for k, v := range m {
			if k == "__meta" || k == "descriptions" {
				continue
			}
			full := k
			if prefix != "" {
				full = prefix + "." + k
			}
			if sub, ok := v.(map[string]any); ok {
				collectKeys(full, sub, out)
			} else {
				out[full] = true
			}
		}
	}

	enKeys := make(map[string]bool)
	collectKeys("", tr.packs["en"], enKeys)

	for _, lang := range tr.Languages() {
		if lang.Code == "en" {
			continue
		}
		packKeys := make(map[string]bool)
		collectKeys("", tr.packs[lang.Code], packKeys)
		for k := range enKeys {
			if !packKeys[k] {
				t.Errorf("i18n/%s.json missing key %q present in en.json", lang.Code, k)
			}
		}

		// Every installed package must have a translated description.
		descs, _ := tr.packs[lang.Code]["descriptions"].(map[string]any)
		for _, sec := range snap.Sections {
			for _, pkg := range sec.Items {
				s, _ := descs[pkg.Pname].(string)
				if strings.TrimSpace(s) == "" {
					t.Errorf("i18n/%s.json missing description for package %q", lang.Code, pkg.Pname)
				}
			}
		}
	}
}

func TestNoRawSettingKeysAndDescriptionsComplete(t *testing.T) {
	app := mustTestApp(t)
	rawKeyRe := regexp.MustCompile(`^[a-z]+(\.[a-z-]+)+$`)

	for _, code := range []string{"zh", "en"} {
		app.setLocale(code)
		panels := app.filteredSettingsPanels()
		if len(panels) < 9 {
			t.Fatalf("locale %s: expected at least 9 settings panels, got %d", code, len(panels))
		}
		for _, pan := range panels {
			if rawKeyRe.MatchString(app.ts(pan.Key)) {
				t.Errorf("locale %s: raw panel title key %q", code, pan.Key)
			}
			for _, row := range pan.Rows {
				label := app.ts(row.Key)
				if rawKeyRe.MatchString(label) {
					t.Errorf("locale %s: raw setting key leaked: %q -> %q", code, row.Key, label)
				}
			}
		}
		for _, sec := range app.snap.Sections {
			for _, pkg := range sec.Items {
				if strings.TrimSpace(app.describe(pkg)) == "" {
					t.Errorf("locale %s: blank description for %q", code, pkg.Pname)
				}
			}
		}
	}
}

func TestIconsDecodeWhenPresent(t *testing.T) {
	app := mustTestApp(t)
	checked := 0
	for _, sec := range app.snap.Sections {
		for _, pkg := range sec.Items {
			p := strVal(pkg.Icon)
			if p == "" {
				continue
			}
			if _, err := os.Stat(p); err != nil {
				continue // store path may not exist in an isolated sandbox
			}
			checked++
			if img := app.icons.Get(p); img == nil {
				t.Errorf("icon for %q failed to decode: %s", pkg.Pname, p)
			}
		}
	}
	t.Logf("decoded %d existing Nix store icons cleanly", checked)
}

func TestLayoutsAndNoHorizontalOverflow(t *testing.T) {
	for _, tc := range []struct {
		name string
		w, h int
	}{
		{"wide-1440", 1440, 960},
		{"narrow-760", 760, 900},
	} {
		t.Run(tc.name, func(t *testing.T) {
			app := mustTestApp(t)
			tt := ui.NewTesterWith(app.view, tc.w, tc.h, ui.TesterOptions{
				Preferences: ui.Preferences{ReduceMotion: true},
			})
			if !tt.HasText(app.snap.Meta.Hostname) {
				t.Fatalf("missing hostname %q", app.snap.Meta.Hostname)
			}
			_, shown := app.filteredSections()
			if shown != app.snap.Total {
				t.Fatalf("expected %d packages shown, got %d", app.snap.Total, shown)
			}
			for _, a := range tt.AccessAll() {
				if a.Bounds.W <= 0 || a.Bounds.H <= 0 {
					continue
				}
				if a.Bounds.X+a.Bounds.W > float32(tc.w)+2 {
					t.Errorf("%s: element %q overflows right edge: x=%.1f w=%.1f (win=%d)",
						tc.name, a.Name, a.Bounds.X, a.Bounds.W, tc.w)
				}
			}
		})
	}
}

func TestSearchFilterSettingsAndLanguageSwitch(t *testing.T) {
	app := mustTestApp(t)
	tt := ui.NewTesterWith(app.view, 1280, 900, ui.TesterOptions{
		Preferences: ui.Preferences{ReduceMotion: true},
	})

	// Starts in Chinese by default.
	if app.locale != "zh" {
		t.Fatalf("expected initial locale zh, got %s", app.locale)
	}

	// Chinese description search: "文件管理器" must hit nautilus and yazi.
	app.query = "文件管理器"
	tt.Frame()
	secs, _ := app.filteredSections()
	var zhHits []string
	for _, s := range secs {
		for _, p := range s.Items {
			zhHits = append(zhHits, p.Pname)
		}
	}
	slices.Sort(zhHits)
	if !slices.Equal(zhHits, []string{"nautilus", "yazi"}) {
		t.Fatalf("zh search '文件管理器': expected [nautilus yazi], got %v", zhHits)
	}

	// Empty search state.
	app.query = "zzzz-nothing-matches"
	tt.Frame()
	if !tt.HasText(app.t("empty.packages", nil)) {
		t.Fatalf("expected empty package message")
	}
	app.query = ""
	tt.Frame()

	// Source filter: click "本仓库构建"
	if err := tt.Click(app.t("filter.local", nil)); err != nil {
		t.Fatalf("click local filter: %v", err)
	}
	secs, localShown := app.filteredSections()
	if localShown != app.snap.Meta.LocalCount {
		t.Fatalf("expected %d local packages, got %d", app.snap.Meta.LocalCount, localShown)
	}
	for _, s := range secs {
		for _, p := range s.Items {
			if !p.Local {
				t.Errorf("non-local package %q appeared under local filter", p.Pname)
			}
		}
	}
	if err := tt.Click(app.t("filter.all", nil)); err != nil {
		t.Fatalf("click all filter: %v", err)
	}

	// Switch to Settings view via Caramel segmented control.
	if err := tt.Click(app.t("nav.settings", nil)); err != nil {
		t.Fatalf("click settings tab: %v", err)
	}
	if app.viewMode != viewSettings {
		t.Fatalf("expected viewSettings, got %v", app.viewMode)
	}
	panelsBefore := len(app.filteredSettingsPanels())
	if panelsBefore < 9 {
		t.Fatalf("expected >= 9 settings panels, got %d", panelsBefore)
	}

	// Settings search keeps matching program's panel open.
	app.query = "jujutsu"
	tt.Frame()
	if got := len(app.filteredSettingsPanels()); got != 1 {
		t.Fatalf("settings search 'jujutsu': expected 1 panel, got %d", got)
	}
	app.query = "zzzz-nothing-matches"
	tt.Frame()
	if !tt.HasText(app.t("empty.settings", nil)) {
		t.Fatalf("expected empty settings message")
	}
	app.query = ""
	tt.Frame()

	// Switch language to English via Caramel pill.
	if err := tt.Click("English"); err != nil {
		t.Fatalf("click English: %v", err)
	}
	if app.locale != "en" {
		t.Fatalf("expected locale en, got %s", app.locale)
	}
	if !tt.HasText("Settings") {
		t.Fatalf("expected English settings heading")
	}

	// Switch back to Installed view and test English search "editor".
	if err := tt.Click("Installed"); err != nil {
		t.Fatalf("click Installed: %v", err)
	}
	app.query = "editor"
	tt.Frame()
	_, editorHits := app.filteredSections()
	if editorHits == 0 || editorHits >= app.snap.Total {
		t.Fatalf("search 'editor': expected narrowed hits, got %d of %d", editorHits, app.snap.Total)
	}
}

func TestDetailSheetAndCaramelIslandPhysics(t *testing.T) {
	app := mustTestApp(t)
	tt := ui.NewTester(app.view, 1280, 900)

	// Open a package detail sheet directly and verify pop animation settles.
	pkg := app.snap.Sections[0].Items[0]
	app.selectedPkg = &pkg
	app.sheetOpenAt = tt.Now()
	tt.Frame()
	tt.Advance(800 * time.Millisecond)

	if !tt.HasText(pkg.Pname) {
		t.Fatalf("detail sheet missing package name %q", pkg.Pname)
	}
	if err := tt.Click(app.t("detail.copyName", nil)); err != nil {
		t.Fatalf("click copy name: %v", err)
	}
	if got := tt.Clipboard(); got != pkg.Pname {
		t.Fatalf("clipboard expected %q, got %q", pkg.Pname, got)
	}
	if hp := strVal(pkg.Homepage); hp != "" {
		if err := tt.Click(app.t("detail.openHomepage", nil)); err != nil {
			t.Fatalf("click open homepage: %v", err)
		}
		if !slices.Contains(tt.OpenedURLs(), hp) {
			t.Fatalf("expected opened URL %q, got %v", hp, tt.OpenedURLs())
		}
	}

	// Escape closes the detail sheet.
	tt.Key(0, ui.KeyEscape)
	if app.selectedPkg != nil {
		t.Fatalf("expected Escape to close detail sheet")
	}

	// Expand Caramel Island and verify analytical 3-spring expansion settles cleanly.
	app.island = newCaramelIsland()
	tt.Frame()
	if err := tt.Click(app.snap.Meta.Hostname + " status island"); err != nil {
		t.Fatalf("click island: %v", err)
	}
	if !app.island.expanded {
		t.Fatalf("expected island to be expanded")
	}
	tt.Advance(1200 * time.Millisecond)
	if app.island.phase != islandStill {
		t.Fatalf("expected island expand spring to settle, phase=%v", app.island.phase)
	}
	if math.Abs(float64(app.island.Height()-168)) > 1.5 {
		t.Fatalf("expected expanded island height ~168, got %.2f", app.island.Height())
	}

	// Collapse via Escape and verify critical-damping shrink settles back to bean.
	tt.Key(0, ui.KeyEscape)
	tt.Advance(1200 * time.Millisecond)
	if app.island.expanded || app.island.phase != islandStill {
		t.Fatalf("expected island collapsed and settled, expanded=%v phase=%v", app.island.expanded, app.island.phase)
	}
	if math.Abs(float64(app.island.Height()-34)) > 1.5 {
		t.Fatalf("expected collapsed island height ~34, got %.2f", app.island.Height())
	}
}

func TestThemeSlowMoContextMenuAndFishCodeBlock(t *testing.T) {
	app := mustTestApp(t)
	tt := ui.NewTesterWith(app.view, 1280, 900, ui.TesterOptions{
		Preferences: ui.Preferences{ReduceMotion: true},
	})

	// Theme cycle: auto -> dark -> light -> auto.
	if app.themeMode != ThemeAuto {
		t.Fatalf("expected ThemeAuto initially, got %v", app.themeMode)
	}
	if err := tt.Click(app.themeLabel()); err != nil {
		t.Fatalf("click theme cycle 1: %v", err)
	}
	if app.themeMode != ThemeDark {
		t.Fatalf("expected ThemeDark, got %v", app.themeMode)
	}
	if err := tt.Click(app.themeLabel()); err != nil {
		t.Fatalf("click theme cycle 2: %v", err)
	}
	if app.themeMode != ThemeLight {
		t.Fatalf("expected ThemeLight, got %v", app.themeMode)
	}

	// Slow-motion toggle.
	if err := tt.Click(app.t("toolbar.slow", nil)); err != nil {
		t.Fatalf("click slow-mo: %v", err)
	}
	if !app.slowMo || app.speed() != 0.25 {
		t.Fatalf("expected slowMo=true speed=0.25, got %v %.2f", app.slowMo, app.speed())
	}

	// Context menu open & filter shelf action.
	pkg := app.snap.Sections[0].Items[0]
	app.menuPkg = &pkg
	app.menuOpenAt = tt.Now()
	app.menuX, app.menuY = 400, 300
	tt.Frame()
	if err := tt.Click(app.t("menu.viewShelf", nil)); err != nil {
		t.Fatalf("click context menu viewShelf: %v", err)
	}
	if app.menuPkg != nil {
		t.Fatalf("expected context menu closed after click")
	}
	if app.sectionID != pkg.Section {
		t.Fatalf("expected sectionID=%q, got %q", pkg.Section, app.sectionID)
	}

	// Settings view: toggle fish.init collapsible script block.
	if err := tt.Click(app.t("nav.settings", nil)); err != nil {
		t.Fatalf("switch to settings: %v", err)
	}
	_, lineCount := dedentCode(app.snap.Programs.Fish.InteractiveShellInit)
	if lineCount > 0 {
		toggleLabel := app.t("card.lines", map[string]any{"n": lineCount})
		if err := tt.Click(toggleLabel); err != nil {
			t.Fatalf("click fish.init toggle %q: %v", toggleLabel, err)
		}
		if !app.fishCodeOpen {
			t.Fatalf("expected fishCodeOpen=true after toggle")
		}
		if !tt.HasText(app.t("card.copyCode", nil)) {
			t.Fatalf("expected copy script button once fish.init expanded")
		}
	}
}

func TestCaramelPuddingMathInvariants(t *testing.T) {
	// Pudding release starts compressed, overshoots wide at t=0.28, tall at t=0.48, settles at 1.0.
	sx0, sy0 := evalPuddingRelease(0.92, 0.92, 0.85, 0)
	if math.Abs(float64(sx0-0.92)) > 1e-4 || math.Abs(float64(sy0-0.92)) > 1e-4 {
		t.Errorf("t=0 mismatch: %.3f, %.3f", sx0, sy0)
	}
	sx1, sy1 := evalPuddingRelease(0.92, 0.92, 0.85, 0.28)
	if sx1 <= 1.05 || sy1 >= 0.95 {
		t.Errorf("t=0.28 expected horizontal squash (sx>1.05, sy<0.95), got %.3f, %.3f", sx1, sy1)
	}
	sx2, sy2 := evalPuddingRelease(0.92, 0.92, 0.85, 0.48)
	if sx2 >= 0.98 || sy2 <= 1.03 {
		t.Errorf("t=0.48 expected vertical stretch (sx<0.98, sy>1.03), got %.3f, %.3f", sx2, sy2)
	}
	sxEnd, syEnd := evalPuddingRelease(0.92, 0.92, 0.85, 1.0)
	if sxEnd != 1 || syEnd != 1 {
		t.Errorf("t=1.0 expected (1, 1), got %.3f, %.3f", sxEnd, syEnd)
	}

	// Critically damped shrink spring must not overshoot below goal.
	x, v := 168.0, 0.0
	for i := 0; i < 60; i++ {
		x, v = springStep(x, v, 34.0, 1200.0, 1.0, 1.0/60.0)
		if x < 33.99 {
			t.Fatalf("critically damped spring overshot below goal: %.4f", x)
		}
	}
	if math.Abs(x-34.0) > 0.05 {
		t.Fatalf("critically damped spring failed to converge: %.4f", x)
	}
}
