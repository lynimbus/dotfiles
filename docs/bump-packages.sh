#!/usr/bin/env bash
# Move the packages in pkgs/ that track an upstream release to that release's
# latest version.
#
# A package pins its version and every hash as literals in its own file, and
# nix-update rewrites them through '--flake legacyPackages.<system>.<attr>':
# version, asset hash, vendorHash and any --custom-dep in the same file move in
# one run, so no release has a second version source that can drift.
#
# Which packages track a release, and the extra nix-update flags each needs, is
# declared by the package file itself in passthru.bump; flake.nix collects them
# into legacyPackages.<system>.bumpMatrix. Adding a package therefore never
# means editing this script.
#
# Some tokens in passthru.bump are not nix-update flags but indices this
# script reads itself, before nix-update runs:
#
#   --bump-maven=<url>    a Maven repository to take the version from; see
#                         maven_latest_stable and why r8 needs it.
#   --bump-manifest=<url> a release manifest whose .version is the newest
#                         release. It becomes a fixed --version and nix-update
#                         still derives every hash itself; herdr-core publishes
#                         one at core/latest.json.
#   --bump-app-manifest=<url>
#                         Google's app update manifest, the electron-updater
#                         shape Antigravity publishes: the version at the top,
#                         and in every asset URL that same version with the
#                         build id appended as the path segment ahead of the
#                         platform. The download only resolves with both, so
#                         the script reads both out of the one answer and
#                         writes the build id itself; see app_manifest_release.
#
# --bump-manifest= only names a version, so the src rewrite and --build stay.
# --bump-app-manifest= also names a build id that must be in the file before
# nix-update fetches that version, so it is written first.
#
# Usage:
#   docs/bump-packages.sh              # every package that tracks a release
#   docs/bump-packages.sh pig kero     # just those
#
# A failed rewrite can leave a half-updated file, version written and hash not.
# The run compares pkgs/ before and after each package and says whether that
# happened, so only the file that actually changed has to be restored. Never
# restore the whole directory: packages that already succeeded in the same run
# would be undone.
#
# The failure modes measured on 2026-11-09, plus one for the jj-only checkout,
# decide the defences below:
#
#   - A fetchurl package is re-fetched unconditionally: nix-update's version
#     comparison treats a fetchurl src as changed every time, because the
#     derivation carries no rev to compare. sing-box's 31MB asset then has to
#     be downloaded to confirm a hash that is already correct, and a transient
#     504 from release-assets.githubusercontent.com (nix's built-in curl window
#     is about 11s) ends the run with exit 1. Retrying is the right answer for
#     that and wrong for anything deterministic, hence the narrow match below:
#     version detection, a regex that matches nothing, an eval failure or a
#     failed --build behave the same on every attempt.
#   - A handshake can be cut instead of answered with 504: on 2026-11-19
#     dl.google.com ended the ClientHello with an unexpected EOF (curl exit 35)
#     and took the r8 index read with it. That EOF turned out to be DNS -- the
#     machine resolved the host to a China-only edge node its proxy exit cannot
#     use, while a Google IP answered 200 -- but a cut handshake is a network
#     break like a reset, not a deterministic failure, so 35 is retried.
#   - nix-update only knows how to enumerate releases from github, gitlab,
#     gitea, codeberg, sourcehut, savannah, pypi, npm, crates.io and rubygems.
#     A package published only to a Maven repository therefore has no version
#     to find and the run dies in VersionError before it touches the file, so
#     the package names its version index instead (--bump-maven=).
#   - A prebuilt binary can be served stale inside the release window, where
#     the CDN serves previous bytes behind a new tag's URL and nix-update
#     prefetches the old hash while writing the new version. Packages whose
#     hashes are release assets therefore carry --build, which runs the build
#     and install checks (including versionCheckHook) during the bump rather
#     than at switch time; source-built packages have vendorHash covered by
#     nix-update itself.
#   - nix-update shells out to `git diff` when the version it found equals the
#     pin (update.py: update_version -> git.old_version_from_git). Letting an
#     empty diff succeed makes nix-update fall through to replace_version and
#     re-fetch every src and dependency hash for an unchanged package. See the
#     git shim below.
# shellcheck source=docs/lib.sh
source "$(dirname "$0")/lib.sh"
cd "$repo_dir" || exit 1

github_token

