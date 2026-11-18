package main

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
)

type activeView string

const (
	viewOverview activeView = "overview"
	viewSettings activeView = "settings"
)

type settingRow struct {
	Key   string
	Value any
}

type codeValue struct {
	Code string
}

type settingPanel struct {
	Key  string
	Rows []settingRow
}

// OverviewApp holds all persistent state of the MyGo native overview app.
type OverviewApp struct {
	win        *mygo.Window
	snap       *Snapshot
	tr         *I18n
	icons      *IconCache
	repoRoot   string
	appIconSVG *ui.SVG

	locale    string
	themeMode ThemeMode
	viewMode  activeView
	sectionID string // "" means all sections
	query     string
	localOnly bool
	slowMo    bool

	// Live refresh state
	refreshing   bool
	refreshErr   string
	refreshedAt  time.Time
	snapshotLive bool

	// Interactive widgets & scroll state
	mainScroll   ui.ScrollState
	sideScroll   ui.ScrollState
	searchHandle ui.Handle
	fishCodeOpen bool
	selectedPkg  *Package
	sheetOpenAt  time.Time
	menuPkg      *Package
	menuOpenAt   time.Time
	menuX, menuY float32
	lastWinTitle string
	persistPrefs bool

	// Caramel Pudding motion controllers
	island       *CaramelIsland
	viewCaramel  *CaramelGroup
	srcCaramel   *CaramelGroup
	langCaramel  *CaramelGroup
	shelfCaramel *CaramelGroup

	// Optional hook to override refresh in tests.
	refreshFunc func(ctx context.Context) (*Snapshot, error)
}

func newOverviewApp(snap *Snapshot, tr *I18n, repoRoot string, refreshedAt time.Time, live bool, persist bool) *OverviewApp {
	prefs := UserPrefs{Theme: ThemeAuto}
	if persist {
		prefs = loadPrefs()
	}
	locale := tr.DefaultLocale()
	if prefs.Locale != "" && tr.HasLocale(prefs.Locale) {
		locale = prefs.Locale
	}
	appSVG, _ := ui.ParseSVG(embeddedAppIcon)
	return &OverviewApp{
		snap:         snap,
		tr:           tr,
		icons:        newIconCache(),
		repoRoot:     repoRoot,
		appIconSVG:   appSVG,
		locale:       locale,
		themeMode:    prefs.Theme,
		viewMode:     viewOverview,
		refreshedAt:  refreshedAt,
		snapshotLive: live,
		persistPrefs: persist,
		island:       newCaramelIsland(),
		viewCaramel:  newCaramelGroup(999),
		srcCaramel:   newCaramelGroup(999),
		langCaramel:  newCaramelGroup(999),
		shelfCaramel: newCaramelGroup(12),
	}
}

func (a *OverviewApp) speed() float64 {
	if a.slowMo {
		return 0.25
	}
	return 1.0
}

func (a *OverviewApp) t(key string, vars map[string]any) string {
	return a.tr.T(a.locale, key, vars)
}

func (a *OverviewApp) ts(key string) string {
	return a.tr.TS(a.locale, key)
}

func (a *OverviewApp) describe(pkg Package) string {
	return a.tr.Describe(a.locale, pkg)
}

func (a *OverviewApp) saveUserPrefs() {
	if !a.persistPrefs {
		return
	}
	savePrefs(UserPrefs{Locale: a.locale, Theme: a.themeMode})
}

func (a *OverviewApp) setLocale(code string) {
	if code == a.locale || !a.tr.HasLocale(code) {
		return
	}
	a.locale = code
	a.saveUserPrefs()
}

func (a *OverviewApp) cycleTheme() {
	switch a.themeMode {
	case ThemeAuto:
		a.themeMode = ThemeDark
	case ThemeDark:
		a.themeMode = ThemeLight
	default:
		a.themeMode = ThemeAuto
	}
	a.saveUserPrefs()
}

func (a *OverviewApp) themeLabel() string {
	switch a.themeMode {
	case ThemeLight:
		return a.t("toolbar.themeLight", nil)
	case ThemeDark:
		return a.t("toolbar.themeDark", nil)
	default:
		return a.t("toolbar.themeAuto", nil)
	}
}

func (a *OverviewApp) copyAndFlash(c *ui.Context, text string) {
	c.WriteClipboard(text)
	preview := text
	if len([]rune(preview)) > 26 {
		preview = string([]rune(preview)[:25]) + "…"
	}
	a.island.Flash(c, a.t("island.copied", map[string]any{"text": preview}), 1800*time.Millisecond, c.Preferences().ReduceMotion)
}

func (a *OverviewApp) openURLAndFlash(c *ui.Context, url string) {
	if url == "" {
		return
	}
	c.OpenURL(url)
	a.island.Flash(c, a.t("island.opened", map[string]any{"text": trimHomepage(url)}), 1800*time.Millisecond, c.Preferences().ReduceMotion)
}

func (a *OverviewApp) triggerRefresh(c *ui.Context) {
	if a.refreshing {
		return
	}
	a.refreshing = true
	a.refreshErr = ""
	a.island.Flash(c, a.t("toolbar.refreshing", nil), 30*time.Second, c.Preferences().ReduceMotion)

	fn := a.refreshFunc
	if fn == nil {
		repo := a.repoRoot
		fn = func(ctx context.Context) (*Snapshot, error) {
			return evalFlakeSnapshot(ctx, repo)
		}
	}

	win := a.win
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		defer cancel()
		snap, err := fn(ctx)
		apply := func() {
			a.refreshing = false
			if err != nil {
				a.refreshErr = err.Error()
				a.island.noticeText = a.t("island.refreshFailed", nil)
				a.island.noticeUntil = time.Now().Add(3 * time.Second)
				return
			}
			a.snap = snap
			a.refreshedAt = time.Now()
			a.snapshotLive = true
			a.refreshErr = ""
			a.island.noticeText = a.t("island.refreshDone", map[string]any{"count": snap.Meta.PackageCount})
			a.island.noticeUntil = time.Now().Add(2200 * time.Millisecond)
		}
		if win != nil {
			win.Update(apply)
		} else {
			apply()
		}
	}()
}

// matchesPkg matches the exact multi-word case-insensitive semantics of the
// original overview page, including localized descriptions.
func (a *OverviewApp) matchesPkg(pkg Package) bool {
	if a.localOnly && !pkg.Local {
		return false
	}
	if a.sectionID != "" && pkg.Section != a.sectionID {
		return false
	}
	q := strings.TrimSpace(a.query)
	if q == "" {
		return true
	}
	hay := strings.ToLower(strings.Join([]string{
		pkg.Pname,
		strVal(pkg.Description),
		a.describe(pkg),
		strVal(pkg.Version),
		strings.Join(pkg.License, " "),
	}, " "))
	for _, word := range strings.Fields(strings.ToLower(q)) {
		if !strings.Contains(hay, word) {
			return false
		}
	}
	return true
}

func (a *OverviewApp) filteredSections() ([]Section, int) {
	out := make([]Section, 0, len(a.snap.Sections))
	shown := 0
	for _, sec := range a.snap.Sections {
		if a.sectionID != "" && sec.ID != a.sectionID {
			continue
		}
		items := make([]Package, 0, len(sec.Items))
		for _, pkg := range sec.Items {
			if a.matchesPkg(pkg) {
				items = append(items, pkg)
			}
		}
		if len(items) > 0 {
			out = append(out, Section{ID: sec.ID, Label: sec.Label, Items: items})
			shown += len(items)
		}
	}
	return out, shown
}

