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
RUN_SH="${REPO_ROOT}/tests/run.sh"

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

t_case "QQ payload comes from Tencent's pinned .deb, not the Flatpak"
# Upstream (linuxqq-wayland-fix) does not support the com.qq.QQ Flatpak: the
# fix needs wlr-data-control + ext-image-copy-capture, which the Flatpak
# Wayland proxy does not forward into the sandbox. Tencent ships no Fedora
# RPM, so the payload comes from the pinned amd64 .deb.
qq_url_template="https://qqdl.gtimg.cn/qqfile/QQNT/9.9.37/beta/816b3c79/linuxqq_\${QQ_VERSION}_amd64.deb"
qq_url_want="https://qqdl.gtimg.cn/qqfile/QQNT/9.9.37/beta/816b3c79/linuxqq_3.2.35-54395_amd64.deb"
assert_contains "QQ deb URL" "$qq_url_template" "$BUILD"
qq_version="$(sed -n 's/^QQ_VERSION="\(.*\)"$/\1/p' "$BUILD" | head -1)"
assert_eq "QQ_VERSION pin resolves the reviewed deb" "$qq_url_want" \
    "https://qqdl.gtimg.cn/qqfile/QQNT/9.9.37/beta/816b3c79/linuxqq_${qq_version}_amd64.deb"

# Same rule as the ollama tarball above: a fetch with an empty hash still
# "works" but ships whatever Tencent serves that day.
t_case "QQ deb is sha256-pinned"
if grep -A1 'qqdl.gtimg.cn' "$BUILD" | grep -qE '"[0-9a-f]{64}"'; then
    t_ok
else
    t_fail "QQ deb is not sha256-pinned"
fi
assert_contains "QQ deb digest is the reviewed one" \
    "7de03862327abbd16da27130413698c9517782b27194afc593bc3abf9b55f9ac" "$BUILD"

t_case "QQ payload lands in /usr/lib/QQ, icon installed"
# The copy runs from inside the unpack dir (`cd ... && cp -a opt/QQ/.`), so
# this script never names the deb's root-level opt path — see the next case.
if grep -qE 'cp -a [^ ]+ /usr/lib/QQ/' "$BUILD"; then
    t_ok
else
    t_fail "no cp -a of the deb payload into /usr/lib/QQ/"
fi
assert_contains "payload dir created" 'mkdir -p /usr/lib/QQ' "$BUILD"
assert_contains "icon install" \
    'install -Dm644 /tmp/linuxqq-deb/usr/share/icons/hicolor/512x512/apps/qq.png' "$BUILD"
assert_contains "icon destination" \
    '/usr/share/icons/hicolor/512x512/apps/qq.png' "$BUILD"
# The deb's own qq.desktop execs the QQ binary by absolute path and so
# bypasses the fix wrapper; T2 ships the image-owned menu entry instead.
assert_not_contains "deb qq.desktop is not installed" \
    'share/applications/qq.desktop' "$BUILD"

t_case "build.sh never writes under the /var-backed /opt"
# /opt is a symlink to /var/opt on this base image and ostree does not deploy
# /var, so the payload must live in /usr/lib/QQ and reach /opt only through
# T2's tmpfiles link. A literal /opt path here would silently regress that
# (and trip `bootc container lint` with untracked /var content).
if grep -qF '/opt/' "$BUILD"; then
    t_fail "build.sh writes under /opt (must be a tmpfiles link, owned by T2)"
else
    t_ok
fi

t_case "linuxqq-wayland-fix RPM is fetched pinned and installed with dnf5"
fix_url_template="https://github.com/SHORiN-KiWATA/linuxqq-wayland-fix/releases/download/v\${QQFIX_VERSION}/linuxqq-wayland-fix-\${QQFIX_VERSION}-1.fc43.x86_64.rpm"
assert_contains "fix RPM URL" "$fix_url_template" "$BUILD"
qqfix_version="$(sed -n 's/^QQFIX_VERSION="\(.*\)"$/\1/p' "$BUILD" | head -1)"
assert_eq "QQFIX_VERSION pin resolves the reviewed RPM" \
    "https://github.com/SHORiN-KiWATA/linuxqq-wayland-fix/releases/download/v0.2.24/linuxqq-wayland-fix-0.2.24-1.fc43.x86_64.rpm" \
    "https://github.com/SHORiN-KiWATA/linuxqq-wayland-fix/releases/download/v${qqfix_version}/linuxqq-wayland-fix-${qqfix_version}-1.fc43.x86_64.rpm"
if grep -A1 'linuxqq-wayland-fix/releases/download' "$BUILD" | grep -qE '"[0-9a-f]{64}"'; then
    t_ok
else
    t_fail "linuxqq-wayland-fix RPM is not sha256-pinned"
fi
assert_contains "fix RPM digest is the reviewed one" \
    "b8662661d9dbe4e646397c40d9bb3c2b8f5ad2ea9793123245cc145220d9a234" "$BUILD"
assert_contains "fix RPM installed with dnf5" \
    'dnf5 -y install /tmp/linuxqq-wayland-fix.rpm' "$BUILD"

t_case "the fix RPM's duplicate menu entry is hidden"
# T2 ships the single image-owned qq.desktop (which also carries the Wayland
# IME flags); the RPM's own entry would show up as a second QQ in the launcher.
assert_contains "NoDisplay sed" \
    "sed -i '/^\\[Desktop Entry\\]$/a NoDisplay=true' /usr/share/applications/linuxqq-wayland-fix.desktop" "$BUILD"

t_case "QQ build scratch is removed"
assert_contains "scratch cleanup" 'rm -rf /tmp/linuxqq-deb' "$BUILD"
assert_contains "deb cleanup" '/tmp/linuxqq.deb' "$BUILD"
assert_contains "rpm cleanup" '/tmp/linuxqq-wayland-fix.rpm' "$BUILD"

t_case "build.sh still parses after the QQ section"
if bash -n "$BUILD" 2>/dev/null; then t_ok; else t_fail "bash -n build_files/build.sh failed"; fi
assert_contains "pipefail preserved" 'set -ouex pipefail' "$BUILD"

t_case "tests/run.sh SUITES registers the QQ suites"
assert_file_exists "tests/run.sh" "$RUN_SH"
suites_line="$(grep -E '^[[:space:]]*SUITES=\(' "$RUN_SH" 2>/dev/null | head -1)"
if [[ -n "$suites_line" ]]; then t_ok; else t_fail "no SUITES=(...) array found in tests/run.sh"; fi
# Strip the assignment syntax so `grep -w` only sees the suite names (a
# substring match would let `qq_desktop` pass on `xqq_desktop`).
suite_names="$(sed -E 's/^[[:space:]]*SUITES=\(//; s/\)[[:space:]]*$//' <<<"$suites_line")"
for want_suite in qq_desktop qq_migration; do
    if grep -qwF -- "$want_suite" <<<"$suite_names"; then
        t_ok
    else
        t_fail "tests/run.sh SUITES is missing [${want_suite}]: ${suites_line}"
    fi
done
missing_suites=()
for want_suite in flatpak brew distrobox inventory git systemd ujust image_integration \
                  dotfiles screenshot screenshot_config screenshot_wiring; do
    grep -qwF -- "$want_suite" <<<"$suite_names" || missing_suites+=("$want_suite")
done
if [[ ${#missing_suites[@]} -eq 0 ]]; then
    t_ok
else
    t_fail "tests/run.sh SUITES dropped: ${missing_suites[*]}"
fi
if bash -n "$RUN_SH" 2>/dev/null; then t_ok; else t_fail "bash -n tests/run.sh failed"; fi

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