# nix-update relies on two assumptions that break in this repo:
#
#   1. In a jj-only checkout (no .git), nix-update asks git for the old version
#      string whenever the version it found equals the pin (update.py:
#      update_version -> git.old_version_from_git). That `git diff` exits 129
#      and kills the run for every already-current package. Even in a colocated
#      jj/git checkout, letting an empty `git diff` succeed with exit 0 causes
#      nix-update to fall through to replace_version; any fetchurl package whose
#      --version-regex stripped a tag prefix (e.g. sing-box) then sees
#      new_version.rev != null and re-fetches and rebuilds an unchanged package.
#      Intercept `--word-diff=porcelain`: in a colocated checkout, delegate to
#      real git only when the target file actually has an uncommitted diff;
#      otherwise emit a marker and exit 42 so nix_update treats it as current.
#   2. nix-update calls `nix flake metadata --json` to copy the local flake into
#      /nix/store before passing that store path to `nix-instantiate` via
#      `builtins.getFlake` (options.py: get_flake_store_path). With Nix 2.35's
#      fetch-tree on a colocated git checkout, `nix flake metadata --json`
#      computes and prints `/nix/store/...-source` lazily without realizing it
#      on disk, so `nix-instantiate` fails with "No such file or directory" —
#      both before and immediately after nix-update edits a package file.
#      Shimming `nix` to run `nix flake prefetch --json .` before `nix flake
#      metadata --json` realizes the current (including dirty) tree into the
#      store so the path exists.
#
# nixpkgs wraps nix-update with makeWrapper, which prepends its own nix/bin to
# PATH and would shadow our nix shim. When `.nix-update-wrapped` sits beside the
# resolved binary, invoke it directly with our shim dir ahead of the wrapper's
# PATH entries.
shim_dir="$(mktemp -d)" || die "cannot create a temporary directory"
trap 'rm -rf "$shim_dir"' EXIT

real_nix="$(command -v nix)" || die "nix is not on PATH"
{
	printf '#!/usr/bin/env bash\nreal_nix=%q\n' "$real_nix"
	cat <<'EOF'
if [ "${1:-}" = "flake" ] && [ "${2:-}" = "metadata" ]; then
	for arg in "$@"; do
		if [ "$arg" = "--json" ]; then
			"$real_nix" flake prefetch --json . >/dev/null 2>&1 || true
			break
		fi
	done
fi
exec "$real_nix" "$@"
EOF
} >"$shim_dir/nix" || die "cannot write the nix shim"
chmod +x "$shim_dir/nix" || die "cannot make the nix shim executable"

nix_update_noop_marker='[bump] nix-update probed an unchanged checkout for its old version'
real_git="$(command -v git)" || die "git is not on PATH"
has_git=0
[ -e "$repo_dir/.git" ] && has_git=1
{
	printf '#!/usr/bin/env bash\nmarker=%q\nreal_git=%q\nhas_git=%q\n' "$nix_update_noop_marker" "$real_git" "$has_git"
	cat <<'EOF'
for arg in "$@"; do
	if [ "$arg" = "--word-diff=porcelain" ]; then
		if [ "$has_git" = 1 ]; then
			if diff_out="$("$real_git" "$@" 2>/dev/null)" && [ -n "$diff_out" ]; then
				printf '%s\n' "$diff_out"
				exit 0
			fi
		fi
		printf '%s\n' "$marker" >&2
		exit 42
	fi
done
exec "$real_git" "$@"
EOF
} >"$shim_dir/git" || die "cannot write the git shim"
chmod +x "$shim_dir/git" || die "cannot make the git shim executable"

system=x86_64-linux
NET_RETRY_RE='502|503|504|cannot download|failed to retrieve hash|timed out|Failed to connect|Connection reset|curl: \((6|7|22|28|35)\)'
retries=2
retry_delay=30

command -v nix-update >/dev/null || die "nix-update is not on PATH (it comes from home/packages.nix)"

nix_update_cmd=(nix-update)
nix_update_bin="$(readlink -f "$(command -v nix-update)")"
nix_update_wrapped="$(dirname "$nix_update_bin")/.nix-update-wrapped"
if [ -x "$nix_update_wrapped" ] && grep -q 'exec -a ' "$nix_update_bin"; then
	wrapper_path="$(grep -oE '/nix/store/[^'\'':"]+/bin' "$nix_update_bin" | awk '!seen[$0]++' | paste -sd: -)"
	nix_update_cmd=("$nix_update_wrapped")
	nix_update_env=(env "PYTHONNOUSERSITE=true" "PYTHONUNBUFFERED=1" "PATH=$shim_dir${wrapper_path:+:$wrapper_path}:$PATH")