func (a *OverviewApp) view(c *ui.Context) {
	// Read desktop dark preference before setting the frame's Caramel theme.
	systemDark := c.Theme().Dark
	isDark := systemDark
	switch a.themeMode {
	case ThemeLight:
		isDark = false
	case ThemeDark:
		isDark = true
	}
	pal := paletteFor(isDark)
	c.SetTheme(buildUITheme(pal))

	// Keep the OS window title synchronized with the active locale.
	title := a.t("app.title", map[string]any{"host": a.snap.Meta.Hostname})
	if a.win != nil && title != a.lastWinTitle {
		a.lastWinTitle = title
		a.win.SetTitle(title)
	}

	// Keyboard shortcuts.
	if c.Shortcut(ui.Cmd, ui.KeyF) {
		a.searchHandle.Focus(c)
	}
	if c.Shortcut(ui.Cmd, ui.KeyR) {
		a.triggerRefresh(c)
	}
	if c.Shortcut(0, ui.KeyEscape) {
		switch {
		case a.menuPkg != nil:
			a.menuPkg = nil
		case a.selectedPkg != nil:
			a.selectedPkg = nil
		case a.island.expanded:
			a.island.Collapse(c)
		case a.query != "":
			a.query = ""
		}
	}

	a.island.Step(c, a.speed())

	winW, _ := c.Size()
	narrow := winW < 860

	// Root frame background.
	c.Root().Background(pal.Bg)

	if narrow {
		a.buildNarrowLayout(c, pal, winW)
	} else {
		a.buildWideLayout(c, pal, winW)
	}

	// Floating overlays: Caramel Island (top center), Detail Sheet (cp-pop),
	// and right-click Context Menu (cp-menu).
	a.buildIslandOverlay(c, pal, winW)
	if a.selectedPkg != nil {
		a.buildDetailSheet(c, pal, winW)
	}
	if a.menuPkg != nil {
		a.buildContextMenu(c, pal, winW)
	}
}

func (a *OverviewApp) buildWideLayout(c *ui.Context, pal Palette, winW float32) {
	const sideW = float32(254)
	mainW := winW - sideW

	ui.Row(c).Fill().AlignItems(ui.Stretch).Children(func() {
		// Left warm sidebar rail.
		ui.Column(c).Width(sideW).Shrink(0).FillHeight().
			Background(pal.Rail).BorderWidth(0, 1, 0, 0).BorderColor(pal.Line).
			Children(func() {
				a.buildSidebarHeader(c, pal)
				ui.Scroll(c.Key("sidebar-scroll")).TrackScroll(&a.sideScroll).Grow(1).
					Padding(4, 12, 14, 12).Gap(10).Children(func() {
					a.buildViewSwitcher(c, pal)
					a.buildShelfNavVertical(c, pal)
				})
				a.buildSidebarFooter(c, pal)
			})

		// Main pane: top chrome with breathing room for floating Caramel Island,
		// toolbar, and scrollable content.
		ui.Column(c).Grow(1).Shrink(1).MinWidth(0).FillHeight().Children(func() {
			a.buildTopBar(c, pal, false)
			a.buildMainScroll(c, pal, mainW)
		})
	})
}

func (a *OverviewApp) buildNarrowLayout(c *ui.Context, pal Palette, winW float32) {
	ui.Column(c).Fill().Children(func() {
		a.buildTopBar(c, pal, true)
		// Horizontal view + shelf navigation bar on narrow viewports.
		ui.Column(c).Padding(8, 16, 8, 16).Gap(8).
			Background(pal.Rail).BorderWidth(0, 0, 1, 0).BorderColor(pal.Line).
			Children(func() {
				ui.Row(c).Gap(10).AlignItems(ui.Center).Children(func() {
					ui.Box(c).Width(186).Shrink(0).Children(func() {
						a.buildViewSwitcher(c, pal)
					})
					ui.Spacer(c)
					a.buildLangSwitcher(c, pal)
				})
				if a.viewMode == viewOverview {
					a.buildShelfNavHorizontal(c, pal)
				}
			})
		a.buildMainScroll(c, pal, winW)
	})
}

func (a *OverviewApp) buildSidebarHeader(c *ui.Context, pal Palette) {
	ui.Row(c).Padding(18, 16, 12, 16).Gap(11).AlignItems(ui.Center).Children(func() {
		mark := ui.Box(c).Size(40, 40).Shrink(0).Radius(13).
			Background(pal.Card).Border(1, pal.Line).
			Shadow(0, 6, 14, -4, pal.Shadow).Center()
		mark.Children(func() {
			if a.appIconSVG != nil {
				ui.Image(c, a.appIconSVG).Size(32, 32).Fit(ui.Contain)
			} else {
				ui.Text(c, strings.ToUpper(a.snap.Meta.Hostname[:1])).Bold().FontSize(16).TextColor(pal.Caramel)
			}
		})
		ui.Column(c).Grow(1).MinWidth(0).Gap(1).Children(func() {
			ui.Text(c, a.snap.Meta.Hostname).FontSize(16).FontWeight(750).TextColor(pal.Ink).SingleLine()
			ui.Textf(c, "%s · %s", a.snap.Meta.System, a.snap.Meta.StateVersion).
				Font("monospace").FontSize(11).TextColor(pal.Mute).SingleLine()
		})
	})
}

func (a *OverviewApp) buildSidebarFooter(c *ui.Context, pal Palette) {
	ui.Column(c).Padding(10, 12, 14, 12).Gap(8).
		BorderWidth(1, 0, 0, 0).BorderColor(pal.Line).Children(func() {
		a.buildLangSwitcher(c, pal)
		ui.Row(c).Gap(6).Children(func() {
			themeBtn := a.tinyChipButton(c, pal, a.themeLabel(), false)
			themeBtn.Grow(1)
			if themeBtn.Clicked() {
				a.cycleTheme()
			}
			slowLabel := a.t("toolbar.slow", nil)
			if a.slowMo {
				slowLabel = a.t("toolbar.normalSpeed", nil)
			}
			slowBtn := a.tinyChipButton(c, pal, slowLabel, a.slowMo)
			slowBtn.Grow(1)
			if slowBtn.Clicked() {
				a.slowMo = !a.slowMo
			}
		})
	})
}

// buildViewSwitcher renders the Installed / Settings Caramel segmented control.
func (a *OverviewApp) buildViewSwitcher(c *ui.Context, pal Palette) {
	activeIdx := 0
	if a.viewMode == viewSettings {
		activeIdx = 1
	}
	a.viewCaramel.Sync(c, activeIdx, a.speed())

	items := []struct {
		label string
		mode  activeView
	}{
		{a.t("nav.installed", nil), viewOverview},
		{a.t("nav.settings", nil), viewSettings},
	}

	row := ui.Row(c.Key("view-seg")).Padding(4).Gap(4).Radius(999).
		Background(pal.Track).Role(ui.RoleTabList)
	a.viewCaramel.RecordRow(row)
	sheen := ui.RGBA(255, 248, 232, 0.24)
	row.Draw(func(p *ui.Painter, r ui.Rect) {
		a.viewCaramel.Paint(p, r, pal.Caramel, sheen, c.Preferences().ReduceMotion)
	})
	row.Children(func() {
		for idx, it := range items {
			mix := a.viewCaramel.TextMix(c, idx)
			ink := pal.Mute.Mix(pal.CaramelInk, mix)
			btn := ui.Row(c.Key(string(it.mode))).Grow(1).Height(34).Radius(999).Center().
				Cursor(ui.CursorPointer).Role(ui.RoleTab).Label(it.label)
			if btn.Pressed() && idx != activeIdx {
				btn.Opacity(0.72)
			}
			a.viewCaramel.RecordItem(c, idx, btn)
			btn.Children(func() {
				ui.Text(c, it.label).FontSize(13).FontWeight(700).TextColor(ink).SingleLine()
			})
			if btn.Clicked() {
				a.viewMode = it.mode
				a.mainScroll.Y = 0
			}
		}
	})
}

// buildLangSwitcher renders the language Caramel segmented control.
func (a *OverviewApp) buildLangSwitcher(c *ui.Context, pal Palette) {
	langs := a.tr.Languages()
	activeIdx := 0
	for i, l := range langs {
		if l.Code == a.locale {
			activeIdx = i
			break
		}
	}
	a.langCaramel.Sync(c, activeIdx, a.speed())

	row := ui.Row(c.Key("lang-seg")).Padding(3).Gap(3).Radius(999).
		Background(pal.Track).Role(ui.RoleTabList).Label(a.t("lang.label", nil))
	a.langCaramel.RecordRow(row)
	sheen := ui.RGBA(255, 250, 240, 0.14)
	row.Draw(func(p *ui.Painter, r ui.Rect) {
		a.langCaramel.Paint(p, r, pal.Soft, sheen, c.Preferences().ReduceMotion)
	})
	row.Children(func() {
		for idx, lang := range langs {
			mix := a.langCaramel.TextMix(c, idx)
			ink := pal.Mute.Mix(pal.SoftInk, mix)
			btn := ui.Row(c.Key("lang-"+lang.Code)).Grow(1).Height(30).Padding(0, 10).Radius(999).Center().
				Cursor(ui.CursorPointer).Role(ui.RoleTab).Label(lang.Name)
			if btn.Pressed() && idx != activeIdx {
				btn.Opacity(0.72)
			}
			a.langCaramel.RecordItem(c, idx, btn)
			btn.Children(func() {
				ui.Text(c, lang.Name).FontSize(12).FontWeight(650).TextColor(ink).SingleLine()
			})
			if btn.Clicked() {
				a.setLocale(lang.Code)
			}
		}
	})
}

