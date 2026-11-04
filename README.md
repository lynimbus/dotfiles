# atomic-workstation

> One git repo for a complete Linux workstation: **Bazzite (bootc) + niri + Flatpak + Homebrew + Distrobox**, with automatic software discovery.
>
> 正常装软件 → 定时器自动扫描 → 状态进 git → 新机器一键恢复 → 系统更新原子化、可回滚。

[![tests](https://img.shields.io/badge/tests-mocked%20e2e-green)](tests/) [![base](https://img.shields.io/badge/base-ghcr.io%2Fublue--os%2Fbazzite-blue)](Containerfile)

This repo doubles as:

* the **atomic-workstation** definition (this README + `docs/`), and
* an existing **NixOS flake** for the current machine on the `main`
  branch (`flake.nix`, `home/`, `system/`, `pkgs/`). This branch is the
  atomic translation of that config: every module/package has a documented
  home in docs/nixos-port-map.md.

## Architecture in 30 seconds

```text
SYSTEM   bootc image (this repo's Containerfile, built by CI → GHCR)
         Bazzite + an ADDITIONAL niri + noctalia session (KDE stays as
         fallback) — a port of this repo's main-branch NixOS config,
         module by module: docs/nixos-port-map.md
CONFIG   chezmoi source: home/chezmoi/ (niri, noctalia, mango, ghostty,
         foot, fish+jjmsg, git, jj, ssh, pipewire autogain, hourly-chime,
         systemd user units, environment.d)
APPS     flatpak (GUI) + homebrew (CLI) + pinned GitHub releases
         (scripts/install-user-apps.sh: magpie ghostty pig opengrep r8
         mygo) — auto-discovered hourly into apps/*/inventory/
DEVS     distrobox containers declared in containers/distrobox.ini
```

You install software the normal way. A user-level systemd timer scans it,
writes sorted JSON/Brewfile inventories, and git diffs show what changed.
Nothing auto-commits, nothing auto-pushes, nothing auto-deletes.

## Quickstart

```bash
# on the target machine (after booting the custom image — see below):
git clone git@github.com:<owner>/<repo>.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh                              # environment check
chezmoi --source home/chezmoi init                  # render ~/.config/chezmoi/chezmoi.toml (gitName/gitEmail/profile)
chezmoi --source home/chezmoi diff                  # preview
chezmoi --source home/chezmoi apply                 # apply user config
just user-apps                                      # magpie ghostty pig opengrep r8 mygo (optional)
just brew-seed                                      # CLI tools (first boot only; optional)
./scripts/install-user-timer.sh                     # hourly inventory scan
./scripts/inventory.sh capture                      # first inventory
```

First deploy of the custom image: **docs/installation.md** (base image
variants, signing keys, `bootc switch`, first niri login).

## Daily commands

```bash
./scripts/inventory.sh capture    # scan now
./scripts/inventory.sh status     # machine vs git inventory diff
./scripts/sync.sh                 # capture + show git state
./scripts/sync.sh --commit        # + commit ONLY inventory files
./scripts/sync.sh --push          # + push (manual; timer never pushes)
./scripts/doctor.sh               # health check ([OK]/[WARN]/[FAIL])
./scripts/backup.sh run           # restic backup of user data
```

Also on the image (ujust): `ujust atomic-ws-doctor`, `ujust atomic-ws-sync`,
`ujust atomic-ws-restore`.

## Installing software (priority order)

1. `ujust …` — Bazzite system integrations
2. `flatpak install flathub <app>` — GUI apps
3. `brew install <tool>` — CLI/TUI apps
4. `distrobox enter fedora-dev` — dev toolchains
5. rpm-ostree layering — last resort (prefer a PR to `build_files/build.sh`)

Then just wait for the next hourly scan (or run capture yourself). Details
and honest limitations: **docs/software-management.md**.

## Directory map

```text
Containerfile, build_files/, system_files/, image-template.env, justfile
  → custom Bazzite image (niri + noctalia added, KDE kept)
.github/workflows/build.yml     → CI: build, rechunk, push GHCR, cosign-sign
cosign.pub                      → signing public key (placeholder → scripts/init-signing.sh)
home/chezmoi/                   → ALL user config (chezmoi source dir)
apps/flatpak/ inventory.py + capture/restore wrappers + inventory/<profile>.json
apps/brew/     capture/restore + inventory/<profile>/Brewfile
apps/profiles/ optional first-boot seed lists
containers/    distrobox.ini + bootstrap/ + inventory/<profile>.json
scripts/       bootstrap · inventory · sync · restore · doctor · backup ·
               init-signing · install-user-timer
system/systemd/user/            → the inventory timer (user-level, no root)
tests/                         → mocked end-to-end suite: ./tests/run.sh
docs/                          → architecture · installation · software-management · recovery · security
```

## New machine migration

```bash
./scripts/restore.sh             # config + flatpak + brew + distrobox + timer
./scripts/doctor.sh              # verify
```

Rollback of a bad system update: `sudo bootc rollback`. Full story:
**docs/recovery.md**.

## Verification

```bash
./tests/run.sh                   # mocked e2e: flatpak/brew/distrobox/git/systemd
cosign verify --key cosign.pub ghcr.io/<owner>/atomic-workstation:latest
```

## Status / what is real

* ✅ tested locally (mocked): inventory capture/restore/idempotency/prune
  consent, brew skip paths, git safety (no auto-push, merge-state refusal),
  systemd unit validation
* ⚠️ needs a real Bazzite host (not this NixOS dev machine): `bootc switch`,
  SDDM niri session login, ujust recipe discovery, real flatpak/brew scans,
  image build in CI. See docs/installation.md §3 and the repo issue tracker.