else
	nix_update_env=(env "PYTHONUNBUFFERED=1" "PATH=$shim_dir:$PATH")
fi

# The newest stable version a Maven repository publishes, read out of its
# maven-metadata.xml. nix-update has no Maven fetcher, so a package that only
# ships to one (r8: the android tools repository on dl.google.com, no GitHub
# release, no JSON manifest) declares the index URL in passthru.bump as
# --bump-maven=<url> and gets the version handed to it as a fixed --version.
# Fixed is the one mode where nix-update does not look for a release at all: it
# takes the string as the new version and rewrites that and the hash in the
# package file, which is everything a bump has to move.
#
# <release> and <latest> are not the answer despite being there: Google Maven
# keeps both pointing at the newest upload, prereleases included (9.6.0-alpha12
# while 9.5.29 is the newest stable). A Maven qualifier is hyphenated by
# convention, so dropping hyphenated versions leaves the stable line, and -V
# orders 9.5.29 above 9.5.9 where a plain sort would not.
maven_latest_stable() {
	local url="$1" xml version
	xml="$(curl -fsSL --retry 2 --retry-delay 2 "$url")" || return 1
	version="$(
		grep -o '<version>[^<]\+</version>' <<<"$xml" |
			sed -e 's/<[^>]*>//g' |
			grep -E '^[0-9]+(\.[0-9]+)*$' |
			sort -V |
			tail -n 1
	)"
	[ -n "$version" ] || return 1
	printf '%s\n' "$version"
}

# The newest release a JSON manifest announces. Unlike a feed this states the
# version only, so nix-update still rewrites the src hash by fetching the new
# URL; --build then proves that hash and the versionCheckHook against the bytes.
# herdr-core's core/latest.json is one such manifest (.version at the top).
manifest_version() {
	local url="$1" json version
	json="$(curl -fsSL --retry 2 --retry-delay 2 "$url")" || return 1
	version="$(jq -r '.version // empty' <<<"$json")"
	[ -n "$version" ] || return 1
	printf '%s\n' "$version"
}

# The release a Google app update manifest announces: version on the first
# line, build id on the next.
#
# The manifest (Antigravity App publishes one per platform under
# antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/)
# states a release twice: `version:` at the top, and in every asset URL that
# same version with the build id appended,
# antigravity-hub/2.32.1-6001966350991360/. The storage path only resolves with
# both, so the second half is read out of the path rather than guessed at — and
# only from a segment that starts with the version the same answer states,
# which is what keeps a release caught halfway through rollout from writing a
# version from one upload and a build id from another.
#
# The answer is YAML and only this one line is taken from it, so the parse is a
# sed and a grep rather than a dependency on a YAML reader neither this script
# nor the machines it runs on otherwise have.
app_manifest_release() {
	local url="$1" yml version segment build_id
	yml="$(curl -fsSL --retry 2 --retry-delay 2 "$url")" || return 1
	version="$(sed -n 's/^version:[[:space:]]*\([^[:space:]]*\)$/\1/p' <<<"$yml" | head -n 1)"
	[ -n "$version" ] || return 1
	segment="$(tr -s ' \t/' '\n' <<<"$yml" | grep -m 1 -E '^[0-9]+(\.[0-9]+)+-[0-9]+$')" || return 1
	case "$segment" in
	"$version"-*) build_id="${segment#"$version"-}" ;;
	*) return 1 ;;
	esac
	printf '%s\n%s\n' "$version" "$build_id"
}