// buildShelfNavVertical renders the vertical caramel shelf list in the sidebar.
func (a *OverviewApp) buildShelfNavVertical(c *ui.Context, pal Palette) {
	ui.Text(c, a.t("nav.installed", nil)).FontSize(10.5).FontWeight(700).
		LetterSpacing(0.8).TextColor(pal.Dim).Padding(6, 10, 0, 10)

	type shelfItem struct {
		id    string
		label string
		count int
	}
	shelves := make([]shelfItem, 0, len(a.snap.Sections)+1)
	shelves = append(shelves, shelfItem{
		id:    "",
		label: a.t("nav.allSections", nil),
		count: a.snap.Meta.PackageCount,
	})
	for _, sec := range a.snap.Sections {
		shelves = append(shelves, shelfItem{
			id:    sec.ID,
			label: a.t("sections."+sec.ID, nil),
			count: len(sec.Items),
		})
	}

	activeIdx := 0
	for i, s := range shelves {
		if a.viewMode == viewOverview && s.id == a.sectionID {
			activeIdx = i
			break
		}
	}
	if a.viewMode != viewOverview {
		activeIdx = -1
	}

	if activeIdx >= 0 {
		a.shelfCaramel.Sync(c, activeIdx, a.speed())
	}

	col := ui.Column(c.Key("shelf-nav-v")).Gap(3)
	a.shelfCaramel.RecordRow(col)
	if activeIdx >= 0 {
		sheen := ui.RGBA(255, 250, 240, 0.14)
		col.Draw(func(p *ui.Painter, r ui.Rect) {
			a.shelfCaramel.Paint(p, r, pal.Soft, sheen, c.Preferences().ReduceMotion)
		})
	}
	col.Children(func() {
		for idx, s := range shelves {
			mix := float32(0)
			if activeIdx >= 0 {
				mix = a.shelfCaramel.TextMix(c, idx)
			}
			ink := pal.Mute.Mix(pal.SoftInk, mix)
			countInk := pal.Dim.Mix(pal.SoftInk, mix)

			btn := ui.Row(c.Key("shelf-"+s.id)).Height(34).Padding(0, 10).Radius(12).
				AlignItems(ui.Center).Gap(8).Cursor(ui.CursorPointer).Label(s.label)
			if btn.Hovered() && idx != activeIdx {
				btn.Background(pal.Track.Alpha(0.55))
			}
			if btn.Pressed() && idx != activeIdx {
				btn.Opacity(0.72)
			}
			a.shelfCaramel.RecordItem(c, idx, btn)
			btn.Children(func() {
				w := 500
				if idx == activeIdx {
					w = 700
				}
				ui.Text(c, s.label).FontSize(13).FontWeight(w).TextColor(ink).Grow(1).SingleLine()
				ui.Textf(c, "%d", s.count).Font("monospace").FontSize(11).TextColor(countInk).SingleLine()
			})
			if btn.Clicked() {
				a.viewMode = viewOverview
				a.sectionID = s.id
				a.mainScroll.Y = 0
			}
		}
	})
}

// buildShelfNavHorizontal renders a wrapping Caramel pill strip for narrow
// viewports so every shelf stays visible with zero horizontal overflow.
func (a *OverviewApp) buildShelfNavHorizontal(c *ui.Context, pal Palette) {
	type shelfItem struct {
		id    string
		label string
		count int
	}
	shelves := make([]shelfItem, 0, len(a.snap.Sections)+1)
	shelves = append(shelves, shelfItem{
		id:    "",
		label: a.t("nav.allSections", nil),
		count: a.snap.Meta.PackageCount,
	})
	for _, sec := range a.snap.Sections {
		shelves = append(shelves, shelfItem{
			id:    sec.ID,
			label: a.t("sections."+sec.ID, nil),
			count: len(sec.Items),
		})
	}

	activeIdx := 0
	for i, s := range shelves {
		if s.id == a.sectionID {
			activeIdx = i
			break
		}
	}
	a.shelfCaramel.Sync(c, activeIdx, a.speed())

	row := ui.Row(c.Key("shelf-nav-h")).Gap(6).Wrap().Role(ui.RoleTabList)
	a.shelfCaramel.RecordRow(row)
	sheen := ui.RGBA(255, 250, 240, 0.14)
	row.Draw(func(p *ui.Painter, r ui.Rect) {
		a.shelfCaramel.Paint(p, r, pal.Soft, sheen, c.Preferences().ReduceMotion)
	})
	row.Children(func() {
		for idx, s := range shelves {
			mix := a.shelfCaramel.TextMix(c, idx)
			ink := pal.Mute.Mix(pal.SoftInk, mix)
			border := pal.Line
			if idx == activeIdx {
				border = pal.Caramel.Alpha(0.35)
			}
			chip := ui.Row(c.Key("hchip-"+s.id)).Height(30).Padding(0, 11).Radius(999).
				AlignItems(ui.Center).Gap(6).Border(1, border).
				Cursor(ui.CursorPointer).Role(ui.RoleTab).Label(s.label)
			if chip.Pressed() && idx != activeIdx {
				chip.Opacity(0.72)
			}
			a.shelfCaramel.RecordItem(c, idx, chip)
			chip.Children(func() {
				ui.Text(c, s.label).FontSize(12.5).FontWeight(650).TextColor(ink).SingleLine()
				ui.Textf(c, "%d", s.count).Font("monospace").FontSize(10.5).TextColor(ink.Alpha(0.78)).SingleLine()
			})
			if chip.Clicked() {
				a.sectionID = s.id
				a.mainScroll.Y = 0
			}
		}
	})
}

func (a *OverviewApp) buildTopBar(c *ui.Context, pal Palette, narrow bool) {
	// Top spacer keeps controls completely clear of the floating Caramel Island.
	padX := float32(28)
	if narrow {
		padX = 16
	}
	ui.Column(c).Padding(54, padX, 12, padX).Gap(10).
		Background(pal.Bg).BorderWidth(0, 0, 1, 0).BorderColor(pal.Line).
		Children(func() {
			ui.Row(c).Gap(10).AlignItems(ui.Center).Children(func() {
				// Search box (never pudding-animated: inputs stay rock-solid).
				sf := ui.SearchField(c.Key("search"), &a.query).
					Placeholder(a.t("search.placeholder", nil)).
					Label(a.t("search.placeholder", nil)).
					Grow(1).MinWidth(160).MaxWidth(440).Radius(14)
				sf.Bind(&a.searchHandle)

				// Source filter Caramel segmented pill (All / From this repo).
				a.buildSourceFilter(c, pal)

				ui.Spacer(c)

				// Refresh utility button (tiny tier: gentle opacity fade, no wobble).
				refLabel := a.t("toolbar.refresh", nil)
				if a.refreshing {
					refLabel = a.t("toolbar.refreshing", nil)
				}
				refBtn := a.tinyChipButton(c, pal, refLabel, a.refreshing)
				if refBtn.Clicked() {
					a.triggerRefresh(c)
				}

				if narrow {
					themeBtn := a.tinyChipButton(c, pal, a.themeLabel(), false)
					if themeBtn.Clicked() {
						a.cycleTheme()
					}
				}
			})
		})
}

