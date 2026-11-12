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
# Three tokens there are not nix-update flags but indices this script reads
# itself, before nix-update runs:
#
#   --bump-maven=<url>    a Maven repository to take the version from; see
#                         maven_latest_stable and why r8 needs it.
#   --bump-feed=<url>     a release feed that states the version, every asset's
#                         SHA-256, and (from 0.1.3862 on) an ed25519 signature
#                         over the release's checksum list. The version and the
#                         asset hash both come out of it, so the asset is never
#                         downloaded to derive them; see feed_release.
#   --bump-asset=<name>   which asset of that feed this package ships.
#
# A package that declares --bump-feed= must also declare --no-src: the hash is
# written by write_src_hash from the feed, and --no-src is what stops nix-update
# from downloading the asset to re-derive it.
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

# The release a feed announces: version on one line, the asset SHA-256 on the next.
#
# The feed (usemagpie.ai/api/latest, and any other that answers in its shape)
# states the version and every asset SHA-256 in one answer, which is what makes
# --no-src possible: nix-update is told the version and writes it, and never
# downloads the 82MB asset to re-derive a hash it was already given.
#
# The hash is then checked against the list upstream signed, not against the
# bytes: it is the release SHA256SUMS, delivered in the same answer, and from
# 0.1.3862 on it carries an ed25519 signature over "magpie release <version>",
# a newline, and that text. Verifying it here rather than inferring it from a
# successful build is what closes the stale-CDN window: a feed that served the
# previous release list under the new version name fails at the signature,
# before anything is written to the package file. A feed published before the
# signing era (or a different feed entirely) has no signature to check, and the
# hash then stands as the feed gave it.
# True when the first version is newer than the second, comparing the numeric
# parts of a dotted version rather than the text: 0.1.3937 sorts above 0.1.3936
# as numbers but so would 0.1.400 have to sort above 0.1.3936, which a string
# comparison gets wrong. A leading "v" and any suffix after the numbers are
# ignored, so a tag and a pinned version answer the same question.
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

feed_release() {
	local url="$1" asset="$2" json version hash signed_hash
	local dir
	dir="$(mktemp -d)" || return 1
	trap 'rm -rf "$dir"' RETURN
	
	json="$(curl -fsSL --retry 2 --retry-delay 2 "$url")" || return 1
	version="$(jq -r '.version // empty' <<<"$json")"
	hash="$(jq -r --arg a "$asset" '.assets[$a].sha256 // empty' <<<"$json")"
	[ -n "$version" ] && [ -n "$hash" ] || return 1
	
	# jq -j rather than a shell variable: the signature covers the exact bytes of
	# this text, trailing newline included, and $(...) would eat it. The list goes
	# to a file once and both the check and the lookup read that file.
	jq -j '.signed.sums // empty' <<<"$json" >"$dir/sums"
	jq -j '.signed.sig // empty' <<<"$json" >"$dir/sig"
	if [ -s "$dir/sums" ] && [ -s "$dir/sig" ]; then
		feed_verify "$version" "$dir/sums" "$dir/sig" || return 1
		signed_hash="$(awk -v a="$asset" '$2 == a { print $1 }' "$dir/sums")"
		if [ -n "$signed_hash" ] && [ "$signed_hash" != "$hash" ]; then
			echo "[bump] the $asset hash the feed gives is not the one it signed" >&2
			return 1
		fi
	fi
	
	printf '%s\n%s\n' "$version" "$hash"
}

