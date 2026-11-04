# installation — atomic-workstation

Step-by-step from an empty machine to a running Sway-on-Bazzite workstation.
Everything dangerous (image switch, reboot, signing keys) is a MANUAL step —
the scripts never do those for you.

## 0. Prerequisites

* A GitHub account (for GHCR + Actions)
* A machine you are willing to rebase onto a custom image (or a VM to test)
* This repo cloned locally

## 1. One-time repo setup

### 1.1 Pick the base image variant

Edit `image-template.env` → `BASE_IMAGE`. Match your GPU:

| hardware | base image |
| --- | --- |
| AMD / Intel graphics | `ghcr.io/ublue-os/bazzite:stable` (default) |
| NVIDIA proprietary driver | `ghcr.io/ublue-os/bazzite-nvidia:stable` |
| Steam Deck / HTPC appliance | `ghcr.io/ublue-os/bazzite-deck:stable` |
| GNOME flavour preferred | `ghcr.io/ublue-os/bazzite-gnome:stable` |

Notes:

* Do NOT guess: on the current machine check `sudo bootc status` (Bazzite
  hosts) or `lspci | grep -iE 'vga|3d'`. The AMD/Intel default is safe
  everywhere; NVIDIA needs the `-nvidia` variant for the proprietary driver
  stack (Bazzite ships NVIDIA  open / proprietary correctly configured).
* Set `IMAGE_NAME` (lowercase; must match your GitHub repo name if you want
  the template's default GHCR flow) and `REPO_ORGANIZATION` (your GitHub
  username/org).

### 1.2 Signing keys (REQUIRED before CI will publish)

```bash
./scripts/init-signing.sh        # generates cosign.key + cosign.pub locally
git add cosign.pub && git commit -m "feat(signing): add image signing public key"
```

The script prints the remaining manual steps:

1. GitHub → repo → **Settings → Secrets and variables → Actions** →
   *New repository secret*:
   * Name: `SIGNING_SECRET`
   * Value: the full contents of `cosign.key`
   (CLI alternative: `gh secret set SIGNING_SECRET < cosign.key`)
2. Keep `cosign.key` + its passphrase in your password manager. It is
   gitignored; losing it means re-signing with a NEW identity later.

CI **fails before building** if the secret is missing or `cosign.pub` is
still the placeholder — an unsigned image is never published.

### 1.3 Build via GitHub Actions (recommended)

```bash
git push origin main            # triggers .github/workflows/build.yml
```

The workflow (adapted from ublue-os/image-template): builds the image with
podman, rechunks it with rpm-ostree for small delta updates, pushes to
`ghcr.io/<owner>/atomic-workstation` with date/sha alias tags, and signs
every tag with cosign. Manual trigger: Actions → *Build container image* →
*Run workflow*. Daily cron keeps the image fresh with upstream Bazzite.

Verify the published image:

```bash
cosign verify --key cosign.pub ghcr.io/<owner>/atomic-workstation:latest
```

### 1.4 Local build (optional, needs podman)

```bash
just image-build                        # uses image-template.env
BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia:stable just image-build
podman run --rm localhost/atomic-workstation:latest bootc status   # sanity
```

(Needs ~10 GB free disk; the base image is large.)

## 2. Switch a machine onto the image (MANUAL — you type this)

From an existing Bazzite/ostree host:

```bash
sudo bootc switch ghcr.io/<owner>/atomic-workstation:latest
sudo systemctl reboot
```

* Rollback at any time: `sudo bootc rollback` then reboot (see
  docs/recovery.md).
* On a non-atomic host you cannot rebase — install Bazzite first from its
  ISO, then switch to the custom image.

## 3. First boot: Sway session

After the reboot, at the SDDM login screen:

1. Click the session selector (bottom-left) → **niri** (next to the default
   KDE Plasma session, which remains as fallback).
2. Log in. You should see: the noctalia bar/shell, kero terminal via
   `Super+Enter`, the noctalia launcher via `Super+D`/`Super+Space` — the
   same keymap as the NixOS setup this session was ported from
   (docs/nixos-port-map.md).

If niri fails to start (driver regression, config error): log out, pick the
KDE session at SDDM, fix, retry. That is exactly why the KDE session is
kept. See troubleshooting below.

