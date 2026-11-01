# software management — atomic-workstation

How to install things, and how the repo finds out about them.

## Priority order (use the simplest thing that works)

1. **Bazzite ujust** — system integrations. Run `ujust` to list; this repo
   adds `ujust atomic-ws-doctor / atomic-ws-sync / atomic-ws-restore`.
2. **Flatpak** — GUI apps. `flatpak install flathub org.mozilla.firefox`.
   Discoverable in GNOME Software / the Bazzite Portal too.
3. **Homebrew** — CLI/TUI apps. `brew install ripgrep fd bat eza`.
   (Preinstalled on Bazzite since 2024; run `ujust install-brew` if absent.)
4. **Distrobox** — dev toolchains and distro-specific builds.
   `distrobox enter fedora-dev`, then install anything inside.
5. **AppImage** — rare cases; keep them in `~/Applications` (not tracked).
6. **rpm-ostree layering** (`rpm-ostree install <pkg>`) — LAST resort:
   layering breaks atomic updates' cleanliness. If you need a package on
   the host, prefer adding it to `build_files/build.sh` and rebuilding the
   image (a PR to yourself).
7. **Custom OCI image** — for system components that must be host-integrated
   (this repo's Sway stack is the example).

## The inventory: automatic discovery

You never maintain package lists by hand. A systemd **user timer** (hourly,
catches up after sleep) runs `scripts/inventory.sh capture`:

| source | output file | what is recorded |
| --- | --- | --- |
| flatpak | `apps/flatpak/inventory/<profile>.json` | app ID, origin remote (+URL), user/system scope, branch, arch |
| homebrew | `apps/brew/inventory/<profile>/Brewfile` + `leaves.<profile>.txt` | full `brew bundle dump` + which formulae you actually requested |
| distrobox | `containers/inventory/<profile>.json` | container name, image, bootstrap script presence |

* **profile** = machine identity: `WORKSTATION_PROFILE` env var, else the
  hostname. Two machines → two profiles → two files. They never overwrite
  each other.
* Files are **sorted and stable**: re-running capture on an unchanged
  machine produces a byte-identical file (no meaningless git diffs).
* The timer **never commits and never pushes**. It only writes the files.
  `journalctl --user -u atomic-workstation-inventory` shows what it did.

Check state any time:

```bash
./scripts/inventory.sh status      # diff machine vs committed inventory
./scripts/inventory.sh capture     # scan now
./scripts/sync.sh                  # capture + show git state
./scripts/sync.sh --commit         # + commit ONLY the inventory files
./scripts/sync.sh --push           # + push (manual, never automatic)
```

Auto-push is off by default and stays off: `sync.sh` reads no AUTO_PUSH env.
The timer unit runs `inventory.sh capture` — nothing that can push.

### Known honest limitations

* `brew bundle dump` records the FULL installed state including
  dependencies — the Brewfile is a restore snapshot, not a curated list.
  `leaves.<profile>.txt` captures what you personally requested; the header
  says so. Restoring installs everything in the file.
* Uninstalls are NOT captured automatically. If you remove an app, the old
  entry stays until you prune or edit the inventory (see below).
* Flatpak remote *filters* (repo filtering) are not synced — only URLs.

## Restore (new machine / after reinstall)

```bash
./scripts/restore.sh               # everything, in order
./scripts/restore.sh --skip-config # only software, no chezmoi
./scripts/inventory.sh restore     # just the software part
```

Flatpak restore is **additive**: adds missing remotes (from saved URLs),
installs missing apps in their original scope (user/system). It NEVER
uninstalls anything that is already there.

Removing apps that are not in the inventory is strictly opt-in:

```bash
./scripts/inventory.sh restore --prune            # lists, then asks "Type 'yes'"
./scripts/inventory.sh restore --prune --dry-run  # list only, change nothing
./apps/flatpak/restore.sh <profile> --prune --dry-run   # flatpak only
```

`--yes` deliberately cannot bypass the prune confirmation.

`inventory.sh status` never changes anything: it diffs the machine against
the committed inventory (flatpak apps+remotes, missing Brewfile entries,
declared-but-missing containers).

## Profiles and multi-machine flow

```bash
# machine A (laptop)
WORKSTATION_PROFILE=laptop ./scripts/inventory.sh capture
WORKSTATION_PROFILE=laptop ./scripts/sync.sh --commit --push

# machine B (desktop) — set its profile in the timer env file
mkdir -p ~/.config/atomic-workstation
echo "WORKSTATION_PROFILE=desktop" >> ~/.config/atomic-workstation/inventory.env
# (systemctl --user edit atomic-workstation-inventory.service and add:
#  [Service]
#  EnvironmentFile=-%h/.config/atomic-workstation/inventory.env)

# restore desktop's set onto a fresh desktop
./scripts/restore.sh --profile desktop
```

## Dev containers

Declared in `containers/distrobox.ini` (declarative `distrobox assemble`
format — the section name IS the container name). Add one:

```ini
[my-toolbox]
image=registry.fedoraproject.org/fedora-toolbox:42
additional_packages="gcc cmake"
```

```bash
./containers/restore.sh            # creates missing containers, runs
                                   # containers/bootstrap/<name>.sh inside NEW ones
```

Existing containers are never replaced or destroyed automatically. To force
recreation: `distrobox assemble create --replace --file containers/distrobox.ini`
(you type it).

## What about the NixOS side of this repo?

This repo also manages a NixOS host via `flake.nix` (the original purpose).
The atomic-workstation parts live alongside it and do not interact:
chezmoi's source is `home/chezmoi/` (NOT the repo root), the image build
uses `justfile`'s `image-*` recipes, and the NixOS `switch/build` recipes
are untouched. On the NixOS host, inventory capture simply skips
(flatpak/brew/distrobox absent → [SKIP] messages, exit 0).