func (a *OverviewApp) buildSourceFilter(c *ui.Context, pal Palette) {
	activeIdx := 0
	if a.localOnly {
		activeIdx = 1
	}
	a.srcCaramel.Sync(c, activeIdx, a.speed())

	opts := []struct {
		id    string
		label string
		local bool
	}{
		{"all", a.t("filter.all", nil), false},
		{"local", a.t("filter.local", nil), true},
	}

	row := ui.Row(c.Key("src-seg")).Padding(3).Gap(3).Radius(999).
		Background(pal.Track).Shrink(0).Role(ui.RoleTabList)
	a.srcCaramel.RecordRow(row)
	sheen := ui.RGBA(255, 248, 232, 0.24)
	row.Draw(func(p *ui.Painter, r ui.Rect) {
		a.srcCaramel.Paint(p, r, pal.Caramel, sheen, c.Preferences().ReduceMotion)
	})
	row.Children(func() {
		for idx, opt := range opts {
			mix := a.srcCaramel.TextMix(c, idx)
			ink := pal.Mute.Mix(pal.CaramelInk, mix)
			btn := ui.Row(c.Key("filter-"+opt.id)).Height(30).Padding(0, 12).Radius(999).Center().
				Cursor(ui.CursorPointer).Role(ui.RoleTab).Label(opt.label)
			if btn.Pressed() && idx != activeIdx {
				btn.Opacity(0.72)
			}
			a.srcCaramel.RecordItem(c, idx, btn)
			btn.Children(func() {
				ui.Text(c, opt.label).FontSize(12.5).FontWeight(700).TextColor(ink).SingleLine()
			})
			if btn.Clicked() {
				a.localOnly = opt.local
				a.viewMode = viewOverview
				a.mainScroll.Y = 0
			}
		}
	})
}

func (a *OverviewApp) tinyChipButton(c *ui.Context, pal Palette, label string, active bool) ui.Element {
	bg := pal.Card
	ink := pal.Mute
	border := pal.Line
	if active {
		bg = pal.Soft
		ink = pal.SoftInk
		border = pal.Caramel.Alpha(0.45)
	}
	btn := ui.Row(c).Height(32).Padding(0, 12).Radius(999).Center().
		Background(bg).Border(1, border).Cursor(ui.CursorPointer).Shrink(0).
		Role(ui.RoleButton).Label(label)
	if btn.Hovered() && !active {
		btn.Border(1, pal.LineHover)
		ink = pal.Ink
	}
	applyTinyFade(btn)
	btn.Children(func() {
		ui.Text(c, label).FontSize(12).FontWeight(650).TextColor(ink).SingleLine()
	})
	return btn
}

func (a *OverviewApp) buildMainScroll(c *ui.Context, pal Palette, availW float32) {
	padX := float32(28)
	if availW < 760 {
		padX = 16
	}
	contentW := availW - padX*2
	if contentW > 1140 {
		contentW = 1140
	}

	ui.Scroll(c.Key("main-scroll")).TrackScroll(&a.mainScroll).Grow(1).FillWidth().Children(func() {
		ui.Column(c).MaxWidth(1140+padX*2).Padding(22, padX, 56, padX).Gap(22).Children(func() {
			if a.viewMode == viewSettings {
				a.buildSettingsContent(c, pal, contentW)
			} else {
				a.buildOverviewContent(c, pal, contentW)
			}
		})
	})
}

func (a *OverviewApp) buildOverviewContent(c *ui.Context, pal Palette, contentW float32) {
	sections, shown := a.filteredSections()

	// Editorial Header
	ui.Column(c).Gap(4).Children(func() {
		ui.Text(c, a.t("overview.title", nil)).FontSize(28).FontWeight(800).
			LetterSpacing(-0.4).TextColor(pal.Ink)
		ui.Text(c, a.t("overview.lead", map[string]any{
			"count": a.snap.Meta.PackageCount,
			"local": a.snap.Meta.LocalCount,
			"host":  a.snap.Meta.Hostname,
		})).FontSize(14).TextColor(pal.Mute)
	})

	// 4 Pudding Metric Tiles
	tileCols := 4
	if contentW < 640 {
		tileCols = 2
	}
	ui.Grid(c).Columns(tileCols).Gap(12).Children(func() {
		a.metricTile(c, pal, "tile-pkgs", fmt.Sprint(a.snap.Meta.PackageCount), a.t("tile.packages", nil), false, func() {
			a.localOnly = false
			a.sectionID = ""
		})
		a.metricTile(c, pal, "tile-local", fmt.Sprint(a.snap.Meta.LocalCount), a.t("tile.local", nil), true, func() {
			a.localOnly = !a.localOnly
		})
		a.metricTile(c, pal, "tile-nix", a.snap.Meta.NixpkgsRev, a.t("tile.nixpkgs", nil), false, func() {
			a.copyAndFlash(c, a.snap.Meta.NixpkgsRev)
		})
		a.metricTile(c, pal, "tile-state", a.snap.Meta.StateVersion, a.t("tile.state", nil), false, func() {
			a.copyAndFlash(c, a.snap.Meta.StateVersion)
		})
	})

	if shown == 0 {
		a.buildEmptyState(c, pal, a.t("empty.packages", nil))
		return
	}

	// Responsive card grid columns so cards never overflow horizontally.
	cols := 3
	if contentW < 920 {
		cols = 2
	}
	if contentW < 580 {
		cols = 1
	}

	for _, sec := range sections {
		ui.Column(c.Key("sec-" + sec.ID)).Gap(12).Children(func() {
			ui.Row(c).Gap(10).AlignItems(ui.Center).Children(func() {
				ui.Text(c, a.t("sections."+sec.ID, nil)).FontSize(17).FontWeight(750).TextColor(pal.Ink)
				ui.Box(c).Padding(2, 9).Radius(999).Background(pal.Track).Children(func() {
					ui.Textf(c, "%d", len(sec.Items)).Font("monospace").FontSize(11).FontWeight(650).TextColor(pal.Mute)
				})
			})
			ui.Grid(c).Columns(cols).Gap(12).Children(func() {
				for _, pkg := range sec.Items {
					a.buildPackageCard(c, pal, pkg)
				}
			})
		})
	}

	// Footer
	ui.Box(c).Padding(16, 0, 0, 0).BorderWidth(1, 0, 0, 0).BorderColor(pal.Line).Children(func() {
		ui.Text(c, a.t("foot.packages", map[string]any{
			"hm":     a.snap.Meta.HomeManagerRev,
			"system": a.snap.Meta.System,
		})).Font("monospace").FontSize(11.5).TextColor(pal.Dim)
	})
}

func (a *OverviewApp) metricTile(c *ui.Context, pal Palette, key, value, label string, accent bool, onClick func()) {
	bg := pal.Card
	if accent {
		bg = pal.Pudding
	}
	tile := ui.Column(c.Key(key)).Padding(15, 17).Gap(4).Radius(22).
		Background(bg).Border(1, pal.Line).
		Shadow(0, 10, 22, -12, pal.Shadow).
		Shadow(0, 2, 6, -2, pal.ShadowTight).
		Cursor(ui.CursorPointer).Role(ui.RoleButton).Label(value + " " + label)
	if tile.Hovered() {
		tile.Border(1, pal.LineHover)
	}
	applyPudding(c, tile, 0.60, a.speed())
	tile.Children(func() {
		ui.Text(c, value).FontSize(24).FontWeight(800).LetterSpacing(-0.4).TextColor(pal.Ink).SingleLine()
		ui.Text(c, label).FontSize(11.5).FontWeight(650).LetterSpacing(0.4).TextColor(pal.Mute).SingleLine()
	})
	if tile.Clicked() && onClick != nil {
		onClick()
	}
}

