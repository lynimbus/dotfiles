# architecture — atomic-workstation

## The idea

One git repository (this one) holds everything needed to rebuild a working
Linux workstation:

* **System layer** — a custom Bazzite (bootc) image built from this repo's
  `Containerfile` via GitHub Actions → GHCR. Adds a Sway session on top of
  stock Bazzite WITHOUT touching the default KDE session.
* **Configuration layer** — chezmoi-managed dotfiles in `home/chezmoi/`.
* **Application layer** — Flatpak (GUI) + Homebrew (CLI), discovered
  automatically by inventory scans, restorable from the repo.
* **Development layer** — Distrobox containers declared in
  `containers/distrobox.ini` with bootstrap scripts.

The repository is **state-first, not declaration-first**: you install
software the normal way (ujust / Flatpak / brew); a timer scans what actually
exists and records it as git-tracked inventory files. New machines restore
from those files. No hand-maintained package lists.

## Repository layout

```text
Containerfile              bootc image definition (Bazzite + Sway stack)
build_files/build.sh       runs INSIDE the image build (dnf5 install …)
system_files/              files overlaid into the image (ujust recipes)
image-template.env         image name / org / base-image / tags
justfile                   image-* recipes (build, rechunk, tag, sign)
.github/workflows/build.yml  CI: build → GHCR → cosign sign
cosign.pub                 image signing PUBLIC key (placeholder until
                           scripts/init-signing.sh runs)
home/chezmoi/              chezmoi SOURCE directory (sway, waybar, foot,
                           mako, wofi, starship, fish, bash, ghostty,
                           systemd user units)
system/systemd/user/       inventory timer units (installed by a script,
                           not baked into the image)
apps/flatpak/              capture/restore wrappers + inventory.py
apps/brew/                 capture/restore wrappers
apps/profiles/             optional hand-written seed lists
containers/distrobox.ini   declarative dev containers
containers/bootstrap/      per-container bootstrap scripts
containers/inventory/      captured container metadata
scripts/                   bootstrap / inventory / sync / restore / doctor /
                           backup / init-signing / install-user-timer
tests/                     mocked end-to-end test suite (tests/run.sh)
docs/                      these documents
```

## Why these choices

| decision | rationale |
| --- | --- |
| Bazzite base + custom image | atomic updates + rollback for free; upstream keeps driver/kernel/flatpak plumbing maintained |
| Sway added to the image, not replacing KDE | login screen offers both; KDE remains the fallback if Sway breaks (NVIDIA driver updates, regressions) |
| chezmoi with a subdirectory source (`home/chezmoi`) | the repo root hosts other things (NixOS flake); the source must stay dedicated |
| Flatpak for GUI apps | Bazzite-native, sandboxed, works on immutable systems |
| Homebrew for CLI apps | preinstalled on Bazzite, distro-agnostic, no rpm layering |
| Distrobox for dev toolchains | heavyweight compilers/SDKs stay in containers; host stays lean |
| inventory = discovered state, not declarations | zero maintenance: uninstall/install normally, the scan records reality |
| per-profile inventory files | machines do not overwrite each other; profile = hostname by default |

## Data flow

```text
        (machine A)                        (machine B, fresh)
  install apps normally                  clone this repo
        │                                       │
  timer fires hourly                      ./scripts/restore.sh
        │                                       │
  scripts/inventory.sh capture      ┌──── chezmoi apply (config)
        │                           ├──── flatpak restore (apps+remotes)
  apps/*/inventory/<host>.json      ├──── brew bundle (CLI apps)
        │                           ├──── distrobox assemble (containers)
  git diff (sync.sh reports)        └──── timer installed
        │
  manual: sync.sh --commit / --push  (NEVER automatic)
```

## What the repo deliberately does NOT do

* No package-definition DSL — you never write "package manifests" by hand
* No forcing declarative purity: install things the normal way, then capture
* No automatic pushes, resets, or force-syncs of git state
* No deletion of user software without an interactive "yes" (`--prune`)
* No secrets in the repo — sops-encrypted files only (see docs/security.md)
