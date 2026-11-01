#!/usr/bin/env bash
# init-signing.sh — generate the image signing key pair and print setup steps.
#
# cosign.pub is committed to the repo (PUBLIC). cosign.key stays LOCAL —
# it is gitignored and must NEVER be committed. The private key goes to
# GitHub as the repository secret SIGNING_SECRET (you do this in the
# GitHub web UI; this script only prints the exact steps).
#
# Usage: ./scripts/init-signing.sh [--force]
set -euo pipefail

ATOMIC_WS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/lib/common.sh
# shellcheck disable=SC1091
source "${ATOMIC_WS_ROOT}/scripts/lib/common.sh"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

cd "$ATOMIC_WS_ROOT"
if ! aw_have cosign; then
    aw_die "cosign is not installed — get it from https://github.com/sigstore/cosign/releases (or brew install cosign)"
fi

if grep -q 'BEGIN PUBLIC KEY' cosign.pub 2>/dev/null && [[ $FORCE -eq 0 ]]; then
    aw_die "cosign.pub already contains a real key — refusing to overwrite (use --force to regenerate)"
fi
if [[ -f cosign.key ]]; then
    aw_die "cosign.key exists — moving on without regenerating (delete it first if you really want new keys)"
fi

aw_step "generating key pair (you will be asked for a passphrase)"
cosign generate-key-pair
# cosign writes cosign.key + cosign.pub in the current directory

if ! grep -q 'BEGIN PUBLIC KEY' cosign.pub; then
    aw_die "cosign.pub was not written correctly — check the cosign output above"
fi
aw_ok "public key written to cosign.pub (commit this)"
aw_ok "private key written to cosign.key (KEEP LOCAL — already gitignored)"

if git check-ignore -q cosign.key; then
    aw_ok ".gitignore already excludes cosign.key"
else
    aw_error "cosign.key is NOT gitignored — add it before committing anything!"
fi

cat <<'EOF'

────────────────────────────────────────────────────────────────────────
NEXT STEPS (manual, in this order):

1. Commit the new public key:
       git add cosign.pub && git commit -m "feat(signing): add image signing public key"

2. Store the PRIVATE key as the GitHub Actions secret SIGNING_SECRET:
       GitHub → your repo → Settings → Secrets and variables → Actions
       → "New repository secret"
         Name:  SIGNING_SECRET
         Value: the full contents of cosign.key (including the BEGIN/END lines)

   (or, with the gh CLI:  gh secret set SIGNING_SECRET < cosign.key)

3. Keep cosign.key + its passphrase somewhere safe (password manager).
   Losing it means you cannot sign future images with the same identity.

4. Verify a published image:
       cosign verify --key cosign.pub ghcr.io/lynimbus/atomic-workstation:latest
────────────────────────────────────────────────────────────────────────
EOF
aw_ok "signing initialised"