func (a *OverviewApp) buildPackageCard(c *ui.Context, pal Palette, pkg Package) {
	borderColor := pal.Line
	if pkg.Local {
		borderColor = pal.LocalLine
	}

	card := ui.Row(c.Key("pkg-"+pkg.Pname)).Padding(14).Gap(12).Radius(22).
		Background(pal.Card).Border(1, borderColor).
		Shadow(0, 10, 22, -14, pal.Shadow).
		Shadow(0, 2, 5, -2, pal.ShadowTight).
		AlignItems(ui.Start).Cursor(ui.CursorPointer).
		Role(ui.RoleButton).Label(pkg.Pname)

	if card.Hovered() {
		card.Background(pal.CardHover).Border(1, pal.LineHover)
	}

	// Pudding jelly press & release on package cards!
	applyPudding(c, card, 0.72, a.speed())

	card.Children(func() {
		// 44x44 Icon well
		iconBox := ui.Box(c).Size(44, 44).Shrink(0).Radius(14).
			Background(pal.Bg).Border(1, pal.Line).Center().Clip()
		iconBox.Children(func() {
			a.renderPackageIcon(c, pal, pkg, 32)
		})

		// Body
		ui.Column(c).Grow(1).Shrink(1).MinWidth(0).Gap(5).Children(func() {
			// Name + Version + Local badge
			ui.Row(c).Gap(6).AlignItems(ui.Center).Wrap().Children(func() {
				ui.Text(c, pkg.Pname).FontSize(14.5).FontWeight(700).TextColor(pal.Ink).SingleLine()
				if v := strVal(pkg.Version); v != "" {
					ui.Box(c).Padding(1, 7).Radius(7).Background(pal.Track).Children(func() {
						ui.Text(c, v).Font("monospace").FontSize(10.5).TextColor(pal.Mute).SingleLine()
					})
				}
				if pkg.Local {
					ui.Box(c).Padding(1, 7).Radius(7).Background(pal.LocalWash).Children(func() {
						ui.Text(c, a.t("card.thisRepo", nil)).FontSize(10.5).FontWeight(700).TextColor(pal.Local).SingleLine()
					})
				}
			})

			// Description (2 lines max)
			ui.Text(c, a.describe(pkg)).FontSize(12.5).LineHeight(1.42).TextColor(pal.Mute).MaxLines(2)

			// Footer: homepage + license
			hp := strVal(pkg.Homepage)
			lic := strings.Join(pkg.License, ", ")
			if hp != "" || lic != "" {
				ui.Row(c).Gap(6).AlignItems(ui.Center).MinWidth(0).Children(func() {
					if hp != "" {
						ui.Text(c, trimHomepage(hp)).Font("monospace").FontSize(10.5).
							TextColor(pal.SoftInk).SingleLine().Shrink(1)
					}
					if hp != "" && lic != "" {
						ui.Text(c, "·").FontSize(10.5).TextColor(pal.Dim)
					}
					if lic != "" {
						ui.Text(c, lic).Font("monospace").FontSize(10.5).
							TextColor(pal.Dim).SingleLine().Shrink(1)
					}
				})
			}
		})
	})

	if card.Clicked() {
		pCopy := pkg
		a.selectedPkg = &pCopy
		a.sheetOpenAt = c.Now()
		a.menuPkg = nil
	}
	if card.RightClicked() {
		pCopy := pkg
		a.menuPkg = &pCopy
		a.menuOpenAt = c.Now()
		b := card.Bounds()
		if lx, ly, ok := card.PointerPosition(); ok {
			a.menuX = b.X + lx
			a.menuY = b.Y + ly
		} else {
			a.menuX = b.X + b.W*0.5
			a.menuY = b.Y + b.H*0.5
		}
	}
}

func (a *OverviewApp) renderPackageIcon(c *ui.Context, pal Palette, pkg Package, size float32) {
	if p := strVal(pkg.Icon); p != "" {
		if img := a.icons.Get(p); img != nil {
			ui.Image(c, img).Size(size, size).Fit(ui.Contain)
			return
		}
	}
	ui.Text(c, monogramFor(pkg.Pname)).Font("monospace").FontSize(size * 0.44).FontWeight(750).TextColor(pal.Caramel)
}

func (a *OverviewApp) buildEmptyState(c *ui.Context, pal Palette, msg string) {
	ui.Column(c).Padding(36, 24).Gap(14).Radius(24).
		Background(pal.Card).Border(1, pal.Line).AlignItems(ui.Center).Children(func() {
		ui.Text(c, msg).FontSize(15).FontWeight(600).TextColor(pal.Mute)
		if a.query != "" || a.localOnly || a.sectionID != "" {
			resetBtn := ui.Row(c.Key("reset-filters")).Height(38).Padding(0, 18).Radius(14).
				Background(pal.Caramel).Center().Cursor(ui.CursorPointer).
				Role(ui.RoleButton).Label(a.t("empty.reset", nil))
			applyPudding(c, resetBtn, 0.55, a.speed())
			resetBtn.Children(func() {
				ui.Text(c, a.t("empty.reset", nil)).FontSize(13.5).FontWeight(700).TextColor(pal.CaramelInk)
			})
			if resetBtn.Clicked() {
				a.query = ""
				a.localOnly = false
				a.sectionID = ""
			}
		}
	})
}

// buildSettingsPanels builds the 9 program/system panels matching data.nix.
func (a *OverviewApp) buildSettingsPanels() []settingPanel {
	p := a.snap.Programs
	d := a.snap.Desktop

	wmList := make([]string, 0, len(d.WindowManagers))
	for _, wm := range d.WindowManagers {
		if wm.Enable {
			wmList = append(wmList, fmt.Sprintf("%s (%s)", wm.Name, a.t("wm."+wm.Mode, nil)))
		}
	}

	ghosttyRows := []settingRow{{Key: "ghostty.enable", Value: p.Ghostty.Enable}}
	for _, k := range sortedMapKeys(p.Ghostty.Settings) {
		ghosttyRows = append(ghosttyRows, settingRow{Key: "ghostty." + k, Value: p.Ghostty.Settings[k]})
	}

	gitRows := []settingRow{{Key: "git.enable", Value: p.Git.Enable}}
	for _, pair := range flattenSettingMap(p.Git.Settings) {
		gitRows = append(gitRows, settingRow{Key: "git." + pair.Key, Value: pair.Value})
	}

	jjRows := []settingRow{{Key: "jujutsu.enable", Value: p.Jujutsu.Enable}}
	for _, k := range sortedMapKeys(p.Jujutsu.Settings) {
		if k == "user" || k == "signing" {
			continue
		}
		jjRows = append(jjRows, settingRow{Key: "jujutsu." + k, Value: p.Jujutsu.Settings[k]})
	}

	toolRows := make([]settingRow, 0, len(a.snap.Toolchain))
	for _, k := range sortedMapKeys(a.snap.Toolchain) {
		toolRows = append(toolRows, settingRow{Key: "toolchain." + k, Value: a.snap.Toolchain[k]})
	}

	return []settingPanel{
		{
			Key: "fish",
			Rows: []settingRow{
				{Key: "fish.enable", Value: p.Fish.Enable},
				{Key: "fish.aliases", Value: p.Fish.Aliases},
				{Key: "fish.init", Value: codeValue{Code: p.Fish.InteractiveShellInit}},
			},
		},
		{Key: "ghostty", Rows: ghosttyRows},
		{Key: "git", Rows: gitRows},
		{Key: "jujutsu", Rows: jjRows},
		{
			Key: "ssh",
			Rows: []settingRow{
				{Key: "ssh.enable", Value: p.SSH.Enable},
				{Key: "ssh.hosts", Value: p.SSH.Hosts},
			},
		},
		{
			Key: "zoxide",
			Rows: []settingRow{
				{Key: "zoxide.enable", Value: p.Zoxide.Enable},
				{Key: "zoxide.options", Value: p.Zoxide.Options},
			},
		},
		{
			Key: "direnv",
			Rows: []settingRow{
				{Key: "direnv.enable", Value: p.Direnv.Enable},
				{Key: "direnv.nix-direnv", Value: p.Direnv.NixDirenv},
			},
		},
		{
			Key: "desktop",
			Rows: []settingRow{
				{Key: "desktop.compositors", Value: wmList},
				{Key: "desktop.shell", Value: d.Shell},
				{Key: "desktop.inputMethod", Value: d.InputMethod},
				{Key: "desktop.sessionVariables", Value: d.SessionVariables},
				{Key: "desktop.userServices", Value: d.UserServices},
				{Key: "desktop.userTimers", Value: d.UserTimers},
				{Key: "desktop.fonts", Value: d.Fonts},
			},
		},
		{Key: "toolchain", Rows: toolRows},
	}
}

func flattenSettingMap(m map[string]any) []settingRow {
	var out []settingRow
	for _, group := range sortedMapKeys(m) {
		val := m[group]
		if nested, ok := val.(map[string]any); ok {
			for _, inner := range sortedMapKeys(nested) {
				out = append(out, settingRow{Key: group + "." + inner, Value: nested[inner]})
			}
		} else {
			out = append(out, settingRow{Key: group, Value: val})
		}
	}
	return out
}

func isEmptySettingValue(v any) bool {
	if v == nil {
		return true
	}
	switch x := v.(type) {
	case string:
		return x == ""
	case codeValue:
		return strings.TrimSpace(x.Code) == ""
	case []string:
		return len(x) == 0
	case []any:
		return len(x) == 0
	case map[string]string:
		return len(x) == 0
	case map[string]any:
		return len(x) == 0
	}
	return false
}

