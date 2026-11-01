# security — atomic-workstation

## Threat model (brief)

The repo is (semi-)public on GitHub. Goals: no secrets in git, signed images,
least-privilege automation, explicit consent for destructive actions.

## Secrets policy

**Never in git** (enforced by `.gitignore`):

```gitignore
cosign.key        # image signing PRIVATE key
.env / .env.*     # local config (backup targets, tokens)
*.secret *.pem *.p12 *.pfx *.key
secrets/*         # EXCEPT sops-encrypted .json/.yaml (see below)
```

This repo ALSO keeps an existing sops+age setup (pre-dating
atomic-workstation) for NixOS secrets: `.sops.yaml` declares the age keys,
and `secrets/` holds ONLY encrypted files. The gitignore lets encrypted
`.json`/`.yaml` through and blocks everything else dropped into `secrets/`.
If you add a new encrypted secret with another extension, either name it
`.yaml`/`.json` or extend the negation patterns.

Never stored here: SSH private keys, access tokens, browser profiles,
application login data, recovery codes. Those belong in your password
manager and your (restic) backups — the backup config deliberately
defaults to a much smaller path set.

## Image signing

* `cosign.pub` — PUBLIC key, committed. Anyone can verify the image:
  ```bash
  cosign verify --key cosign.pub ghcr.io/<owner>/atomic-workstation:latest
  ```
* `cosign.key` — PRIVATE key, **local only** (gitignored), protected by a
  passphrase. Stored in GitHub Actions as TWO repository secrets:
  `SIGNING_SECRET` (the key itself) and `SIGNING_PASSWORD` (its passphrase).
  Unlike the upstream ublue-os template — which requires a passwordless key
  (`COSIGN_PASSWORD="" cosign generate-key-pair`) — this repo keeps the key
  encrypted, so build.yml passes `COSIGN_PASSWORD` from `SIGNING_PASSWORD`
  when signing. `scripts/init-signing.sh` prints the exact setup steps.
* CI (build.yml) refuses to build/publish when the secret is missing or the
  public key is still the placeholder — an unsigned image is never pushed.
* The workflow pins every third-party action to a commit SHA (same pins as
  ublue-os/image-template) and uses `GITHUB_TOKEN` with minimal
  permissions: `contents: read`, `packages: write`.

## Automation privileges

* The inventory timer is a **user** systemd unit: no root, no sudo. It reads
  `flatpak list`, `brew leaves`, `distrobox list` — package metadata only,
  no documents, no history, no telemetry.
* It writes ONLY under `apps/*/inventory` and `containers/inventory` in the
  clone it runs from.
* It never commits, never pushes, never resets git state.
* Failures land in the journal: `journalctl --user -u atomic-workstation-inventory`.

## Destructive-action consent

| action | consent mechanism |
| --- | --- |
| flatpak prune (`restore --prune`) | interactive `Type 'yes'`; `--yes` is ignored for prune by design |
| container replacement (`assemble --replace`) | you type the command manually; restore never passes --replace |
| git push | manual `sync.sh --push` only; timer cannot push |
| bootc switch / rollback / reboot | documentation only — never scripted |
| restic backup target | printed before every run; `backup.sh` refuses literal passwords |

## Inventory privacy notes

The inventory files record application IDs, remote URLs, and container
image names — that is all. If you consider your app list sensitive, keep
the repo private (GHCR images can stay public independently).

## Reporting/checking

```bash
# anything that would be committed but looks secret?
git add -A -n 2>/dev/null | grep -Ei 'key|secret|token|pem|p12' || echo clean
# is cosign.key really ignored?
git check-ignore -v cosign.key
# does the image verify?
cosign verify --key cosign.pub ghcr.io/<owner>/atomic-workstation:latest
```
