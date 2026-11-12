# Overview page

`docs/overview.html` is a single-file page that shows what this flake installs
and how it is configured, laid out like a settings panel or an app store. It is
generated, not hand-edited. It ships in English and Simplified Chinese, switched
from the picker in the top bar.

```bash
just overview         # rebuild docs/overview.html
just overview-verify  # drive the built page in a headless browser
```

`overview-verify` exists because `data.nix` reads module output, and a module
that renames an option or stops exporting settings would leave the page quietly
missing something. The check asserts the card count still matches the flake, the
inlined icons still load, no card overflows its column, the search and filters
still work, and both languages are complete. It is worth running after a package
bump or a settings change.

## Files

- `data.nix` evaluates the flake and reads the result. Packages come from
  `home-manager.users.lynimbus.home.packages`, so versions, descriptions,
  licences and icons are the derivations' own metadata. Settings come from the
  home-manager modules, so the page shows what the login shell and the session
  actually read. `bumpMatrix` supplies the list of packages this repo builds
  itself, which the page marks separately.
- `shell.html` is the template: markup, styling and logic, with two
  placeholders. Both are filled by the build.
- `i18n/en.json` and `i18n/zh.json` are the language packs. English is the
  reference; every other pack must carry the same keys.
- `build.sh` runs the evaluation, assembles the packs, resamples each bitmapped
  icon to 64px and inlines it as a data URI (a store path is not reachable from
  `file://`, and the 256px originals added half a megabyte for a 40px card),
  then writes the result.
- `verify.sh` is the render check described above.

## Adding a package

Adding one to `home/packages.nix` is enough for it to appear in English, because
the derivation carries its own description. Two things then need a hand:

- **Which shelf it sits on.** `data.nix` has a `sectionOf` table mapping pnames
  to sections. Anything unlisted lands in "Other", so nothing disappears, it just
  reads as unshelved.
- **The Chinese pack.** `build.sh` fails with the package name if
  `i18n/zh.json` has no `descriptions` entry for it, rather than showing an
  English sentence in the middle of a Chinese page.

## Adding a language

Drop `i18n/<code>.json` beside the other packs and state its display name in
`__meta.name`. `build.sh` checks it against `en.json` for missing keys and
against the package list for missing descriptions, and the picker picks it up
without any other change. The page opens in its first locale (Chinese) and
remembers the reader's last choice in `localStorage`.
