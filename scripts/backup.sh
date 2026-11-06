#!/usr/bin/env bash
# backup.sh — restic wrapper for USER DATA (not the whole home).
#
#   ./scripts/backup.sh init        create the restic repository
#   ./scripts/backup.sh run         backup (interactive confirm of target+paths)
#   ./scripts/backup.sh snapshots   list snapshots
#   ./scripts/backup.sh check       verify repository integrity
#
# Configuration (first found wins):
#   1. $ATOMIC_WS_BACKUP_ENV        (file with KEY=VALUE lines, see below)
#   2. ~/.config/atomic-workstation/backup.env
#   3. <repo>/.env  (gitignored!)
#
# Required vars:
#   RESTIC_REPOSITORY       where to back up (path, sftp:, s3:, b2:, rest:...)
#   RESTIC_PASSWORD_FILE    file containing the password (NEVER commit it!)
# Optional:
#   BACKUP_PATHS            space-separated, default: ~/Documents ~/Pictures
#   BACKUP_EXCLUDES         newline-separated patterns appended to defaults
#   RESTIC_*                passed through to restic (e.g. AWS creds)
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
# shellcheck disable=SC1091
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

CMD="${1:-}"
[[ -n "$CMD" ]] || {
    cat <<'EOF'
usage: ./scripts/backup.sh <init|run|snapshots|check> [--yes]

read config from ~/.config/atomic-workstation/backup.env (see .env.example)
EOF
    exit 2
}
shift || true

CONF=""
for candidate in \
    "${ATOMIC_WS_BACKUP_ENV:-}" \
    "${HOME}/.config/atomic-workstation/backup.env" \
    "${ATOMIC_WS_ROOT}/.env"; do
    [[ -n "$candidate" && -f "$candidate" ]] && {
        CONF="$candidate"
        break
    }
done
if [[ -z "$CONF" ]]; then
    aw_die "no backup config found — copy .env.example to ~/.config/atomic-workstation/backup.env and edit it"
fi
set -a
# shellcheck disable=SC1090
. "$CONF"
set +a
aw_info "config: $CONF"

: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is not set in $CONF}"
if [[ -z "${RESTIC_PASSWORD_FILE:-}" && -z "${RESTIC_PASSWORD_COMMAND:-}" && -z "${RESTIC_PASSWORD:-}" ]]; then
    aw_die "no RESTIC_PASSWORD_FILE / RESTIC_PASSWORD_COMMAND set in $CONF (do not hardcode passwords)"
fi
if [[ -n "${RESTIC_PASSWORD:-}" ]]; then
    aw_warn "RESTIC_PASSWORD set directly in env — prefer RESTIC_PASSWORD_FILE for hygiene"
fi

aw_have restic || aw_die "restic is not installed (brew install restic, or dnf install restic)"

BACKUP_PATHS="${BACKUP_PATHS:-$HOME/Documents $HOME/Pictures}"
DEFAULT_EXCLUDES="$HOME/.cache
**/.cache
**/node_modules
**/__pycache__
**/.venv
**/target
**/*.tmp
$HOME/.local/share/containers"
BACKUP_EXCLUDES="${BACKUP_EXCLUDES:-}"
ALL_EXCLUDES="${DEFAULT_EXCLUDES}
${BACKUP_EXCLUDES}"

EXCLUDE_ARGS=()
while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    EXCLUDE_ARGS+=(--exclude "$pattern")
done <<<"$ALL_EXCLUDES"

case "$CMD" in
init)
    aw_step "initialising restic repository: $RESTIC_REPOSITORY"
    aw_confirm "create a NEW restic repository there?" || aw_die "aborted"
    exec restic init
    ;;
run)
    aw_step "backup target: $RESTIC_REPOSITORY"
    aw_info "paths:   $BACKUP_PATHS"
    aw_info "excludes: $(printf '%s' "$ALL_EXCLUDES" | wc -l) patterns"
    aw_have notify-send && notify-send "atomic-workstation backup" "starting → $RESTIC_REPOSITORY" 2>/dev/null || true
    exec restic backup $BACKUP_PATHS "${EXCLUDE_ARGS[@]}" --verbose
    ;;
snapshots)
    exec restic snapshots
    ;;
check)
    aw_step "checking repository integrity (read-only)"
    exec restic check --read-data-subset=1G
    ;;
*)
    aw_die "unknown command: $CMD (init|run|snapshots|check)"
    ;;
esac
