# Overview desktop app

`overview` is a native pure-Go desktop application built with
[MyGo](https://github.com/egoist/mygo) (`github.com/egoist/mygo/ui`) and
designed around the tactile interaction language and warm palette of
[Caramel Pudding](https://github.com/wave2234/caramel-pudding).

It shows what this NixOS flake installs and how the home-manager modules are
configured, ships in Simplified Chinese and English, supports warm light and
dark themes (following the desktop by default), and refreshes directly from the
flake on demand.

```bash
just overview         # regenerate docs/overview/snapshot.json and verify build
just overview-verify  # check snapshot parity, run mygo vet and ui.NewTester suite
just overview-run     # build and launch the desktop app from source
```

Once activated through `just switch` (`pkgs/overview.nix` + `home/packages.nix`),
it is also installed as `overview` with a desktop entry and app icon.

## Interface & tactile design

Following Caramel Pudding's rules (*where to use jelly vs. gooey adhesion*):

- **Caramel adhesion (`caramel.go` + GPU SDF metaball shader):** single-select
  pill rows (view switch, source filter, language picker, shelf navigation)
  flow with liquid caramel smooth-union bridging and pre-release surface tension.
- **Pudding jelly (`applyPudding`):** package cards, metric tiles, and primary
  detail-sheet buttons compress on press and release along Caramel Pudding's
  6-stop squash-and-stretch curve.
- **Caramel Island (`island.go`):** a floating top-center status capsule driven
  by three analytical damped springs (real width, height, and corner radius —
  never scaled) showing live package counts, refresh progress, copy feedback,
  and an expandable system snapshot card.
- **Overlays (`cp-pop` / `cp-menu`):** clicking a package card pops a detail
  sheet; right-clicking opens a context menu from the pointer origin.
- **Restraint:** small utility buttons only fade on press (`applyTinyFade`);
  search inputs, collapsible scripts, and reduced-motion mode never wobble.

## Files

- `data.nix` evaluates the flake and exports packages, settings, desktop
  session info, and toolchain versions.
- `snapshot.json` is the generated build-time snapshot embedded via `//go:embed`
  so the app opens immediately without blocking on `nix eval`. Clicking Refresh
  in the app evaluates `data.nix` in the background and caches the updated
  snapshot under `$XDG_CACHE_HOME/overview/snapshot.json`.
- `i18n/en.json` and `i18n/zh.json` are the embedded language packs.
- `main.go`, `app.go`, `data.go`, `i18n.go`, `theme.go`, `caramel.go`,
  `island.go`, and `icon.svg` implement the MyGo native UI app.
- `app_test.go` drives the real view headlessly via `ui.NewTester`.
- `build.sh` and `verify.sh` power `just overview` and `just overview-verify`.

## Adding a package

Adding a package to `home/packages.nix` makes it appear automatically once
`just overview` regenerates `snapshot.json`:

1. Place its pname in `sectionOf` inside `data.nix` (unlisted packages fall
   into "Other").
2. Add its Chinese description under `descriptions` in `i18n/zh.json`
   (`build.sh` and `app_test.go` fail if a package is undocumented).
