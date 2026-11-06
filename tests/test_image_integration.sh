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
