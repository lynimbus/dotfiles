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
# means editing this script. One token there is not a nix-update flag but a
# version index this script has to read itself, before nix-update runs: see
# maven_latest_stable for the --bump-maven= form and why r8 needs it.
#
# Usage:
#   docs/bump-packages.sh              # every package that tracks a release
#   docs/bump-packages.sh pig kero     # just those
#
# A failed rewrite leaves a half-updated file, version written and hash not:
# 'jj restore pkgs/' puts it back before a retry.
#
# Two failure modes measured on 2026-11-09 decide the defences below:
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
#   - nix-update only knows how to enumerate releases from github, gitlab,
#     gitea, codeberg, sourcehut, savannah, pypi, npm, crates.io and rubygems.
#     A package published only to a Maven repository therefore has no version
#     to find and the run dies in VersionError before it touches the file, so
#     the package names its version index instead (--bump-maven=).
#   - A prebuilt binary can be served stale inside the release window: about 10
#     minutes into magpie v0.1.3370 the CDN still put the previous bytes behind
#     the new tag's URL, so nix-update prefetched the old hash, wrote the new
#     version and exited 0. Only the build caught it, at 'just switch' time.
#     Packages whose hashes are release assets therefore carry --build, which
#     builds the package (versionCheckHook included) as part of the bump;
#     source-built packages have vendorHash covered by nix-update itself.
# shellcheck source=docs/lib.sh
source "$(dirname "$0")/lib.sh"
cd "$repo_dir" || exit 1

github_token

system=x86_64-linux
NET_RETRY_RE='502|503|504|cannot download|failed to retrieve hash|timed out|Failed to connect|Connection reset|curl: \((6|7|22|28)\)'
retries=2
retry_delay=30

command -v nix-update >/dev/null || die "nix-update is not on PATH (it comes from home/packages.nix)"

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

# Turns what the package declared into the nix-update command line: the flags
# pass through untouched, a version index is read first. It runs inside
# run_nix_update's retry loop, so an index that 502s is retried on the same
# terms as a release asset that does, and its error text is in the log the
# retry match reads.
bump_package() {
	local p="$1"
	shift
	local arg url version
	local -a pass=()
	for arg in "$@"; do
		case "$arg" in
		--bump-maven=*)
			url="${arg#--bump-maven=}"
			if ! version="$(maven_latest_stable "$url")"; then
				echo "[bump] $p: cannot read the version index $url" >&2
				return 1
			fi
			echo "[bump] $p: $url publishes $version" >&2
			pass+=("--version=$version")
			;;
		*) pass+=("$arg") ;;
		esac
	done
	nix-update --flake "legacyPackages.$system.$p" "${pass[@]}"
}

fail=()
for p in "${pkgs[@]}"; do
	args=()
	while IFS= read -r arg; do
		args+=("$arg")
	done < <(jq -r --arg p "$p" '.[$p][]' <<<"$matrix")

	if run_nix_update "$p" bump_package "$p" "${args[@]}"; then
		echo "[bump] $p ok"
	else
		fail+=("$p")
		echo "[bump] $p failed; its file may hold the new version with the old hash (jj restore pkgs/ and retry)" >&2
	fi
done

if ((${#fail[@]})); then
	echo "[bump] failed: ${fail[*]}" >&2
	exit 1
fi
echo "[bump] all ${#pkgs[@]} package(s) updated"