### What the image contains

Fedora packages (verified 2026-11): niri (ships
`/usr/share/wayland-sessions/niri.desktop` — that is what makes SDDM offer
niri), noctalia, foot (fallback terminal), swaylock, xwayland-satellite,
xdg-desktop-portal-gnome/gtk (screen sharing), xdg-terminal-exec, grim,
slurp, swappy, wl-clipboard, brightnessctl, playerctl, ddcutil, wlsunset,
fish, tmux, just, fcitx5 (+ chinese-addons/rime/gtk/qt/configtool), the
font set (Noto CJK/emoji, JetBrains Mono, Fira Code, Intel One Mono),
ladspa-swh-plugins, ollama, openssh-server, tuned.

Release tarballs pinned by sha256 in `build_files/build.sh`: kero (terminal,
Mod+Return), strata (file manager + FileChooser portal), Maple Mono NF CN
and JetBrainsMono Nerd Font (the two fonts Fedora does not package).

Polkit agent: the KDE one already in Bazzite
(`/usr/libexec/polkit-kde-authentication-agent-1`), started from the niri
spawn-at-startup config. PipeWire/WirePlumber: already in the Bazzite base.

### NVIDIA caveat

niri works with the NVIDIA proprietary driver; the base image choice
(`bazzite-nvidia-open`) matches this machine. If niri misbehaves after a
driver update: boot the KDE session (still installed) and roll back the
image (`sudo bootc rollback`).

The original KDE desktop is always available as fallback — by design.

## 4. User configuration + software

```bash
git clone git@github.com:<owner>/<repo>.git ~/dotfiles
cd ~/dotfiles
./scripts/bootstrap.sh                       # checks the environment
chezmoi --source ~/dotfiles/home/chezmoi diff    # PREVIEW first
chezmoi --source ~/dotfiles/home/chezmoi apply
./scripts/install-user-timer.sh              # hourly inventory capture
./scripts/inventory.sh capture               # first inventory for this machine
```

Optional first-boot extras (ports of the main branch's NixOS config — see
docs/nixos-port-map.md):

```bash
ujust atomic-ws-user-apps     # magpie ghostty pig opengrep r8 mygo rime-ice
just brew-seed                # CLI/dev tools (brew translation of home/packages)
just flatpak-seed             # GUI apps (flathub translation of the GUI packages)
ujust atomic-ws-set-shell-fish  # fish as login shell (chsh — machine state)
ujust atomic-ws-ollama-pull   # kev:4b-q4_K_M (runtime model state)
```

Existing files: chezmoi `apply` would overwrite conflicts — run `diff`
first; if you have local configs you want to keep, back them up or move the
conflicting file aside, apply, then merge by hand.

Machine-specific niri overrides: the ported config includes live in
`~/.config/niri/*.kdl` (managed by chezmoi); the hardware file
(`niri-hardware.kdl`) holds this laptop's eDP-1 mode/scale — edit it
locally after applying, or `chezmoi unmanage` it.

## 5. Verify everything

```bash
./scripts/doctor.sh
```

[OK]/[WARN]/[FAIL] output for: bootc status, booted image, niri session
entry, niri/noctalia/kero/strata/foot binaries, portals, flatpak + flathub,
brew, distrobox, chezmoi drift, timer state, git state.

## Troubleshooting

| symptom | fix |
| --- | --- |
| No niri entry at SDDM | image not actually booted (`sudo bootc status`); or you are still on stock Bazzite |
| niri session starts, then black screen | try the KDE session; check `~/.local/share/niri.log` (niri-session) |
| kero/strata/foot "command not found" inside niri | those come from the custom image — you booted the wrong image |
| ghostty "command not found" | ghostty is a user app: `ujust atomic-ws-user-apps` (or `just user-apps`) |
| Screen sharing does nothing | `systemctl --user status xdg-desktop-portal-gnome`; log out/in once |
| CI fails at "Verify signing prerequisites" | `SIGNING_SECRET` missing or cosign.pub still placeholder (see §1.2) |
| CI fails at build | check the Actions log — usually `BASE_IMAGE` name typo in image-template.env |
