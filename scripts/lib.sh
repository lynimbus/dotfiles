#!/usr/bin/env bash
# Setup shared by the scripts under scripts/. Sourced, not executed.

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034 # both are read by the scripts that source this
repo_dir="$(dirname "$scripts_dir")"

# Without this nix, nix-init, and nix-update reach the GitHub API anonymously,
# at 60 requests per hour per IP. Handing nix the gh token via NIX_CONFIG and
# tools like nix-update via GITHUB_TOKEN raises that to the account's own limit.
github_token() {
	local token
	command -v gh >/dev/null || return 0
	token="$(gh auth token 2>/dev/null)" || return 0
	[ -n "$token" ] || return 0
	NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG
}access-tokens = github.com=$token"
	export NIX_CONFIG
	export GITHUB_TOKEN="${GITHUB_TOKEN:-$token}"
}

die() {
	printf '%s: %s\n' "${0##*/}" "$*" >&2
	exit 1
}
