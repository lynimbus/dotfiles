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

1. Click the session selector (bottom-left) → **Sway** (next to the default
   KDE Plasma session, which remains as fallback).
2. Log in. You should see: solid dark wallpaper, waybar on top,    foot terminal via `Super+Enter`, wofi launcher via `Super+D`.

If Sway fails to start (driver regression, config error): log out, pick the
KDE session at SDDM, fix, retry. That is exactly why the KDE session is
kept. See troubleshooting below.

### What the image contains (all from Fedora repos, verified 2026-10)

sway (+ sway-config-upstream which ships `/usr/share/wayland-sessions/sway.desktop`
— that is what makes SDDM offer Sway), swayidle, swaylock, swaybg, waybar,
foot, mako, wofi, kanshi, grim, slurp, wl-clipboard, brightnessctl,
playerctl, xdg-desktop-portal-wlr, xdg-desktop-portal-gtk.

Polkit agent: the KDE one already in Bazzite
(`/usr/libexec/polkit-kde-authentication-agent-1`), started from the sway
config. PipeWire/WirePlumber: already in the Bazzite base.

### NVIDIA caveat

Sway works with the NVIDIA proprietary driver on most setups, but it is the
least-tested path in the Sway ecosystem. Known limitations:

* Use the `bazzite-nvidia` base variant (correct driver + kernel params).
* Screen sharing/copy sometimes needs `WLR_DRM_NO_ATOMIC=1` — if you hit it,
  add it in `~/.config/sway/conf.d/10-nvidia.conf` (untracked drop-in) as
  `exec systemctl --user set-environment WLR_DRM_NO_ATOMIC=1` or export it in
  the session. Test before relying on it.
* If Sway misbehaves after a driver update: boot the KDE session (still
  installed) and roll back the image (`sudo bootc rollback`).

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

Existing files: chezmoi `apply` would overwrite conflicts — run `diff`
first; if you have local configs you want to keep, back them up or move the
conflicting file aside, apply, then merge by hand.

Machine-specific sway overrides go in `~/.config/sway/conf.d/*.conf`
(included last, NOT managed by chezmoi). Monitor setup lives in
`~/.config/kanshi/config` — edit it locally after applying.

## 5. Verify everything

```bash
./scripts/doctor.sh
```

[OK]/[WARN]/[FAIL] output for: bootc status, booted image, sway session
entry, waybar/foot/… binaries, portals, flatpak + flathub, brew, distrobox,
chezmoi drift, timer state, git state.

## Troubleshooting

| symptom | fix |
| --- | --- |
| No Sway entry at SDDM | image not actually booted (`sudo bootc status`); or you are still on stock Bazzite |
| Sway session starts, then black screen | try the KDE session; check `~/.local/share/sway.log`; remove `~/.config/sway/conf.d/*` drop-ins |
| Waybar/foot "command not found" inside Sway | those come from the custom image — you booted the wrong image |
| Screen sharing does nothing | `systemctl --user status xdg-desktop-portal-wlr`; log out/in once |
| CI fails at "Verify signing prerequisites" | `SIGNING_SECRET` missing or cosign.pub still placeholder (see §1.2) |
| CI fails at build | check the Actions log — usually `BASE_IMAGE` name typo in image-template.env |
