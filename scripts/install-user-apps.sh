#!/usr/bin/env bash
# install-user-apps.sh — GitHub-release apps for atomic-workstation.
#
# The main branch of this repo built these with Nix overlay packages
# (pkgs/*.nix); on the atomic side they are user-space installs with the
# same pinned upstream assets. Everything lands in $HOME, so no image
# rebuild is needed and apps can update themselves when they support it
# (magpie does).
#
#   scripts/install-user-apps.sh              install/refresh all (skips present)
#   scripts/install-user-apps.sh magpie r8    install just these
#   scripts/install-user-apps.sh --force      reinstall even if present
#   scripts/install-user-apps.sh --check      compare pinned vs upstream latest
#   scripts/install-user-apps.sh --list       show the manifest
#
# Bumping a pin = editing APPS_* in this file (mirrors `just bump` on main).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

BIN_DIR="${HOME}/.local/bin"
SHARE_DIR="${HOME}/.local/share"

# ── manifest ───────────────────────────────────────────────────────────────
# Format: name|kind|url|sha256
#   kind: binary      — single executable → ~/.local/bin/<name>
#         appimage    — AppImage extracted → ~/.local/share/<name> + AppRun wrapper
#         tarball     — .tar.gz holding <name> at its top level
#         jar         — single jar → ~/.local/share/java + java wrapper
#         goinstall   — Go module installed via `go install` (needs brew go)
#         gitdata     — git-clone data dir (no sha pin; update = git pull)
# The gitdata target dir is "name:repopath" → ~/.local/share/<repopath>.
ALL_APPS=(
    "magpie|binary|https://github.com/yetone/magpie/releases/download/v0.1.2909/magpie-linux-amd64|b50b705da4470d76a35ea01dc50fc7e66fbed92ffd7fc29b2d7d901e7b1963c7"
    "ghostty|appimage|https://github.com/pkgforge-dev/ghostty-appimage/releases/download/v1.4.0/Ghostty-1.4.0-x86_64.AppImage|50ad4f8b54a01e7d41426e7d12ffae9c88aa1c516ac140755e2bca596e1d2ae6"
    "pig|tarball|https://github.com/MichaelKinsy/PiG/releases/download/v0.5.3/pig-0.5.3-linux-amd64.tar.gz|1e45e5e591a06d087587d5f09d2b6d61673a1e262cb2609e6189defffd5ae7ec"
    "opengrep|binary|https://github.com/opengrep/opengrep/releases/download/v1.33.1/opengrep_manylinux_x86|46e8133cc490f9f50518061590ce2f6be5a08afaeda034471c0ceda4b3899808"
    "r8|jar|https://dl.google.com/android/maven2/com/android/tools/r8/9.5.28/r8-9.5.28.jar|38a9ffaaebbd17d1514e3ecbff5a85b989bb13c551b9e224c7409514eea84ff5"
    "mygo|goinstall|github.com/egoist/mygo/cmd/mygo@v0.7.3|"
    "rime-ice|gitdata|https://github.com/iDvel/rime-ice|fcitx5/rime"
)

# ── helpers ────────────────────────────────────────────────────────────────

app_field() { # app_field <entry> <n>
    local IFS='|'
    # shellcheck disable=SC2206
    local parts=($1)
    # `set -u` + trailing empty fields (mygo has no sha) → index guard
    echo "${parts[$2]:-}"
}

installed_version() { # installed_version <name> — best-effort probe
    local bin="${BIN_DIR}/$1"
    case "$1" in
    magpie) [[ -x "$bin" ]] && "$bin" --version 2>/dev/null | head -1 || true ;;
    ghostty) [[ -x "$bin" ]] && "$bin" --version 2>/dev/null | head -1 || true ;;
    pig) [[ -x "$bin" ]] && "$bin" --version 2>/dev/null | head -1 || true ;;
    opengrep) [[ -x "$bin" ]] && "$bin" --version 2>/dev/null | head -1 || true ;;
    r8) ls "${SHARE_DIR}/java"/r8-*.jar >/dev/null 2>&1 && basename "$(ls "${SHARE_DIR}/java"/r8-*.jar | tail -1)" || true ;;
    mygo) [[ -x "${BIN_DIR:-}/mygo" ]] || command -v mygo >/dev/null 2>&1 && mygo --version 2>/dev/null | head -1 || true ;;
    esac
}