# Checks a release signed SHA256SUMS against the key upstream builds into its
# binary, and fails when it cannot. The key lives in internal/update/signed.go
# as raw base64 bytes, which openssl reads once wrapped in an ed25519 SPKI
# header: the fixed 12-byte prefix below, then those 32 bytes.
#
# Not verifying is only right when the feed claims no signature. A signature
# that is there and does not check is a tampered or broken feed, and taking its
# hash would defeat the point of reading the signed list at all.
feed_verify() {
	local version="$1" sumsfile="$2" sigfile="$3" key dir ossl
	if ! ossl="$(nix build --no-link --print-out-paths ".#legacyPackages.$system.openssl.bin" 2>/dev/null)/bin/openssl"; then
		echo "[bump] cannot build openssl, so the release signature cannot be checked" >&2
		return 1
	fi
	# The key is read from the tagged source, so a release that rotates it is
	# checked with the key that release shipped rather than with a literal here
	# that would have to be edited in the same commit as every version. GitHub's
	# API answers when raw.githubusercontent.com does not: the raw host was the one
	# refusing TLS on the network this was written for, and curl's --retry does
	# not cover that failure.
	key="$(curl -fsSL --retry 2 --retry-delay 2 \
		"https://api.github.com/repos/yetone/magpie/contents/internal/update/signed.go?ref=v$version" |
		jq -r '.content // empty' | base64 -d 2>/dev/null |
		grep -o 'var signingKey = "[^"]*"' | head -1 | cut -d'"' -f2)" || key=""
	if [ -z "$key" ]; then
		key="$(curl -fsSL --retry 2 --retry-delay 2 \
			"https://raw.githubusercontent.com/yetone/magpie/v$version/internal/update/signed.go" |
			grep -o 'var signingKey = "[^"]*"' | head -1 | cut -d'"' -f2)" || key=""
	fi
	if [ -z "$key" ]; then
		echo "[bump] the feed signed $version but its key could not be read from the source" >&2
		return 1
	fi
	
	dir="$(mktemp -d)" || return 1
	trap 'rm -rf "$dir"' RETURN
	base64 -d <<<"$key" >"$dir/key.raw" || return 1
	# 30 2a 30 05 06 03 2b 65 70 03 21 00 is the SPKI header of an ed25519 key.
	{ printf '\060\052\060\005\006\003\053\145\160\003\041\000'; cat "$dir/key.raw"; } >"$dir/key.der"
	# The message upstream signs is this line, a newline, then the list verbatim.
	{ printf 'magpie release %s\n' "$version"; cat "$sumsfile"; } >"$dir/msg"
	# The feed carries the signature base64-encoded; openssl wants the 64 bytes.
	base64 -d <"$sigfile" >"$dir/sig" || return 1
	
	if ! "$ossl" pkeyutl -verify -pubin -inkey "$dir/key.der" -keyform DER -rawin \
		-in "$dir/msg" -sigfile "$dir/sig" >/dev/null 2>&1; then
		echo "[bump] the signature on $version does not check against its own key" >&2
		return 1
	fi
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
# Runs nix-update, and treats the one failure that is this repository's shape
# rather than a problem as a no-op.
#
# nix-update asks git for the old version number when the version it was told
# equals the pin, and it asks by shelling out to `git diff` (git.py,
# old_version_from_git). With no .git that exits 129, so every package that is
# already current ends the run: kero, whose upstream atom feed last moved well
# before the pin, could not be bumped at all. The answer it wants is 'changed
# nothing', which the message makes unambiguous: git prints 'Not a git
# repository' and only reaches that when it found no repository to diff in. A
# run that did rewrite the file fails earlier, on the hash or on the eval, so a
# package with a real change never lands here.
#
# The rest of nix-update needs no git on this path: git_has_diff is skipped
# when find_git_root returns None, and git_commit only runs under --commit.
nix_update() {
	local p="$1" out rc
	shift
	out="$(nix-update --flake "legacyPackages.$system.$p" "$@" 2>&1)"
	rc=$?
	printf '%s\n' "$out"
	((rc == 0)) && return 0
	# Only the no-op case: the failure is git's, and nix-update never got as far
	# as announcing a version change. A run that did announce one must fail loudly
	# here rather than be reported as already current.
	if grep -q 'Not a git repository' <<<"$out" && ! grep -q '^Update ' <<<"$out"; then
		echo "[bump] $p: nothing to update (nix-update could not read the old version from git)" >&2
		return 0
	fi
	return "$rc"
}

