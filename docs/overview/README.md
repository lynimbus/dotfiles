# Overview desktop app

`overview` is a native pure-Go desktop application built with
[MyGo](https://github.com/egoist/mygo) (`github.com/egoist/mygo/ui`) and
designed around the tactile interaction language and warm palette of
[Caramel Pudding](https://github.com/wave2234/caramel-pudding).

It is packaged in [pkgs/overview.nix](../../pkgs/overview.nix) and installed
into `home.packages`, replacing the old static HTML workflow:

- Launches instantaneously from its embedded/cached snapshot, then silently
  evaluates `data.nix` against the live flake in the background.
- Click **Refresh** (`Ctrl+R`) or expand the top Caramel Island to re-evaluate
  on demand after editing Nix configurations.
- Build and run its headless `ui.NewTester` checks with:

```bash
nix build --no-link .#legacyPackages.x86_64-linux.overview
```

## Interface & tactile design

Following Caramel Pudding's rules (*where to use jelly vs. gooey adhesion*):

- **Caramel adhesion (`caramel.go` + GPU SDF metaball shader):** single-select
  pill rows (view switch, language picker, shelf navigation) flow with liquid
  caramel smooth-union bridging and pre-release surface tension.
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
- `snapshot.json` is the fallback seed snapshot embedded via `//go:embed` so
  the app opens immediately without blocking on `nix eval`. Live evaluations
  are cached under `$XDG_CACHE_HOME/overview/snapshot.json`.
- `i18n/en.json` and `i18n/zh.json` are the embedded language packs.
- `main.go`, `app.go`, `data.go`, `i18n.go`, `theme.go`, `caramel.go`,
  `island.go`, and `icon.svg` implement the MyGo native UI app.
- `app_test.go` drives the real view headlessly via `ui.NewTester` during the
  Nix build's `checkPhase`.

## Adding a package

Adding a package to `home/packages.nix` (or enabling a `programs.*` module)
requires zero manual edits in `docs/overview/`:

1. `data.nix` classifies every package automatically from its derivation output
   and repo origin (`desktop`, `local`, `cli`, `libs`).
2. `overview` uses optional static overrides in `i18n/zh.json` when present,
   and otherwise translates upstream `meta.description` in the background via
   the local `hy-mt2-server` (`http://127.0.0.1:11435`), caching results in
   `$XDG_CACHE_HOME/overview/translations-zh.json` (falling back to English if
   the local translation server is stopped).