func (a *OverviewApp) settingRowMatches(r settingRow) bool {
	q := strings.TrimSpace(a.query)
	if q == "" {
		return true
	}
	var raw string
	switch x := r.Value.(type) {
	case codeValue:
		raw = x.Code
	case []string:
		raw = strings.Join(x, " ")
	case string:
		raw = x
	default:
		b, _ := json.Marshal(x)
		raw = string(b)
	}
	hay := strings.ToLower(a.ts(r.Key) + " " + r.Key + " " + raw)
	for _, w := range strings.Fields(strings.ToLower(q)) {
		if !strings.Contains(hay, w) {
			return false
		}
	}
	return true
}

func (a *OverviewApp) filteredSettingsPanels() []settingPanel {
	all := a.buildSettingsPanels()
	words := strings.Fields(strings.ToLower(strings.TrimSpace(a.query)))
	var out []settingPanel
	for _, pan := range all {
		nonEmpty := make([]settingRow, 0, len(pan.Rows))
		for _, r := range pan.Rows {
			if !isEmptySettingValue(r.Value) {
				nonEmpty = append(nonEmpty, r)
			}
		}
		if len(nonEmpty) == 0 {
			continue
		}
		title := a.ts(pan.Key)
		tag := a.ts(pan.Key + ".tag")
		headHay := strings.ToLower(title + " " + tag)
		headHit := len(words) > 0
		for _, w := range words {
			if !strings.Contains(headHay, w) {
				headHit = false
				break
			}
		}
		var kept []settingRow
		if headHit || len(words) == 0 {
			kept = nonEmpty
		} else {
			for _, r := range nonEmpty {
				if a.settingRowMatches(r) {
					kept = append(kept, r)
				}
			}
		}
		if len(kept) > 0 {
			out = append(out, settingPanel{Key: pan.Key, Rows: kept})
		}
	}
	return out
}

func (a *OverviewApp) buildSettingsContent(c *ui.Context, pal Palette, contentW float32) {
	panels := a.filteredSettingsPanels()
	narrowRows := contentW < 580

	ui.Column(c).Gap(4).Children(func() {
		ui.Text(c, a.t("settings.title", nil)).FontSize(28).FontWeight(800).
			LetterSpacing(-0.4).TextColor(pal.Ink)
		ui.Text(c, a.t("settings.lead", nil)).FontSize(14).TextColor(pal.Mute)
	})

	if len(panels) == 0 {
		a.buildEmptyState(c, pal, a.t("empty.settings", nil))
		return
	}

	for _, pan := range panels {
		title := a.ts(pan.Key)
		tag := a.ts(pan.Key + ".tag")

		ui.Column(c.Key("panel-"+pan.Key)).Radius(22).
			Background(pal.Card).Border(1, pal.Line).
			Shadow(0, 10, 22, -14, pal.Shadow).Clip().
			Children(func() {
				// Panel Header
				ui.Row(c).Padding(13, 18).Gap(10).AlignItems(ui.Center).
					BorderWidth(0, 0, 1, 0).BorderColor(pal.Line).Children(func() {
					ui.Box(c).Size(8, 8).Radius(4).Background(pal.Local).Shrink(0)
					ui.Text(c, title).FontSize(15).FontWeight(750).TextColor(pal.Ink)
					ui.Spacer(c)
					ui.Box(c).Padding(2, 9).Radius(8).Background(pal.Track).Children(func() {
						ui.Text(c, tag).Font("monospace").FontSize(11).TextColor(pal.Mute)
					})
				})

				// Panel Rows
				for i, r := range pan.Rows {
					var bw float32 = 1
					if i == len(pan.Rows)-1 {
						bw = 0
					}
					if narrowRows {
						ui.Column(c.Key(r.Key)).Padding(10, 18).Gap(4).
							BorderWidth(0, 0, bw, 0).BorderColor(pal.Line).Children(func() {
							ui.Text(c, a.ts(r.Key)).Font("monospace").FontSize(12).TextColor(pal.Mute)
							a.renderSettingValue(c, pal, r.Key, r.Value)
						})
					} else {
						ui.Row(c.Key(r.Key)).Padding(10, 18).Gap(16).AlignItems(ui.Start).
							BorderWidth(0, 0, bw, 0).BorderColor(pal.Line).Children(func() {
							ui.Text(c, a.ts(r.Key)).Width(210).Shrink(0).
								Font("monospace").FontSize(12.5).TextColor(pal.Mute)
							ui.Column(c).Grow(1).Shrink(1).MinWidth(0).Children(func() {
								a.renderSettingValue(c, pal, r.Key, r.Value)
							})
						})
					}
				}
			})
	}

	ui.Box(c).Padding(16, 0, 0, 0).BorderWidth(1, 0, 0, 0).BorderColor(pal.Line).Children(func() {
		ui.Text(c, a.t("foot.settings", nil)).Font("monospace").FontSize(11.5).TextColor(pal.Dim)
	})
}

func (a *OverviewApp) renderSettingValue(c *ui.Context, pal Palette, key string, val any) {
	switch x := val.(type) {
	case codeValue:
		body, lineCount := dedentCode(x.Code)
		// Collapsible script block: intentionally NOT pudding-animated (Pitfall #9).
		ui.Column(c).Gap(8).Children(func() {
			ui.Row(c).Gap(10).AlignItems(ui.Center).Children(func() {
				marker := "▸ "
				if a.fishCodeOpen {
					marker = "▾ "
				}
				toggle := ui.Row(c.Key("toggle-"+key)).Padding(4, 10).Radius(10).
					Background(pal.Soft).Cursor(ui.CursorPointer).Role(ui.RoleButton).
					Label(a.t("card.lines", map[string]any{"n": lineCount}))
				applyTinyFade(toggle)
				toggle.Children(func() {
					ui.Text(c, marker+a.t("card.lines", map[string]any{"n": lineCount})).
						FontSize(12).FontWeight(650).TextColor(pal.SoftInk)
				})
				if toggle.Clicked() {
					a.fishCodeOpen = !a.fishCodeOpen
				}
				if a.fishCodeOpen {
					copyBtn := a.tinyChipButton(c, pal, a.t("card.copyCode", nil), false)
					if copyBtn.Clicked() {
						a.copyAndFlash(c, body)
					}
				}
			})
			if a.fishCodeOpen {
				ui.Box(c).Padding(12, 14).Radius(14).Background(pal.Bg).Border(1, pal.Line).
					Selectable().Children(func() {
					ui.Text(c, body).Font("monospace").FontSize(11.5).LineHeight(1.48).TextColor(pal.Ink)
				})
			}
		})

	case bool:
		color := pal.Dim
		label := a.t("value.off", nil)
		if x {
			color = pal.Local
			label = a.t("value.on", nil)
		}
		ui.Text(c, label).FontSize(13).FontWeight(700).TextColor(color)

	case []string:
		a.renderInlineTags(c, pal, x)

	case []any:
		strs := make([]string, 0, len(x))
		for _, item := range x {
			strs = append(strs, formatAnyCompact(item))
		}
		a.renderInlineTags(c, pal, strs)

	case map[string]string:
		keys := sortedMapKeys(x)
		pairs := make([]string, 0, len(keys))
		for _, k := range keys {
			pairs = append(pairs, k+"="+x[k])
		}
		a.renderInlineTags(c, pal, pairs)

	case map[string]any:
		keys := sortedMapKeys(x)
		pairs := make([]string, 0, len(keys))
		for _, k := range keys {
			pairs = append(pairs, k+"="+formatAnyCompact(x[k]))
		}
		a.renderInlineTags(c, pal, pairs)

	default:
		raw := fmt.Sprint(x)
		pretty := prettyPath(raw)
		btn := ui.Box(c).Cursor(ui.CursorPointer)
		applyTinyFade(btn)
		btn.Children(func() {
			ui.Text(c, pretty).Font("monospace").FontSize(12.5).TextColor(pal.Ink)
		})
		if btn.Clicked() {
			a.copyAndFlash(c, raw)
		}
	}
}

func formatAnyCompact(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case []any:
		parts := make([]string, 0, len(x))
		for _, item := range x {
			parts = append(parts, fmt.Sprint(item))
		}
		return strings.Join(parts, " ")
	case map[string]any:
		b, _ := json.Marshal(x)
		return string(b)
	default:
		return fmt.Sprint(x)
	}
}