fetch() { # fetch <url> <sha256> <dest>
    curl --fail --location --retry 3 -o "$3" "$1"
    if [[ -n "$2" ]]; then
        echo "$2  $3" | sha256sum --check
    fi
}

install_binary() { # url sha name
    fetch "$1" "$2" "/tmp/atomic-ws-$3"
    chmod 0755 "/tmp/atomic-ws-$3"
    mv "/tmp/atomic-ws-$3" "${BIN_DIR}/$3"
}

install_appimage() { # url sha name
    local dest="${SHARE_DIR}/$3"
    fetch "$1" "$2" "/tmp/atomic-ws-$3.AppImage"
    chmod 0755 "/tmp/atomic-ws-$3.AppImage"
    rm -rf "${dest}"
    mkdir -p "${dest}"
    (cd "${dest}" && /tmp/atomic-ws-$3.AppImage --appimage-extract >/dev/null)
    # Layout stays exactly as extracted — either a plain squashfs-root/
    # directory or the sharun form (AppDir/ payload + squashfs-root → AppDir
    # symlink). "squashfs-root/AppRun" resolves in both.
    [[ -e "${dest}/squashfs-root/AppRun" ]] || aw_die "$3: AppRun not found after extraction"
    cat > "${BIN_DIR}/$3" <<EOF
#!/bin/sh
# wrapper for the extracted $3 AppImage (atomic-workstation)
exec "${dest}/squashfs-root/AppRun" "\$@"
EOF
    chmod 0755 "${BIN_DIR}/$3"
    # Register the shipped desktop entry + icon for the app grid
    local desk="${dest}/squashfs-root/com.mitchellh.ghostty.desktop"
    if [[ -f "${desk}" ]]; then
        mkdir -p "${HOME}/.local/share/applications"
        cp "${desk}" "${HOME}/.local/share/applications/"
        if [[ -f "${dest}/squashfs-root/com.mitchellh.ghostty.png" ]]; then
            mkdir -p "${HOME}/.local/share/icons/hicolor/512x512/apps"
            cp "${dest}/squashfs-root/com.mitchellh.ghostty.png" "${HOME}/.local/share/icons/hicolor/512x512/apps/"
        fi
    fi
    rm -f "/tmp/atomic-ws-$3.AppImage"
}

install_tarball() { # url sha name
    fetch "$1" "$2" "/tmp/atomic-ws-$3.tar.gz"
    local tmp
    tmp="$(mktemp -d)"
    tar -xzf "/tmp/atomic-ws-$3.tar.gz" -C "$tmp"
    local inner
    inner="$(find "$tmp" -maxdepth 2 -type f -name "$3" | head -1)"
    [[ -n "$inner" ]] || aw_die "$3: no binary named '$3' inside the tarball"
    chmod 0755 "$inner"
    mv "$inner" "${BIN_DIR}/$3"
    rm -rf "$tmp" "/tmp/atomic-ws-$3.tar.gz"
}

install_jar() { # url sha name version
    mkdir -p "${SHARE_DIR}/java"
    fetch "$1" "$2" "${SHARE_DIR}/java/r8-$4.jar"
    cat > "${BIN_DIR}/r8" <<EOF
#!/bin/sh
# wrapper for the r8 dexer jar (Google Maven), port of pkgs/r8.nix (main branch)
exec java -jar "${SHARE_DIR}/java/r8-$4.jar" "\$@"
EOF
    chmod 0755 "${BIN_DIR}/r8"
}

install_go() { # module@version
    if ! aw_have go; then
        aw_warn "go is not on PATH — install it first (brew bundle --file apps/profiles/base.Brewfile)"
        return 1
    fi
    GOBIN="${BIN_DIR}" go install "$1"
}

install_gitdata() { # url target-relative-path
    local dest="${SHARE_DIR}/$2"
    if [[ -d "${dest}/.git" ]]; then
        git -C "${dest}" pull --ff-only || aw_warn "$2: pull failed — resolve locally"
    else
        mkdir -p "${dest}"
        git clone --depth 1 "$1" "${dest}"
    fi
}

# ── CLI ────────────────────────────────────────────────────────────────────

