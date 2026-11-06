# atomic-workstation helpers — ujust recipes baked into the image.
#
# The FILE NAME is load-bearing. `ujust` does not glob
# /usr/share/ublue-os/just: /usr/share/ublue-os/justfile imports every recipe
# file EXPLICITLY, and the single slot reserved for custom images is
#
#     import? "/usr/share/ublue-os/just/60-custom.just"
#
# (`import?` tolerates the file being absent). These recipes must therefore
# live in 60-custom.just. Under any other name -- the file shipped as
# 99-atomic-workstation.just before this fix -- nothing imports them, and
# `ujust atomic-ws-doctor` fails with "justfile does not contain recipe" no
# matter how correct the file contents are.
#
# These recipes wrap the scripts in the dotfiles repo (default ~/dotfiles,
# override with the ATOMIC_WORKSTATION_DIR environment variable).
# See docs/software-management.md and docs/nixos-port-map.md.

# Health check of the atomic-workstation setup (bootc/niri/apps/git state)
[group('atomic-workstation')]
atomic-ws-doctor *args:
    #!/usr/bin/env bash
    set -euo pipefail
    REPO="${ATOMIC_WORKSTATION_DIR:-$HOME/dotfiles}"
    if [[ ! -x "$REPO/scripts/doctor.sh" ]]; then
        echo "atomic-workstation repo not found at: $REPO" >&2
        echo "Clone it first:  git clone git@github.com:lynimbus/dotfiles.git ~/dotfiles" >&2
        echo "...or export ATOMIC_WORKSTATION_DIR=/path/to/your/clone" >&2
        exit 1
    fi
    exec "$REPO/scripts/doctor.sh" "$@"

# Capture this machine's software inventory into the repo (flatpak/brew/distrobox)
[group('atomic-workstation')]
atomic-ws-sync *args:
    #!/usr/bin/env bash
    set -euo pipefail
    REPO="${ATOMIC_WORKSTATION_DIR:-$HOME/dotfiles}"
    if [[ ! -x "$REPO/scripts/sync.sh" ]]; then
        echo "atomic-workstation repo not found at: $REPO" >&2
        echo "Clone it first:  git clone git@github.com:lynimbus/dotfiles.git ~/dotfiles" >&2
        echo "...or export ATOMIC_WORKSTATION_DIR=/path/to/your/clone" >&2
        exit 1
    fi
    exec "$REPO/scripts/sync.sh" "$@"

# Restore software and user configuration from the repo onto this machine
[group('atomic-workstation')]
atomic-ws-restore *args:
    #!/usr/bin/env bash
    set -euo pipefail
    REPO="${ATOMIC_WORKSTATION_DIR:-$HOME/dotfiles}"
    if [[ ! -x "$REPO/scripts/restore.sh" ]]; then
        echo "atomic-workstation repo not found at: $REPO" >&2
        echo "Clone it first:  git clone git@github.com:lynimbus/dotfiles.git ~/dotfiles" >&2
        echo "...or export ATOMIC_WORKSTATION_DIR=/path/to/your/clone" >&2
        exit 1
    fi
    exec "$REPO/scripts/restore.sh" "$@"

# Install/update the GitHub-release user apps (magpie, ghostty, opengrep,
# r8, mygo) — the pieces the main branch used to build with Nix overlay pkgs
[group('atomic-workstation')]
atomic-ws-user-apps *args:
    #!/usr/bin/env bash
    set -euo pipefail
    REPO="${ATOMIC_WORKSTATION_DIR:-$HOME/dotfiles}"
    if [[ ! -x "$REPO/scripts/install-user-apps.sh" ]]; then
        echo "atomic-workstation repo not found at: $REPO" >&2
        echo "Clone it first:  git clone git@github.com:lynimbus/dotfiles.git ~/dotfiles" >&2
        echo "...or export ATOMIC_WORKSTATION_DIR=/path/to/your/clone" >&2
        exit 1
    fi
    exec "$REPO/scripts/install-user-apps.sh" "$@"

# Carry the Flatpak QQ profile (~/.var/app/com.qq.QQ/config/QQ, ~1.5 GB) over
# to the native build's config path (~/.config/QQ) before the Flatpak is
# uninstalled. A copy, never a move: the Flatpak tree stays the fallback.
# Run it, then quit QQ, then `flatpak uninstall com.qq.QQ` once native works.
[group('atomic-workstation')]
atomic-ws-qq-migrate *args:
    #!/usr/bin/env bash
    set -euo pipefail
    REPO="${ATOMIC_WORKSTATION_DIR:-$HOME/dotfiles}"
    if [[ ! -x "$REPO/scripts/migrate-qq-from-flatpak.sh" ]]; then
        echo "atomic-workstation repo not found at: $REPO" >&2
        echo "Clone it first:  git clone git@github.com:lynimbus/dotfiles.git ~/dotfiles" >&2
        echo "...or export ATOMIC_WORKSTATION_DIR=/path/to/your/clone" >&2
        exit 1
    fi
    exec "$REPO/scripts/migrate-qq-from-flatpak.sh" "$@"

# Port of system/users.nix: fish as the login shell (opt-in; it touches
# /etc, which stays machine state on atomic systems).
#
# NOTE: Bazzite's util-linux build ships without /usr/bin/chsh (verified on
# the booted image: `rpm -V util-linux` reports "missing /usr/bin/chsh"), so
# the historical `chsh -s` body failed with "command not found". Prefer chsh
# when it exists and otherwise use `usermod -s`, which shadow-utils provides.
[group('atomic-workstation')]
atomic-ws-set-shell-fish:
    #!/usr/bin/env bash
    set -euo pipefail
    current="$(getent passwd "${USER}" | cut -d: -f7)"
    if [[ "$current" == "/usr/bin/fish" || "$current" == "/bin/fish" ]]; then
        echo "login shell is already fish"
        exit 0
    fi
    if command -v chsh >/dev/null 2>&1; then
        exec chsh -s /usr/bin/fish
    fi
    # chsh is absent on Bazzite; usermod -s does the same edit of /etc/passwd.
    echo "chsh not found — falling back to usermod -s /usr/bin/fish" >&2
    exec sudo usermod -s /usr/bin/fish "${USER}"

# Port of system/ollama.nix loadModels — the model is runtime state, so it
# cannot be baked into the image
[group('atomic-workstation')]
atomic-ws-ollama-pull model="kev:4b-q4_K_M":
    #!/usr/bin/env bash
    set -euo pipefail
    exec sudo -u ollama ollama pull "{{model}}"

# Port of system/users.nix security.sudo.wheelNeedsPassword = false.
# Opt-in: baking passwordless wheel sudo into a published image would be a
# security regression for anyone else consuming it.
[group('atomic-workstation')]
atomic-ws-sudo-nopasswd:
    #!/usr/bin/env bash
    set -euo pipefail
    # The invoking user, not "whoever sudo says we are".
    target_user="${SUDO_USER:-${USER}}"
    if [[ -z "$target_user" || "$target_user" == root ]]; then
        echo "run this as your normal user (not via sudo), e.g. ujust atomic-ws-sudo-nopasswd" >&2
        exit 1
    fi
    echo "${target_user} ALL=(ALL) NOPASSWD: ALL" |
        sudo tee "/etc/sudoers.d/90-${target_user}-nopasswd" >/dev/null
    sudo chmod 440 "/etc/sudoers.d/90-${target_user}-nopasswd"
    echo "passwordless sudo enabled for ${target_user}"