func (a *OverviewApp) renderInlineTags(c *ui.Context, pal Palette, rawItems []string) {
	ui.Row(c).Gap(6).Wrap().Children(func() {
		for idx, raw := range rawItems {
			pretty := prettyPath(raw)
			tag := ui.Box(c.Key(fmt.Sprintf("tag-%d", idx))).Padding(3, 9).Radius(9).
				Background(pal.Bg).Border(1, pal.Line).Cursor(ui.CursorPointer)
			if tag.Hovered() {
				tag.Border(1, pal.LineHover)
			}
			applyTinyFade(tag)
			tag.Children(func() {
				ui.Text(c, pretty).Font("monospace").FontSize(11.5).TextColor(pal.Ink)
			})
			if tag.Clicked() {
				a.copyAndFlash(c, raw)
			}
		}
	})
}

// buildIslandOverlay renders the floating top-center CaramelIsland driven by
// three analytical damped springs (real W/H/R — never scaled!).
func (a *OverviewApp) buildIslandOverlay(c *ui.Context, pal Palette, winW float32) {
	_, shown := a.filteredSections()

	// Keep idle bean width neatly sized to current filter/host text.
	var pillText string
	var pillRight string
	switch {
	case a.island.noticeText != "":
		pillText = a.island.noticeText
	case a.viewMode == viewOverview && (a.query != "" || a.localOnly || a.sectionID != ""):
		pillText = a.snap.Meta.Hostname
		pillRight = a.t("island.filtered", map[string]any{
			"shown": shown,
			"count": a.snap.Meta.PackageCount,
		})
	default:
		pillText = a.snap.Meta.Hostname
		pillRight = a.t("island.pkgs", map[string]any{
			"count": a.snap.Meta.PackageCount,
		})
	}

	if !a.island.expanded && a.island.noticeText == "" {
		wantW := float64(len([]rune(pillText+pillRight))*8 + 78)
		if wantW < 184 {
			wantW = 184
		}
		if wantW > 290 {
			wantW = 290
		}
		if a.island.phase == islandStill && (wantW < a.island.final.W-6 || wantW > a.island.final.W+6) {
			a.island.bean.W = wantW
			a.island.To(islandShape{W: wantW, H: 34, R: 17}, false, c.Preferences().ReduceMotion, c.Now())
		}
	}

	w := a.island.Width()
	h := a.island.Height()
	rad := a.island.Radius()
	left := (winW - w) * 0.5
	if left < 10 {
		left = 10
	}

	ui.Overlay(c, func() {
		isl := ui.Box(c.Key("caramel-island")).Absolute().Top(10).Left(left).
			Size(w, h).Radius(rad).Background(pal.IslandBg).
			Shadow(0, 12, 28, -10, ui.RGBA(0, 0, 0, 0.55)).
			Clip().Cursor(ui.CursorPointer).
			Role(ui.RoleButton).Label(a.snap.Meta.Hostname + " status island")

		alpha := a.island.ContentAlpha()

		if !a.island.expanded {
			isl.Children(func() {
				ui.Row(c).Fill().Padding(0, 15).Gap(8).AlignItems(ui.Center).Opacity(alpha).Children(func() {
					// Warm amber status dot
					dotColor := pal.IslandGold
					if a.refreshing {
						dotColor = pal.Local
					}
					ui.Box(c).Size(8, 8).Radius(4).Background(dotColor).Shrink(0)
					ui.Text(c, pillText).FontSize(12.5).FontWeight(700).TextColor(pal.IslandInk).SingleLine()
					if pillRight != "" {
						ui.Spacer(c)
						ui.Text(c, pillRight).Font("monospace").FontSize(12).FontWeight(700).
							TextColor(pal.IslandGold).SingleLine()
					}
				})
			})
			if isl.Clicked() {
				a.island.Toggle(c, winW)
			}
			return
		}

		// Expanded System Snapshot Card inside the Caramel Island.
		localRatio := float32(0)
		if a.snap.Meta.PackageCount > 0 {
			localRatio = float32(a.snap.Meta.LocalCount) / float32(a.snap.Meta.PackageCount)
		}
		snapSub := a.t("island.snapshotEmbedded", nil)
		if a.snapshotLive && !a.refreshedAt.IsZero() {
			snapSub = a.t("island.snapshotLive", map[string]any{"time": a.refreshedAt.Format("15:04:05")})
		}

		isl.Children(func() {
			ui.Column(c).Fill().Padding(16, 20).Gap(8).Opacity(alpha).Children(func() {
				ui.Row(c).Gap(10).AlignItems(ui.Center).Children(func() {
					ui.Box(c).Size(10, 10).Radius(5).Background(pal.IslandGold).Shrink(0)
					ui.Textf(c, "%s · %s", a.snap.Meta.Hostname, a.snap.Meta.StateVersion).
						FontSize(15).FontWeight(800).TextColor(pal.IslandInk).SingleLine()
					ui.Spacer(c)
					ui.Textf(c, "nix %s", a.snap.Meta.NixpkgsRev).
						Font("monospace").FontSize(11).TextColor(pal.IslandGold).SingleLine()
				})
				ui.Text(c, a.t("island.localRatio", map[string]any{
					"local": a.snap.Meta.LocalCount,
					"count": a.snap.Meta.PackageCount,
				})+" · "+snapSub).FontSize(12).TextColor(pal.IslandMute).SingleLine()

				// Caramel progress bar showing local derivations share
				ui.Box(c).Height(6).FillWidth().Radius(9).Background(pal.IslandBar).Clip().Children(func() {
					ui.Box(c).Height(6).WidthPercent(localRatio * 100).Radius(9).Background(pal.IslandGold)
				})

				ui.Spacer(c)

				ui.Row(c).Gap(8).AlignItems(ui.Center).Children(func() {
					ref := ui.Row(c.Key("isl-refresh")).Height(32).Padding(0, 14).Radius(999).
						Background(pal.Caramel).Center().Cursor(ui.CursorPointer).
						Role(ui.RoleButton).Label(a.t("island.refreshNow", nil))
					applyTinyFade(ref)
					ref.Children(func() {
						ui.Text(c, a.t("island.refreshNow", nil)).FontSize(12).FontWeight(750).TextColor(pal.CaramelInk)
					})
					if ref.Clicked() {
						a.triggerRefresh(c)
					}

					slowTxt := a.t("toolbar.slow", nil)
					if a.slowMo {
						slowTxt = a.t("toolbar.normalSpeed", nil)
					}
					sl := ui.Row(c.Key("isl-slow")).Height(32).Padding(0, 12).Radius(999).
						Background(pal.IslandBar).Center().Cursor(ui.CursorPointer).
						Role(ui.RoleButton).Label(slowTxt)
					applyTinyFade(sl)
					sl.Children(func() {
						ui.Text(c, slowTxt).FontSize(12).FontWeight(650).TextColor(pal.IslandInk)
					})
					if sl.Clicked() {
						a.slowMo = !a.slowMo
					}

					ui.Spacer(c)

					cls := ui.Row(c.Key("isl-close")).Height(32).Padding(0, 12).Radius(999).
						Background(pal.IslandBar).Center().Cursor(ui.CursorPointer).
						Role(ui.RoleButton).Label(a.t("island.close", nil))
					applyTinyFade(cls)
					cls.Children(func() {
						ui.Text(c, a.t("island.close", nil)).FontSize(12).FontWeight(650).TextColor(pal.IslandMute)
					})
					if cls.Clicked() {
						a.island.Collapse(c)
					}
				})
			})
		})

		if isl.PressedOutside() || isl.OverlayShortcut(0, ui.KeyEscape) {
			a.island.Collapse(c)
		}
	})
}

