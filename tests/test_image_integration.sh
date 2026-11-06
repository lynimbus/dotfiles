#!/usr/bin/env bash
# test_image_integration.sh — static checks on the image definition.
#
# These guard failure modes that are invisible until a machine is running the
# built image, so they are cheap assertions on the tracked files instead:
#   * the ollama payload must NOT come from Fedora (0.24.0 < the model's
#     required 0.40.4 → `ollama pull` fails with 412), and the unit/sysuser it
#     used to provide must ship with the image;
#   * ~/.bashrc must export ~/.local/bin (niri-session's import-environment
#     overwrites the manager PATH with the login shell's PATH, so a missing
#     entry hides ghostty/chromium/screenshot from the whole session);
#   * the PATH/terminal emulator must not be silently dropped from the
#     chezmoi tree.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/tests/lib.sh"

BUILD="${REPO_ROOT}/build_files/build.sh"
BASHRC="${REPO_ROOT}/home/chezmoi/dot_bashrc"

t_title "image integration"

t_case "ollama payload is not the Fedora package"
assert_not_contains "no ollama-base in dnf list" "    ollama-base \\\\" "$BUILD"
assert_not_contains "no ollama-vulkan in dnf list" "    ollama-vulkan \\\\" "$BUILD"
assert_contains "upstream release is fetched" "github.com/ollama/ollama/releases/download" "$BUILD"

t_case "ollama release is sha256-pinned"
# A fetch with an empty hash would still "work" but ships whatever upstream
# serves that day; require a 64-hex literal right after the URL.
if grep -A1 'ollama-linux-amd64.tar.zst' "$BUILD" | grep -qE '"[0-9a-f]{64}"'; then
    t_ok
else
    t_fail "ollama tarball is not sha256-pinned"
fi

t_case "ollama CUDA payload is excluded (Vulkan-only machine)"
assert_contains "cuda_v12 excluded" "cuda_v12/*" "$BUILD"
assert_contains "cuda_v13 excluded" "cuda_v13/*" "$BUILD"

t_case "the Fedora unit + sysuser ollama used to provide now ship"
assert_file_exists "ollama.service" "${REPO_ROOT}/system_files/usr/lib/systemd/system/ollama.service"
assert_file_exists "ollama sysusers" "${REPO_ROOT}/system_files/usr/lib/sysusers.d/ollama.conf"
assert_contains "unit runs /usr/bin/ollama serve" "/usr/bin/ollama serve" \
    "${REPO_ROOT}/system_files/usr/lib/systemd/system/ollama.service"
assert_contains "sysuser creates ollama" "u ollama" \
    "${REPO_ROOT}/system_files/usr/lib/sysusers.d/ollama.conf"

t_case "bash login shell puts ~/.local/bin on PATH"
# The bug: niri-session runs `systemctl --user import-environment`, replacing
# the manager's environment.d PATH with the login shell's PATH. ~/.bash_profile
# (from /etc/skel) sources ~/.bashrc but never ~/.profile, so the ~/.local/bin
# entry in ~/.profile never reached a bash session.
assert_contains "dot_bashrc exports ~/.local/bin" '${HOME}/.local/bin' "$BASHRC"

t_case "default avatar is a symlink to a packaged icon"
# AccountsService reports IconFile=${HOME}/.face; without the file noctalia
# logs "failed to decode image" on every session. chezmoi ships it as a
# symlink to an adwaita-icon-theme asset (present in the base image).
assert_file_exists "symlink_dot_face" "${REPO_ROOT}/home/chezmoi/symlink_dot_face"
assert_contains "points at the packaged avatar" "/usr/share/icons/Adwaita/" \
    "${REPO_ROOT}/home/chezmoi/symlink_dot_face"

t_case "terminal font is not a generic CJK font (fontconfig)"
# Maple Mono NF CN advances CJK glyphs 1.2em (two 0.6em Latin cells) — right
# for a monospace terminal grid, 20% too wide for running text. It declares
# ja / zh-cn / zh-sg, and its charset is larger than Noto CJK's, so fontconfig
# picked it for *every* generic CJK lookup inside flatpak (the sandbox gets
# the runtime's /etc/fonts, which has no Noto-CJK preference). Firefox then
# rendered Chinese 20% too wide — "big gaps between the characters".
# The rule below is a scan-time edit, so it lands in the font cache that
# build.sh's `fc-cache -f` writes; flatpak bind-mounts that cache read-only
# as /run/host/fonts-cache, which is how it reaches the sandbox too.
CJKCONF="${REPO_ROOT}/system_files/usr/share/fontconfig/conf.avail/69-atomic-workstation-terminal-fonts.conf"
CJK_LINK="${REPO_ROOT}/system_files/etc/fonts/conf.d/69-atomic-workstation-terminal-fonts.conf"
assert_file_exists "fontconfig rule" "$CJKCONF"
assert_file_exists "rule is enabled via conf.d" "$CJK_LINK"
assert_contains "targets the terminal font" "Maple Mono NF CN" "$CJKCONF"
assert_contains "strips zh-cn" "<string>zh-cn</string>" "$CJKCONF"
assert_contains "strips ja" "<string>ja</string>" "$CJKCONF"
# A scan-time (not pattern-time) edit is the whole point: only scan-time
# edits are baked into the cache, and only the cache reaches flatpak.
assert_contains "edits at scan time, not match time" 'target="scan"' "$CJKCONF"

t_case "font cache is rebuilt after system_files is overlaid"
# system_files/ (which now carries /etc/fonts/conf.d) must be copied before
# fc-cache runs, otherwise the rule misses the cache baked into the image.
copy_line=$(grep -n 'cp -avf "/ctx/system_files"/\. /' "$BUILD" | head -1 | cut -d: -f1)
cache_line=$(grep -n 'fc-cache -f' "$BUILD" | head -1 | cut -d: -f1)
assert_eq "system_files copied before fc-cache" "yes" \
    "$([[ -n "$copy_line" && -n "$cache_line" && "$copy_line" -lt "$cache_line" ]] && echo yes || echo no)"

t_case "emulator + PATH docs stay in step with the config"
assert_file_exists "fish config" "${REPO_ROOT}/home/chezmoi/dot_config/fish/config.fish"
assert_contains "fish adds ~/.local/bin" "fish_add_path" \
    "${REPO_ROOT}/home/chezmoi/dot_config/fish/config.fish"
assert_file_exists "environment.d PATH" \
    "${REPO_ROOT}/home/chezmoi/dot_config/environment.d/60-atomic-workstation.conf"
assert_contains "environment.d sets ~/.local/bin" '${HOME}/.local/bin' \
    "${REPO_ROOT}/home/chezmoi/dot_config/environment.d/60-atomic-workstation.conf"

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "image integration: ${TESTS_RUN} checks, 0 failed" >&2
    exit 0
else
    echo "image integration: ${TESTS_RUN} checks, ${TESTS_FAILED} failed" >&2
    exit 1
fi
