# ═══════════════════════════════════════════════════════════════════
# atomic-workstation helpers — ujust recipes baked into the image.
#
# ujust discovers every *.just file under /usr/share/ublue-os/just/.
# These recipes wrap the scripts in the dotfiles repo (default ~/dotfiles,
# override with the ATOMIC_WORKSTATION_DIR environment variable).
# See docs/software-management.md and docs/nixos-port-map.md.
# ═══════════════════════════════════════════════════════════════════

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

# Install/update the GitHub-release user apps (magpie, ghostty, pig, opengrep,
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

# Port of system/users.nix: fish as the login shell (opt-in — chsh touches
# /etc, which stays machine state on atomic systems)
[group('atomic-workstation')]
atomic-ws-set-shell-fish:
    #!/usr/bin/env bash
    set -euo pipefail
    current="$(getent passwd "${USER}" | cut -d: -f7)"
    if [[ "$current" == "/usr/bin/fish" || "$current" == "/bin/fish" ]]; then
        echo "login shell is already fish"
        exit 0
    fi
    exec chsh -s /usr/bin/fish

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