// buildDetailSheet renders the Package Detail Sheet with Caramel Pudding's
// `cp-pop` 580ms elastic pop-up entrance.
func (a *OverviewApp) buildDetailSheet(c *ui.Context, pal Palette, winW float32) {
	pkg := *a.selectedPkg

	var op, dy, sx, sy float32 = 1, 0, 1, 1
	if !c.Preferences().ReduceMotion {
		dur := 0.58 / a.speed()
		t := float32(c.Now().Sub(a.sheetOpenAt).Seconds() / dur)
		if t < 1 {
			op, dy, sx, sy = evalPopEntrance(t)
			c.Invalidate()
		}
	}

	sheetW := min(float32(520), winW-32)

	ui.Overlay(c, func() {
		scrim := ui.Column(c.Key("detail-scrim")).Absolute().Left(0).Top(0).Right(0).Bottom(0).
			Background(pal.Scrim).Center().Modal()

		scrim.Children(func() {
			sheet := ui.Column(c.Key("detail-sheet")).Width(sheetW).Padding(22, 24).Gap(16).
				Radius(28).Background(pal.Card).Border(1, pal.Line).
				Shadow(0, 28, 56, -20, ui.RGBA(30, 14, 4, 0.52)).
				Opacity(op).Translate(0, dy).Scale(sx, sy).
				Role(ui.RoleDialog).Label(pkg.Pname)

			sheet.Children(func() {
				// Grab handle
				ui.Box(c).Width(42).Height(5).Radius(9).Background(pal.Line).AlignSelf(ui.Center)

				// Header row: large icon + title + version/local pills
				ui.Row(c).Gap(14).AlignItems(ui.Center).Children(func() {
					ui.Box(c).Size(58, 58).Shrink(0).Radius(18).
						Background(pal.Bg).Border(1, pal.Line).Center().Clip().Children(func() {
						a.renderPackageIcon(c, pal, pkg, 44)
					})
					ui.Column(c).Grow(1).MinWidth(0).Gap(4).Children(func() {
						ui.Text(c, pkg.Pname).FontSize(22).FontWeight(800).TextColor(pal.Ink).SingleLine()
						ui.Row(c).Gap(6).Wrap().Children(func() {
							if v := strVal(pkg.Version); v != "" {
								ui.Box(c).Padding(2, 9).Radius(999).Background(pal.Track).Children(func() {
									ui.Text(c, v).Font("monospace").FontSize(11.5).TextColor(pal.Mute)
								})
							}
							if pkg.Local {
								ui.Box(c).Padding(2, 9).Radius(999).Background(pal.LocalWash).Children(func() {
									ui.Text(c, a.t("detail.sourceLocal", nil)).FontSize(11.5).FontWeight(700).TextColor(pal.Local)
								})
							} else {
								ui.Box(c).Padding(2, 9).Radius(999).Background(pal.Soft).Children(func() {
									ui.Text(c, a.t("detail.sourceNixpkgs", nil)).FontSize(11.5).FontWeight(650).TextColor(pal.SoftInk)
								})
							}
						})
					})
				})

				// Full untruncated description
				ui.Text(c, a.describe(pkg)).FontSize(14).LineHeight(1.55).TextColor(pal.Ink).Selectable()

				// Metadata table well
				ui.Column(c).Padding(12, 14).Gap(8).Radius(18).Background(pal.Bg).Border(1, pal.Line).Children(func() {
					metaRow := func(label, val string) {
						if val == "" {
							return
						}
						ui.Row(c).Gap(12).AlignItems(ui.Start).Children(func() {
							ui.Text(c, label).Width(84).Shrink(0).FontSize(12).TextColor(pal.Mute)
							ui.Text(c, val).Font("monospace").FontSize(12).TextColor(pal.Ink).Grow(1).Selectable()
						})
					}
					metaRow(a.t("detail.section", nil), a.t("sections."+pkg.Section, nil))
					metaRow(a.t("detail.license", nil), strings.Join(pkg.License, ", "))
					metaRow(a.t("detail.homepage", nil), strVal(pkg.Homepage))
				})

				// Big tactile action buttons (Pudding tier!)
				ui.Row(c).Gap(10).Children(func() {
					if hp := strVal(pkg.Homepage); hp != "" {
						openBtn := ui.Row(c.Key("sheet-open")).Grow(1).Height(44).Radius(16).
							Background(pal.Caramel).Shadow(0, 10, 20, -10, pal.CarShadow).
							Center().Cursor(ui.CursorPointer).Role(ui.RoleButton).Label(a.t("detail.openHomepage", nil))
						applyPudding(c, openBtn, 0.65, a.speed())
						openBtn.Children(func() {
							ui.Text(c, a.t("detail.openHomepage", nil)).FontSize(14).FontWeight(750).TextColor(pal.CaramelInk)
						})
						if openBtn.Clicked() {
							a.openURLAndFlash(c, hp)
						}
					}

					copyBtn := ui.Row(c.Key("sheet-copy")).Grow(1).Height(44).Radius(16).
						Background(pal.Track).Center().Cursor(ui.CursorPointer).
						Role(ui.RoleButton).Label(a.t("detail.copyName", nil))
					applyPudding(c, copyBtn, 0.55, a.speed())
					copyBtn.Children(func() {
						ui.Text(c, a.t("detail.copyName", nil)).FontSize(14).FontWeight(700).TextColor(pal.Ink)
					})
					if copyBtn.Clicked() {
						a.copyAndFlash(c, pkg.Pname)
					}

					closeBtn := ui.Row(c.Key("sheet-close")).Height(44).Padding(0, 18).Radius(16).
						Background(pal.Soft).Center().Cursor(ui.CursorPointer).
						Role(ui.RoleButton).Label(a.t("detail.close", nil))
					applyPudding(c, closeBtn, 0.55, a.speed())
					closeBtn.Children(func() {
						ui.Text(c, a.t("detail.close", nil)).FontSize(14).FontWeight(700).TextColor(pal.SoftInk)
					})
					if closeBtn.Clicked() {
						a.selectedPkg = nil
					}
				})
			})

			if sheet.PressedOutside() || scrim.OverlayShortcut(0, ui.KeyEscape) {
				a.selectedPkg = nil
			}
		})
	})
}

// buildContextMenu renders Caramel Pudding's `cp-menu` context menu growing
// from the pointer's origin on right-click.
func (a *OverviewApp) buildContextMenu(c *ui.Context, pal Palette, winW float32) {
	pkg := *a.menuPkg
	_, winH := c.Size()

	const menuW = float32(196)
	const menuH = float32(168)
	x := a.menuX
	y := a.menuY
	if x+menuW > winW-12 {
		x = winW - menuW - 12
	}
	if x < 12 {
		x = 12
	}
	if y+menuH > winH-12 {
		y = winH - menuH - 12
	}
	if y < 12 {
		y = 12
	}

	var op, sx, sy float32 = 1, 1, 1
	if !c.Preferences().ReduceMotion {
		dur := 0.60 / a.speed()
		t := float32(c.Now().Sub(a.menuOpenAt).Seconds() / dur)
		if t < 1 {
			op, sx, sy = evalMenuEntrance(t)
			c.Invalidate()
		}
	}

	ui.Overlay(c, func() {
		menu := ui.Column(c.Key("ctx-menu")).Absolute().Left(x).Top(y).
			Width(menuW).Padding(6).Gap(2).Radius(18).
			Background(pal.Card).Border(1, pal.Line).
			Shadow(0, 20, 42, -16, ui.RGBA(40, 20, 5, 0.48)).
			TransformOrigin(0, 0).Opacity(op).Scale(sx, sy).
			Role(ui.RoleMenu)

		item := func(key, label string, onClick func()) {
			row := ui.Row(c.Key("mi-"+key)).Height(36).Padding(0, 12).Radius(12).
				AlignItems(ui.Center).Cursor(ui.CursorPointer).Role(ui.RoleMenuItem).Label(label)
			if row.Hovered() {
				row.Background(pal.Soft)
			}
			applyTinyFade(row)
			row.Children(func() {
				ui.Text(c, label).FontSize(13.5).FontWeight(600).TextColor(pal.Ink)
			})
			if row.Clicked() {
				onClick()
				a.menuPkg = nil
			}
		}

		menu.Children(func() {
			item("copy-name", a.t("menu.copyName", nil), func() {
				a.copyAndFlash(c, pkg.Pname)
			})
			if v := strVal(pkg.Version); v != "" {
				item("copy-ver", a.t("menu.copyVersion", nil), func() {
					a.copyAndFlash(c, pkg.Pname+" "+v)
				})
			}
			if hp := strVal(pkg.Homepage); hp != "" {
				item("open-hp", a.t("menu.openHomepage", nil), func() {
					a.openURLAndFlash(c, hp)
				})
			}
			item("shelf", a.t("menu.viewShelf", nil), func() {
				a.viewMode = viewOverview
				a.sectionID = pkg.Section
				a.mainScroll.Y = 0
			})
		})

		if menu.PressedOutside() || menu.OverlayShortcut(0, ui.KeyEscape) {
			a.menuPkg = nil
		}
	})
}

// sortedSectionsForTest ensures deterministic inspection in tests.
func (a *OverviewApp) allPackageNames() []string {
	var names []string
	for _, s := range a.snap.Sections {
		for _, p := range s.Items {
			names = append(names, p.Pname)
		}
	}
	sort.Strings(names)
	return names
}
