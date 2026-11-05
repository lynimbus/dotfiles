# base.Brewfile — first-boot seed list for Homebrew (CLI + dev tools).
# Install:  brew bundle --file apps/profiles/base.Brewfile
#
# Rebuilt 2026-11 as the brew translation of the NixOS home package lists
# on main (home/packages/cli.nix + dev.nix + the jj/git tooling), merged
# with what this machine already had installed. Your REAL inventory is
# captured afterwards into apps/brew/inventory/<profile>/Brewfile — that
# file wins over this seed.
#
# Not translatable to brew (see docs/nixos-port-map.md):
#   nvd nix-init nixfmt nil nixd  — Nix-only tooling, no Nix on atomic
#   lody-pi                       — Lody desktop ships its own runtime
#   opengrep r8 mygo              — scripts/install-user-apps.sh
#   satty                         — swappy is baked into the image
#
# One package, one owner (docs/software-management.md). These were dropped
# here because the IMAGE already provides them — a brew copy lands behind the
# system PATH (environment.d appends brew last on purpose), so it is never the
# one that resolves; it only costs disk and a shadowed duplicate:
#   file libxml2 dig tmux 7zip zip unzip fish just ffmpeg ImageMagick
#   android-tools               — build_files/build.sh (dnf, image layer)
#   jq fzf fastfetch            — the Bazzite base image
#   pdftoppm pdfinfo …          — the Bazzite base image (poppler-utils);
#                                 the image layer adds poppler-glib for
#                                 GLib/thumbnailing and now poppler-utils too

# ── CLI (home/packages/cli.nix) ──────────────────────────────────────
brew "neovim"
brew "helix"
brew "ripgrep"
brew "gh"
brew "jjui"
brew "fd"
brew "eza"
brew "bat"
brew "shellcheck"
brew "sops"
brew "age"
brew "sing-box"
brew "zoxide"
brew "direnv"
brew "starship"

# ── jujutsu + git tooling (home/programs/jujutsu.nix) ────────────────
brew "jj"
brew "difftastic"
brew "git-delta"

# ── dev toolchain (home/packages/dev.nix) ─────────────────────────────
brew "go"
brew "node"
brew "python@3.12"
brew "zig"
brew "koka"
# Two JDKs on purpose: jadx/apktool bake `openjdk`'s JAVA_HOME into their
# wrappers (Homebrew's Language::Java helper), while r8/d8 in
# scripts/install-user-apps.sh resolve `openjdk@17` explicitly (R8 is tested
# against 17). Both formulae are keg-only, so neither puts `java` on PATH.
brew "openjdk"
brew "openjdk@17"
brew "jdtls"
brew "ast-grep"
brew "typos-cli"
brew "jadx"
brew "apktool"
brew "erofs-utils"
brew "payload-dumper-go"
# android-tools: no brew formula — the image's dnf `android-tools` covers it

# ── archive/media (home/packages/archive.nix) ─────────────────────────
# ffmpeg / ImageMagick / poppler: no brew lines. The image layer installs
# ffmpeg + ImageMagick (dnf) and poppler-utils (dnf) — see the list above.

# ── config management ────────────────────────────────────────────────
# chezmoi renders home/chezmoi/ (scripts/restore.sh calls it)
brew "chezmoi"

# ── agent runtimes this machine actually uses ─────────────────────────
brew "pi-coding-agent"
brew "rtk"
