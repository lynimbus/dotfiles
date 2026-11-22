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
#   --bump-feed=<url>     a release feed that states the version, every asset's
#                         SHA-256, and (from 0.1.3862 on) an ed25519 signature
#                         over the release's checksum list. The version and the
#                         asset hash both come out of it, so the asset is never
#                         downloaded to derive them; see feed_release.
#   --bump-asset=<name>   which asset of that feed this package ships.
#   --bump-app-manifest=<url>
#                         Google's app update manifest, the electron-updater
#                         shape Antigravity publishes: the version at the top,
#                         and in every asset URL that same version with the
#                         build id appended as the path segment ahead of the
#                         platform. The download only resolves with both, so
#                         the script reads both out of the one answer and
#                         writes the build id itself; see app_manifest_release.
#
# A package that declares --bump-feed= must also declare --no-src: the hash is
# written by write_src_hash from the feed, and --no-src is what stops nix-update
# from downloading the asset to re-derive it. --bump-manifest= is the opposite:
# it only names a version, so the src rewrite and --build have to stay.
# --bump-app-manifest= sits between the two: it names the version the way
# --bump-manifest= does, but the build id it also names has to be in the file
# before nix-update fetches that version, so it is written first.
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
#   - A prebuilt binary can be served stale inside the release window: about 10
#     minutes into magpie v0.1.3370 the CDN still put the previous bytes behind
#     the new tag's URL, so nix-update prefetched the old hash, wrote the new
#     version and exited 0. Only the build caught it, at 'just switch' time.
#     Packages whose hashes are release assets therefore carry --build, which
#     builds the package (versionCheckHook included) as part of the bump;
#     source-built packages have vendorHash covered by nix-update itself.
#   - nix-update shells out to `git diff` when the version it found equals the
#     pin (update.py: update_version -> git.old_version_from_git). This checkout
#     has .jj but no .git, so that call exited 129 and killed the run for every
#     already-current package. Letting it succeed is worse: with an empty diff
#     nix-update falls through to replace_version and re-fetches every src and
#     dependency hash for a package that did not change. See the git shim below.
# shellcheck source=docs/lib.sh
source "$(dirname "$0")/lib.sh"
cd "$repo_dir" || exit 1

github_token

# nix-update relies on two assumptions that break in this repo:
#
#   1. In a jj-only checkout (no .git), nix-update asks git for the old version
#      string whenever the version it found equals the pin (update.py:
#      update_version -> git.old_version_from_git). That `git diff` exits 129
#      and kills the run for every already-current package. Making the diff
#      succeed is not the answer: nix-update then falls through to
#      replace_version and re-fetches src and dependency hashes for an unchanged
#      package. Intercept that probe with a marker and exit 42 instead. A
#      colocated jj/git checkout keeps its real git repository for this.
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

nix_update_noop_marker='[bump] nix-update probed a jj-only checkout for its old version'
if [ ! -e "$repo_dir/.git" ]; then
	real_git="$(command -v git)" || die "git is not on PATH"
	{
		printf '#!/usr/bin/env bash\nmarker=%q\nreal_git=%q\n' "$nix_update_noop_marker" "$real_git"
		cat <<'EOF'
for arg in "$@"; do
	if [ "$arg" = "--word-diff=porcelain" ]; then
		printf '%s\n' "$marker" >&2
		exit 42
	fi
done
exec "$real_git" "$@"
EOF
	} >"$shim_dir/git" || die "cannot write the git shim"
	chmod +x "$shim_dir/git" || die "cannot make the git shim executable"
fi

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
	nix_update_env=(env "PYTHONNOUSERSITE=true" "PATH=$shim_dir${wrapper_path:+:$wrapper_path}:$PATH")
else
	nix_update_env=(env "PATH=$shim_dir:$PATH")
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
	local -a auth_header=()
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		auth_header=(-H "Authorization: Bearer $GITHUB_TOKEN")
	fi
	key="$(curl -fsSL --retry 2 --retry-delay 2 "${auth_header[@]}" \
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

# Runs nix-update with the git shim on PATH. Only the no-op decision reads a
# marker, and it is a marker the shim above wrote itself: nix-update's error
# wording is never consulted for control flow. The VersionError hint below is
# just a hint; if its wording changes, the exit code still decides the outcome.
nix_update() {
	local p="$1" out rc
	shift
	out="$("${nix_update_env[@]}" "${nix_update_cmd[@]}" --flake "legacyPackages.$system.$p" "$@" 2>&1)"
	rc=$?
	((rc == 0)) && {
		printf '%s\n' "$out"
		return 0
	}
	# The shim answers before nix-update rewrites anything, so no package file
	# changed and no traceback needs to reach the terminal.
	if grep -qF -- "$nix_update_noop_marker" <<<"$out"; then
		echo "[bump] $p: already current" >&2
		return 0
	fi
	printf '%s\n' "$out"
	if grep -q 'VersionError: Please specify the version' <<<"$out"; then
		echo "[bump] $p: nix-update cannot enumerate this package's releases; declare a version index in passthru.bump (--bump-maven=, --bump-manifest= or --bump-feed=)" >&2
	fi
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
	local arg url="" manifest="" app_manifest="" version build_id="" feed="" asset="" hash="" out current
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
	elif [ -n "$manifest" ]; then
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

	# An index that answered is compared against the pin before nix-update runs,
	# and that comparison carries two rules at once.
	#
	# It is what stops a version moving backwards. The feed trails the releases —
	# it answered 0.1.3936 while 0.1.3937 was already out, because it is rebuilt
	# from a release rather than being what a release is cut from — so following it
	# downwards would undo a bump the releases had already made.
	#
	# It is also what keeps nix-update off its git branch: when the version it was
	# told equals the pin it asks git for the old version number by shelling out
	# to `git diff` (git.py, old_version_from_git). That branch is harmless now
	# thanks to the shim, but a package with an index still avoids the whole
	# comparison. A package with no index has nothing to compare and relies on
	# the shim alone.
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
	local p="$1" hex="$2" file old sri
	file="$(package_file "$p")" || return 1
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

# Rewrites the build id a package file pins. The file comes from the derivation
# and so does the old value (passthru.buildId), on the same terms as
# write_src_hash: the replacement cannot land on another number that happens to
# sit in the same file.
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