# True when the first version is newer than the second, comparing numeric
# components of a dotted version rather than text. A leading "v" and any
# non-numeric suffix after the digits are ignored.
version_newer() {
	local a="$1" b="$2" i x y
	local -a as bs
	IFS=. read -r -a as <<<"${a#v}"
	IFS=. read -r -a bs <<<"${b#v}"
	for ((i = 0; i < ${#as[@]} || i < ${#bs[@]}; i++)); do
		x="${as[i]:-0}"
		y="${bs[i]:-0}"
		# A suffix (a -rc1, a date) is dropped; the digits before it are what
		# compared. %%[!0-9]* keeps the whole string when it is already all digits,
		# and an empty part counts as 0, so a shorter version is not "newer".
		case "$x" in *[!0-9]*) x="${x%%[!0-9]*}" ;; esac
		case "$y" in *[!0-9]*) y="${y%%[!0-9]*}" ;; esac
		x="${x:-0}"
		y="${y:-0}"
		((10#$x > 10#$y)) && return 0
		((10#$x < 10#$y)) && return 1
	done
	return 1
}

matrix="$(nix eval --json ".#legacyPackages.$system.bumpMatrix")" ||
	die "cannot evaluate .#legacyPackages.$system.bumpMatrix"

# Packages that track a release, alphabetical.
mapfile -t rolling < <(jq -r 'to_entries[] | select(.value != null) | .key' <<<"$matrix")
((${#rolling[@]})) || die "no package declares passthru.bump"

pkgs=("$@")
if ((${#pkgs[@]} == 0)); then
	pkgs=("${rolling[@]}")
else
	for p in "${pkgs[@]}"; do
		printf '%s\n' "${rolling[@]}" | grep -qx -- "$p" ||
			die "$p does not track a release (no passthru.bump); known: ${rolling[*]}"
	done
fi

# stdout and stderr are teed to a per-package log, so the terminal keeps showing
# progress and the failure can still be classified. The exit code is the
# command's, not tee's.
run_nix_update() {
	local p="$1"
	shift
	local log attempt=0 rc
	log="$(mktemp)" || return 1
	while :; do
		attempt=$((attempt + 1))
		"$@" 2>&1 | tee "$log"
		rc=${PIPESTATUS[0]}
		if ((rc == 0)); then
			rm -f "$log"
			return 0
		fi
		if ((attempt > retries)); then
			rm -f "$log"
			return "$rc"
		fi
		if ! grep -qiE -- "$NET_RETRY_RE" "$log"; then
			rm -f "$log"
			return "$rc"
		fi
		echo "[bump] $p hit a network error on attempt $attempt of $((retries + 1)); retrying in ${retry_delay}s" >&2
		sleep "$retry_delay"
	done
}

# Runs nix-update with the git shim on PATH. Only the no-op decision reads a
# marker, and it is a marker the shim above wrote itself: nix-update's error
# wording is never consulted for control flow. The VersionError hint below is
# just a hint; if its wording changes, the exit code still decides the outcome.
nix_update() {
	local p="$1" log rc
	shift
	log="$(mktemp)" || return 1
	"${nix_update_env[@]}" "${nix_update_cmd[@]}" --flake "legacyPackages.$system.$p" "$@" 2>&1 |
		awk -v marker="$nix_update_noop_marker" -v logfile="$log" '
			BEGIN { suppressed = 0 }
			{
				print $0 > logfile
				fflush(logfile)
				if (!suppressed) {
					if (index($0, marker) > 0) {
						suppressed = 1
					} else {
						print $0
						fflush()
					}
				}
			}
		'
	rc=${PIPESTATUS[0]}
	if ((rc == 0)); then
		rm -f "$log"
		return 0
	fi
	# The shim answers before nix-update rewrites anything, so no package file
	# changed and no traceback needs to reach the terminal.
	if grep -qF -- "$nix_update_noop_marker" "$log"; then
		rm -f "$log"
		echo "[bump] $p: already current" >&2
		return 0
	fi
	if grep -q 'VersionError: Please specify the version' "$log"; then
		echo "[bump] $p: nix-update cannot enumerate this package's releases; declare a version index in passthru.bump (--bump-maven=, --bump-manifest= or --bump-app-manifest=)" >&2
	fi
	rm -f "$log"
	return "$rc"
}

# Turns what the package declared into the nix-update command line: the flags
# pass through untouched, a version index is read first. It runs inside
# run_nix_update's retry loop, so an index that 502s is retried on the same
# terms as a release asset that does, and its error text is in the log the
# retry match reads.
bump_package() {
	local p="$1"
	shift
	local arg url="" manifest="" app_manifest="" version="" build_id="" out current
	local -a pass=()
	# The --bump-* flags are read here rather than passed through to nix-update,
	# inside the retry loop: an index that 502s is then retried on the same terms
	# as a release asset that does, and its error text is in the log the retry
	# match reads.
	for arg in "$@"; do
		case "$arg" in
		--bump-maven=*) url="${arg#--bump-maven=}" ;;
		--bump-manifest=*) manifest="${arg#--bump-manifest=}" ;;
		--bump-app-manifest=*) app_manifest="${arg#--bump-app-manifest=}" ;;
		*) pass+=("$arg") ;;
		esac
	done

	if [ -n "$manifest" ]; then
		if ! version="$(manifest_version "$manifest")"; then
			echo "[bump] $p: cannot read the version manifest $manifest" >&2
			return 1
		fi
		echo "[bump] $p: $manifest publishes $version" >&2
	elif [ -n "$app_manifest" ]; then
		if ! out="$(app_manifest_release "$app_manifest")"; then
			echo "[bump] $p: cannot read the app manifest $app_manifest" >&2
			return 1
		fi
		version="$(sed -n 1p <<<"$out")"
		build_id="$(sed -n 2p <<<"$out")"
		echo "[bump] $p: $app_manifest publishes $version-$build_id" >&2
	elif [ -n "$url" ]; then
		if ! version="$(maven_latest_stable "$url")"; then
			echo "[bump] $p: cannot read the version index $url" >&2
			return 1
		fi
		echo "[bump] $p: $url publishes $version" >&2
	fi

	# Compare an indexed version against the pin before running nix-update:
	# prevents version downgrades when an index trails releases and skips
	# nix-update's git diff probe on already-current packages.
	if [ -n "$version" ]; then
		current="$(nix eval --raw ".#legacyPackages.$system.$p.version")" || return 1
		if ! version_newer "$version" "$current"; then
			echo "[bump] $p: at $current, not older than $version" >&2
			return 0
		fi
		pass+=("--version=$version")
	fi

	# The download URL carries the build id, so it has to be in the file before
	# nix-update fetches the release the version names: written from the literal
	# the derivation reports, so the replacement cannot land on another number.
	# From here on a failure leaves the file with the new build id and the old
	# version, which pkgs_checksum reports like any other half-write.
	if [ -n "$build_id" ]; then
		write_build_id "$p" "$build_id" || return 1
	fi

	if ! nix_update "$p" "${pass[@]}"; then
		return 1
	fi
}

# Rewrites the build id a package file pins. The file comes from the derivation
# and so does the old value (passthru.buildId), so the replacement cannot land
# on another number that happens to sit in the same file.
write_build_id() {
	local p="$1" new="$2" file old
	file="$(package_file "$p")" || return 1
	old="$(nix eval --raw ".#legacyPackages.$system.$p.passthru.buildId")" || return 1
	[ "$old" != "$new" ] || return 0
	if ! grep -qF -- "$old" "$file"; then
		echo "[bump] $p: $file carries no build id $old" >&2
		return 1
	fi
	OLD="$old" NEW="$new" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$file"
	echo "[bump] $p: build id -> $new" >&2
}

# The file a package was defined in, as a path in the checkout. meta.position
# names it in the flake source as nix copied it into the store, which is
# read-only; the same path under the checkout is the one nix-update rewrites.
package_file() {
	local p="$1" file store
	file="$(nix eval --raw ".#legacyPackages.$system.$p.meta.position")" || return 1
	file="${file%:*}"
	store="$(nix flake metadata --json | jq -r .path)" || return 1
	file="$repo_dir/${file#"$store"/}"
	[ -f "$file" ] || { echo "[bump] $p: $file is not in the checkout" >&2; return 1; }
	printf '%s\n' "$file"
}

# A checksum of every package file, taken before and after one package's run,
# is the only objective way to tell whether a failure left a half-written file.
# The advice has to be per-file: a successful package earlier in the same run
# has already written its own file, and 'jj restore pkgs/' would undo it too.
pkgs_checksum() {
	find pkgs -maxdepth 1 -type f -name '*.nix' -print0 |
		sort -z |
		xargs -0 cat |
		sha256sum
}

fail=()
for p in "${pkgs[@]}"; do
	args=()
	while IFS= read -r arg; do
		args+=("$arg")
	done < <(jq -r --arg p "$p" '.[$p][]' <<<"$matrix")

	before="$(pkgs_checksum)"
	if run_nix_update "$p" bump_package "$p" "${args[@]}"; then
		echo "[bump] $p ok"
	else
		fail+=("$p")
		if [ "$(pkgs_checksum)" = "$before" ]; then
			echo "[bump] $p failed before writing any package file; nothing to restore" >&2
		else
			echo "[bump] $p failed after writing a package file; check 'jj diff' and restore only that file before retrying" >&2
		fi
	fi
done

if ((${#fail[@]})); then
	echo "[bump] failed: ${fail[*]}" >&2
	exit 1
fi
echo "[bump] all ${#pkgs[@]} package(s) updated"
