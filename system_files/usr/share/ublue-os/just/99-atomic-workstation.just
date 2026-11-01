# ═══════════════════════════════════════════════════════════════════
# atomic-workstation helpers — ujust recipes baked into the image.
#
# ujust discovers every *.just file under /usr/share/ublue-os/just/.
# These recipes wrap the scripts in the dotfiles repo (default ~/dotfiles,
# override with the ATOMIC_WORKSTATION_DIR environment variable).
# See docs/software-management.md.
# ═══════════════════════════════════════════════════════════════════

# Health check of the atomic-workstation setup (bootc/sway/apps/git state)
[group('atomic-workstation')]
atomic-ws-doctor:
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
atomic-ws-sync:
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
atomic-ws-restore:
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