MODE="install"
FORCE=0
WANTED=()
for arg in "$@"; do
    case "$arg" in
    --force) FORCE=1 ;;
    --check) MODE="check" ;;
    --list) MODE="list" ;;
    -*) aw_die "unknown option: $arg" ;;
    *) WANTED+=("$arg") ;;
    esac
done

want_app() { # want_app <name>
    [[ ${#WANTED[@]} -eq 0 ]] && return 0
    local w
    for w in "${WANTED[@]}"; do
        [[ "$w" == "$1" ]] && return 0
    done
    return 1
}

latest_tag() { # latest_tag <repo> — via redirect, no API (rate-limit free)
    curl -s -o /dev/null -w '%{redirect_url}' "https://github.com/$1/releases/latest" |
        sed -n 's|.*/tag/||p'
}

pinned_version() { # pinned_version <url>
    local u="$1"
    sed -n \
        -e 's|.*/tag/\(.*\)$|\1|p' \
        -e 's|.*/download/\(v[^/]*\)/.*|\1|p' \
        -e 's|.*/r8/\([0-9.]*\)/.*|\1|p' \
        -e 's|.*@\(v\?[0-9][^ ]*\)$|\1|p' \
        <<<"$u" | head -1
}

mkdir -p "${BIN_DIR}"

case "$MODE" in
list)
    for entry in "${ALL_APPS[@]}"; do
        name="$(app_field "$entry" 0)"
        kind="$(app_field "$entry" 1)"
        url="$(app_field "$entry" 2)"
        printf '%-10s %-12s %-9s %s\n' "$name" "$(pinned_version "$url")" "$kind" "$url"
    done
    ;;
check)
    aw_step "comparing pinned versions with upstream latest"
    for entry in "${ALL_APPS[@]}"; do
        name="$(app_field "$entry" 0)"
        url="$(app_field "$entry" 2)"
        repo="$(sed -n 's|https://github.com/\([^/]*\)/\([^/]*\)/releases/.*|\1/\2|p' <<<"$url")"
        if [[ -n "$repo" ]]; then
            up="$(latest_tag "$repo")"
            pin="$(pinned_version "$url")"
            if [[ "$pin" == "$up" ]]; then
                aw_ok "$name: pinned ${pin:-?} = latest"
            else
                aw_info "$name: pinned ${pin:-?}, upstream ${up:-unknown}"
            fi
        else
            aw_info "$name: $url (no GitHub release tag to compare)"
        fi
    done
    ;;
install)
    for entry in "${ALL_APPS[@]}"; do
        name="$(app_field "$entry" 0)"
        kind="$(app_field "$entry" 1)"
        url="$(app_field "$entry" 2)"
        sha="$(app_field "$entry" 3)"

        want_app "$name" || continue

        case "$kind" in
        binary|appimage|tarball)
            if [[ -e "${BIN_DIR}/${name}" && $FORCE -eq 0 ]]; then
                aw_ok "$name already installed ($(installed_version "$name" || echo present)) — use --force to reinstall"
                continue
            fi
            ;;
        gitdata)
            ;; # presence is checked inside (git pull updates in place)
        goinstall)
            if command -v "${name}" >/dev/null 2>&1 && [[ $FORCE -eq 0 ]]; then
                aw_ok "$name already installed ($(installed_version "$name" || echo present)) — use --force to reinstall"
                continue
            fi
            ;;
        jar)
            ;; # idempotent by version in the filename
        esac

        aw_step "installing ${name} (${kind})"
        case "$kind" in
        binary) install_binary "$url" "$sha" "$name" ;;
        appimage) install_appimage "$url" "$sha" "$name" ;;
        tarball) install_tarball "$url" "$sha" "$name" ;;
        jar) install_jar "$url" "$sha" "$name" "$(sed -n 's|.*/r8-\([0-9.]*\)\.jar|\1|p' <<<"$url")" ;;
        goinstall) install_go "$url" ;;
        gitdata) install_gitdata "$url" "$(app_field "$entry" 3)" ;;
        esac
        case "$kind" in
        gitdata) aw_ok "$name → ${SHARE_DIR}/$(app_field "$entry" 3)" ;;
        *) aw_ok "$name → ${BIN_DIR}/${name}" ;;
        esac
    done
    ;;
esac
