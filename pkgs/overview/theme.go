package main

import "github.com/egoist/mygo/ui"

// ThemeMode chooses whether the app follows the desktop appearance or pins
// light or dark mode.
type ThemeMode string

const (
	ThemeAuto  ThemeMode = "auto"
	ThemeLight ThemeMode = "light"
	ThemeDark  ThemeMode = "dark"
)

// Palette holds the Caramel Pudding color tokens for light and dark themes.
type Palette struct {
	Dark bool

	Bg        ui.Color // Warm custard cream / roasted cocoa canvas
	Rail      ui.Color // Sidebar surface
	Card      ui.Color // Elevated card face
	CardHover ui.Color // Subtle warm hover tint
	Pudding   ui.Color // Soft custard yellow accent surface
	Track     ui.Color // Segmented track / recessed well
	Ink       ui.Color // Primary espresso / milk ink
	Mute      ui.Color // Secondary mocha / oat ink
	Dim       ui.Color // Tertiary caption ink
	Line      ui.Color // Hairline warm border
	LineHover ui.Color // Stronger warm border on hover

	Caramel     ui.Color // Primary amber caramel fill
	CaramelDeep ui.Color // Darker caramel for hover / gradient stop
	CaramelInk  ui.Color // Text on caramel fill
	Soft        ui.Color // Warm caramel wash for tabs and chips
	SoftInk     ui.Color // Deep amber ink on soft wash

	Local     ui.Color // Matcha herb accent for derivations built in this repo
	LocalWash ui.Color // Soft matcha pill background
	LocalLine ui.Color // Subtle card edge highlight for local packages

	Shadow      ui.Color // Warm cocoa ambient card shadow
	ShadowTight ui.Color // Tight contact shadow
	CarShadow   ui.Color // Warm amber shadow under primary caramel pills

	IslandBg   ui.Color // Obsidian pill surface (always dark, like CaramelIsland)
	IslandInk  ui.Color // Cream ink inside the island
	IslandMute ui.Color // Muted oat inside the island
	IslandGold ui.Color // Golden caramel highlight inside the island
	IslandBar  ui.Color // Progress track inside the island

	Scrim ui.Color // Backdrop dim for detail sheet
}

func caramelLight() Palette {
	return Palette{
		Dark:        false,
		Bg:          ui.Hex("#f6efe4"),
		Rail:        ui.Hex("#f1e7d8"),
		Card:        ui.Hex("#fffaf3"),
		CardHover:   ui.Hex("#fdf4e6"),
		Pudding:     ui.Hex("#fbe7b3"),
		Track:       ui.Hex("#ecdfcd"),
		Ink:         ui.Hex("#3a2a1f"),
		Mute:        ui.Hex("#7d6857"),
		Dim:         ui.Hex("#9c8776"),
		Line:        ui.RGBA(58, 42, 31, 0.13),
		LineHover:   ui.RGBA(58, 42, 31, 0.24),
		Caramel:     ui.Hex("#c6772f"),
		CaramelDeep: ui.Hex("#ad6220"),
		CaramelInk:  ui.Hex("#fff8ef"),
		Soft:        ui.Hex("#f3dcc0"),
		SoftInk:     ui.Hex("#9a5420"),
		Local:       ui.Hex("#476f24"),
		LocalWash:   ui.Hex("#e7f0d7"),
		LocalLine:   ui.RGBA(71, 111, 36, 0.34),
		Shadow:      ui.RGBA(96, 58, 24, 0.14),
		ShadowTight: ui.RGBA(96, 58, 24, 0.08),
		CarShadow:   ui.RGBA(150, 76, 18, 0.36),
		IslandBg:    ui.Hex("#140f0c"),
		IslandInk:   ui.Hex("#f7eee5"),
		IslandMute:  ui.Hex("#bfae9d"),
		IslandGold:  ui.Hex("#f6c58f"),
		IslandBar:   ui.Hex("#2e241d"),
		Scrim:       ui.RGBA(30, 16, 6, 0.32),
	}
}

func caramelDark() Palette {
	return Palette{
		Dark:        true,
		Bg:          ui.Hex("#1b1511"),
		Rail:        ui.Hex("#211a15"),
		Card:        ui.Hex("#271f19"),
		CardHover:   ui.Hex("#30261f"),
		Pudding:     ui.Hex("#3d3220"),
		Track:       ui.Hex("#352a21"),
		Ink:         ui.Hex("#f3e7d9"),
		Mute:        ui.Hex("#b49e8b"),
		Dim:         ui.Hex("#8a7564"),
		Line:        ui.RGBA(243, 231, 217, 0.14),
		LineHover:   ui.RGBA(243, 231, 217, 0.26),
		Caramel:     ui.Hex("#e39a52"),
		CaramelDeep: ui.Hex("#cf853e"),
		CaramelInk:  ui.Hex("#26170b"),
		Soft:        ui.Hex("#4b3626"),
		SoftInk:     ui.Hex("#f6c58f"),
		Local:       ui.Hex("#b8dc8c"),
		LocalWash:   ui.RGBA(184, 220, 140, 0.15),
		LocalLine:   ui.RGBA(184, 220, 140, 0.32),
		Shadow:      ui.RGBA(0, 0, 0, 0.44),
		ShadowTight: ui.RGBA(0, 0, 0, 0.26),
		CarShadow:   ui.RGBA(0, 0, 0, 0.42),
		IslandBg:    ui.Hex("#0c0908"),
		IslandInk:   ui.Hex("#f7eee5"),
		IslandMute:  ui.Hex("#bfae9d"),
		IslandGold:  ui.Hex("#f6c58f"),
		IslandBar:   ui.Hex("#2b231d"),
		Scrim:       ui.RGBA(10, 6, 3, 0.54),
	}
}

func paletteFor(dark bool) Palette {
	if dark {
		return caramelDark()
	}
	return caramelLight()
}

// buildUITheme maps the Caramel Pudding palette onto MyGo's native ui.Theme so
// built-in controls (SearchField, scrollbars, focus rings, selection) share the
// exact warm palette.
func buildUITheme(pal Palette) *ui.Theme {
	var t ui.Theme
	if pal.Dark {
		t = *ui.DarkTheme()
	} else {
		t = *ui.LightTheme()
	}
	t.Dark = pal.Dark
	t.Background = pal.Bg
	t.Surface = pal.Card
	t.SurfaceHover = pal.CardHover
	t.SurfacePressed = pal.Track
	t.Border = pal.Line
	t.Text = pal.Ink
	t.TextMuted = pal.Mute
	t.Accent = pal.Caramel
	t.AccentHover = pal.CaramelDeep
	t.AccentPressed = pal.CaramelDeep
	t.AccentText = pal.CaramelInk
	t.InactiveAccent = pal.Soft
	t.Success = pal.Local
	t.Selection = pal.Soft
	t.Focus = pal.Caramel.Alpha(0.65)
	t.Radius = 14
	t.Inverse = pal.IslandBg
	t.InverseText = pal.IslandInk
	t.ScrollbarStyle = ui.ScrollbarStyle{
		TrackWidth: 10,
		ThumbWidth: 6,
		Radius:     3,
		MinLength:  28,
		Thumb:      pal.Mute.Alpha(0.28),
		Hover:      pal.Caramel.Alpha(0.55),
		Active:     pal.Caramel.Alpha(0.8),
	}
	return &t
}