bump_package() {
	local p="$1"
	shift
	local arg url version feed="" asset="" hash="" out current
	local -a pass=()
	# Two flags name a version index instead of passing through to nix-update,
	# and both are read here, inside the retry loop: an index that 502s is then
	# retried on the same terms as a release asset that does, and its error text
	# is in the log the retry match reads.
	for arg in "$@"; do
		case "$arg" in
		--bump-maven=*) url="${arg#--bump-maven=}" ;;
		--bump-feed=*) feed="${arg#--bump-feed=}" ;;
		--bump-asset=*) asset="${arg#--bump-asset=}" ;;
		*) pass+=("$arg") ;;
		esac
	done

	if [ -n "$feed" ]; then
		if [ -z "$asset" ]; then
			echo "[bump] $p: --bump-feed= needs --bump-asset=" >&2
			return 1
		fi
		if ! out="$(feed_release "$feed" "$asset")"; then
			echo "[bump] $p: cannot read $asset out of $feed" >&2
			return 1
		fi
		version="$(sed -n 1p <<<"$out")"
		hash="$(sed -n 2p <<<"$out")"
		echo "[bump] $p: $feed publishes $version" >&2
	elif [ -n "$url" ]; then
		if ! version="$(maven_latest_stable "$url")"; then
			echo "[bump] $p: cannot read the version index $url" >&2
			return 1
		fi
		echo "[bump] $p: $url publishes $version" >&2
	fi

	# An index that answered is compared against the pin before nix-update runs,
	# and that comparison carries two rules at once.
	#
	# It is what stops a version moving backwards. The feed trails the releases —
	# it answered 0.1.3936 while 0.1.3937 was already out, because it is rebuilt
	# from a release rather than being what a release is cut from — so following it
	# downwards would undo a bump the releases had already made.
	#
	# It is also what keeps nix-update off the one branch of itself that needs a
	# checkout. When the version it was told equals the pin it asks git for the old
	# version number, by shelling out to `git diff` (git.py, old_version_from_git);
	# with no .git that exits 129 and ends the run. Answering "nothing to do" here
	# means that branch is never entered. A package with no index has nothing to
	# compare, and nix_update below handles the same failure for it.
	if [ -n "$version" ]; then
		current="$(nix eval --raw ".#legacyPackages.$system.$p.version")" || return 1
		if ! version_newer "$version" "$current"; then
			echo "[bump] $p: at $current, not older than $version" >&2
			return 0
		fi
		pass+=("--version=$version")
	fi

	if ! nix_update "$p" "${pass[@]}"; then
		return 1
	fi

	# The asset hash is written here rather than prefetched: the feed stated it and
	# it matched the list upstream signed. --no-src is what keeps nix-update from
	# downloading the asset to re-derive it.
	if [ -n "$hash" ]; then write_src_hash "$p" "$hash" || return; fi
}

# Replaces the src hash literal in a package file with the SRI form of a feed
# hex digest. nix-update cannot do this without prefetching the asset, which is
# exactly the download the feed makes unnecessary.
#
# The file comes from the derivation (meta.position names it) and so does the
# old value (src.outputHash), so the replacement cannot land on another hash
# that happens to sit in the same file.
write_src_hash() {
	local p="$1" hex="$2" file old sri store
	file="$(nix eval --raw ".#legacyPackages.$system.$p.meta.position")" || return 1
	file="${file%:*}"
	# meta.position names the file in the flake source as nix copied it into the
	# store, which is read-only. The same path under the checkout is the one
	# nix-update just rewrote.
	store="$(nix flake metadata --json | jq -r .path)" || return 1
	file="$repo_dir/${file#"$store"/}"
	[ -f "$file" ] || { echo "[bump] $p: $file is not in the checkout" >&2; return 1; }
	old="$(nix eval --raw ".#legacyPackages.$system.$p.src.outputHash")" || return 1
	sri="$(nix hash convert --hash-algo sha256 --to sri "$hex")" || return 1
	[ "$old" != "$sri" ] || return 0
	if ! grep -qF -- "$old" "$file"; then
		echo "[bump] $p: $file carries no src hash $old" >&2
		return 1
	fi
	OLD="$old" NEW="$sri" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$file"
	echo "[bump] $p: src -> $sri" >&2
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
