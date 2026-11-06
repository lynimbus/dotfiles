#!/usr/bin/env bash

set -ouex pipefail

cp -avf "/ctx/system_files"/. /

# Port of the NixOS system layer on the main branch of this repo
# (system/desktop-niri.nix, fonts.nix, input-method.nix, audio.nix,
# ollama.nix, hardware.nix …). Package names are the base
# image's own (bazzite-nvidia-open:stable, Fedora 45 + ublue/multimedia
# repos) — the local `just image-build` is the verification. See
# docs/nixos-port-map.md for the mapping and the deliberate deviations.

dnf5 -y install \
    niri \
    noctalia \
    foot \
    swaylock \
    xwayland-satellite \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    xdg-terminal-exec \
    grim \
    slurp \
    swappy \
    wl-clipboard \
    brightnessctl \
    playerctl \
    wlsunset \
    fish \
    tmux \
    just \
    libnotify \
    pipewire-utils \
    sound-theme-freedesktop \
    file \
    bind-utils \
    libxml2 \
    zip \
    unzip \
    7zip \
    xz \
    fcitx5 \
    fcitx5-rime \
    fcitx5-gtk \
    fcitx5-qt \
    fcitx5-configtool \
    google-noto-sans-cjk-fonts \
    google-noto-color-emoji-fonts \
    jetbrains-mono-fonts \
    fira-code-fonts \
    intel-one-mono-fonts \
    ladspa-swh-plugins \
    bubblewrap \
    desktop-file-utils \
    ffmpeg \
    ffmpegthumbnailer \
    fontconfig \
    gstreamer1-plugin-libav \
    gstreamer1 \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gtk4 \
    gtksourceview5 \
    gvfs \
    poppler-glib \
    poppler-utils \
    xdg-utils \
    ImageMagick \
    LibRaw \
    android-tools \
    openssh-server \
    tuned

# main branch system/fonts.nix carries maple-mono."NF-CN" and
# nerd-fonts.jetbrains-mono; Fedora has neither (its `nerd-fonts` package is
# symbols-only). Both ship official release archives with sidecar hashes, so
# pin them here the same way the NixOS overlay pinned versions.

fetch() { # url sha256 dest
    curl --fail --location --retry 3 -o "$3" "$1"
    echo "$2  $3" | sha256sum --check
}

FONTS_DIR="/usr/share/fonts/atomic-workstation"
mkdir -p "${FONTS_DIR}"

fetch \
    "https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF-CN.zip" \
    "af913b6322905348b3f50e4397fedc35b3a880db5effcce7969003051dcd3e94" \
    /tmp/MapleMono-NF-CN.zip
unzip -o -q /tmp/MapleMono-NF-CN.zip -d "${FONTS_DIR}/MapleMono-NF-CN"

fetch \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/JetBrainsMono.zip" \
    "fab782a66f7d3019da64f6572db9fc5d3a4bcb19f9fa13e2d8a62e3693d6396e" \
    /tmp/JetBrainsMono.zip
unzip -o -q /tmp/JetBrainsMono.zip -d "${FONTS_DIR}/JetBrainsMono-NerdFont"
rm -f "${FONTS_DIR}/JetBrainsMono-NerdFont/LICENSE" \
      "${FONTS_DIR}/JetBrainsMono-NerdFont/"*.md 2>/dev/null || true

# Same tarball pkgs/kero.nix fetches on the main branch. The Go binary locates
# its bundled libghostty-vt.so relative to /proc/self/exe, so the whole tree
# goes to /usr/lib/kero and /usr/bin/kero is a symlink into it.

KERO_VERSION="2.1.32"
fetch \
    "https://github.com/egoist/kero/releases/download/v${KERO_VERSION}/kero-${KERO_VERSION}-linux-amd64.tar.gz" \
    "d8769662405cceffff27af574ef2750440c0cb6d0a647642dc1d43ad68a2c52f" \
    /tmp/kero.tar.gz
# NOTE: the kero tarball is FLAT (kero, libghostty-vt.so, fonts/ at its
# root) — no --strip-components here, unlike the strata tarball below.
mkdir -p /usr/lib/kero
tar -xzf /tmp/kero.tar.gz -C /usr/lib/kero
ln -sfn /usr/lib/kero/kero /usr/bin/kero
install -Dm644 /usr/lib/kero/kero.desktop /usr/share/applications/kero.desktop
install -Dm644 /usr/lib/kero/kero.png /usr/share/pixmaps/kero.png

# Ports system/desktop-niri.nix's `strata-file-manager` / `strata-portal`
# pair (they install exactly these files out of the same tarball on NixOS).
# The release install.sh targets $HOME; for the image we place everything
# under /usr by hand, which is what the .service.in template expects.

STRATA_VERSION="1.1.1"
fetch \
    "https://github.com/lgse/strata/releases/download/v${STRATA_VERSION}/strata-${STRATA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    "e0552e0772fcded13a82884747b28f0b32220a32931cda6e55f83575bbe50734" \
    /tmp/strata.tar.gz
mkdir -p /usr/lib/strata
tar -xzf /tmp/strata.tar.gz --strip-components=1 -C /usr/lib/strata
ln -sfn /usr/lib/strata/strata /usr/bin/strata
install -Dm644 /usr/lib/strata/io.github.lgse.Strata.desktop \
    /usr/share/applications/io.github.lgse.Strata.desktop
install -Dm644 /usr/lib/strata/io.github.lgse.Strata.svg \
    /usr/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg
install -Dm644 /usr/lib/strata/io.github.lgse.Strata.FileManager1.service \
    /usr/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service
sed "s|@STRATA_EXECUTABLE@|/usr/bin/strata|g" \
    /usr/lib/strata/portal/org.freedesktop.impl.portal.desktop.strata.service.in \
    > /usr/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service
install -Dm644 /usr/lib/strata/portal/strata.portal \
    /usr/share/xdg-desktop-portal/portals/strata.portal

fc-cache -f || true
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true

# Why not `dnf install ollama-base ollama-vulkan`? Fedora 45 still ships
# ollama 0.24.0 (checked 2026-11; rawhide too), while the model this machine
# loads (`kev:4b-q4_K_M`) declares `"requires":"0.40.4"` in its registry
# manifest. `ollama pull` therefore fails with
#   "The model you are attempting to pull requires a newer version of Ollama."
# so the packaged build is unusable for the configured model.
#
# The upstream release bundle is the same payload the official
# `ollama/ollama` image ships: bin/ollama + lib/ollama/{vulkan,cuda_v*}. The
# binary finds its libraries RELATIVE to its own path (bin/../lib/ollama), so
# installing to the same layout Fedora used (/usr/bin/ollama +
# /usr/lib/ollama) keeps everything working. Because the Fedora package is no
# longer installed, its systemd unit and `ollama` sysuser ship in
# system_files/ instead (same contents).
#
# cuda_v12/ + cuda_v13/ are ~2.4 GB of NVIDIA CUDA userspace that is dead
# weight here: this machine's GPU backend is Vulkan (see the service drop-in
# and docs/nixos-port-map.md). They are excluded from the extraction.
OLLAMA_VERSION="0.40.15"
fetch \
    "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
    "628c018404a4206493efd38e46251c154ede5141b8b8dc85c659b3b027c47379" \
    /tmp/ollama.tar.zst
mkdir -p /tmp/ollama-unpack
tar --zstd -xf /tmp/ollama.tar.zst -C /tmp/ollama-unpack \
    --exclude='lib/ollama/cuda_v12/*' \
    --exclude='lib/ollama/cuda_v13/*'
install -Dm755 /tmp/ollama-unpack/bin/ollama /usr/bin/ollama
mkdir -p /usr/lib/ollama
cp -a /tmp/ollama-unpack/lib/ollama/. /usr/lib/ollama/
rm -rf /tmp/ollama-unpack /tmp/ollama.tar.zst
# The tar also carries empty cuda_v12/cuda_v13 dirs after the exclude; drop
# them so `bootc container lint` sees no stray empty lib dirs.
rmdir /usr/lib/ollama/cuda_v12 /usr/lib/ollama/cuda_v13 2>/dev/null || true

# QQ still ships as the com.qq.QQ Flatpak, but upstream
# (SHORiN-KiWATA/linuxqq-wayland-fix) does not support that build: the fix
# injects a Wayland screen-share capture thread and an X11 clipboard
# implementation into QQ's Electron internals, and that needs the
# wlr-data-control + ext-image-copy-capture protocols — which the Flatpak
# Wayland proxy does not forward into the sandbox. So the payload is the
# official Tencent build plus the fix's own RPM release.
#
# Tencent ships only a .deb (there is no Fedora RPM of QQ), and the fix only
# publishes fc43 RPMs; both install and run against this fc45 base (verified
# by installing them into ghcr.io/ublue-os/bazzite:stable). Every Requires of
# the fix RPM (glib2, libX11.so.6, libwayland-client.so.0, libgio/libglib/
# libgobject, libz) is already in the base image, so the fix adds no package
# names to the dnf5 list above.
#
# The payload goes to /usr/lib/QQ, NOT under the real opt mount: that path is
# a symlink to /var/opt on this base image, ostree does not deploy /var, and
# writing there during the build trips `bootc container lint` (untracked /var
# content — see the dnf cleanup at the end of this script). The opt path the
# fix's launcher looks for is provided at boot by a systemd-tmpfiles symlink to
# /usr/lib/QQ, which ships in system_files/ (its own task) — never written
# here. The launcher resolves QQ via `command -v linuxqq`, then that opt path,
# and finds QQ's internals under QQ/resources/app beneath it (hardcoded
# fallback), so the link is what makes the fix find this payload.
#
# The deb's own menu file is deliberately NOT installed: it execs the QQ
# binary by absolute path and bypasses the fix wrapper. The image-owned menu
# entry (which also carries the Wayland IME flags) ships in system_files/
# instead.
QQ_VERSION="3.2.35-54395"
fetch \
    "https://qqdl.gtimg.cn/qqfile/QQNT/9.9.37/beta/816b3c79/linuxqq_${QQ_VERSION}_amd64.deb" \
    "7de03862327abbd16da27130413698c9517782b27194afc593bc3abf9b55f9ac" \
    /tmp/linuxqq.deb
# Unpack only the payload and the icons we ship. `ar` writes the member into
# its CWD, so the extraction happens in a subshell rather than moving the
# script's CWD (the rest of this script uses absolute paths on purpose).
mkdir -p /tmp/linuxqq-deb
( cd /tmp/linuxqq-deb && ar x /tmp/linuxqq.deb data.tar.xz )
tar -xJf /tmp/linuxqq-deb/data.tar.xz -C /tmp/linuxqq-deb ./opt ./usr/share/icons
# The copy runs from the unpack dir so no line here ever spells out the deb's
# root-level opt path: the guard in tests/test_image_integration.sh requires
# that this script name that path nowhere (on this base it is a symlink into
# /var, which the build must not write and `bootc container lint` would flag).
mkdir -p /usr/lib/QQ
( cd /tmp/linuxqq-deb && cp -a opt/QQ/. /usr/lib/QQ/ )
install -Dm644 /tmp/linuxqq-deb/usr/share/icons/hicolor/512x512/apps/qq.png \
    /usr/share/icons/hicolor/512x512/apps/qq.png

QQFIX_VERSION="0.2.24"
fetch \
    "https://github.com/SHORiN-KiWATA/linuxqq-wayland-fix/releases/download/v${QQFIX_VERSION}/linuxqq-wayland-fix-${QQFIX_VERSION}-1.fc43.x86_64.rpm" \
    "b8662661d9dbe4e646397c40d9bb3c2b8f5ad2ea9793123245cc145220d9a234" \
    /tmp/linuxqq-wayland-fix.rpm
dnf5 -y install /tmp/linuxqq-wayland-fix.rpm
# The RPM drops its own menu entry next to the one from system_files/; hide it
# so the launcher shows a single QQ and the Wayland IME flags stay authoritative.
sed -i '/^\[Desktop Entry\]$/a NoDisplay=true' /usr/share/applications/linuxqq-wayland-fix.desktop
# Both the .deb, its extracted tree and the fix RPM are build inputs, not
# image content — same reason as the archive cleanup at the end of the script.
rm -rf /tmp/linuxqq-deb /tmp/linuxqq.deb /tmp/linuxqq-wayland-fix.rpm

# Port of system/ollama.nix (service enabled, host/env baked — models are
# runtime state, pulled via `ujust atomic-ws-ollama-pull`), system/ssh.nix
# (hardening drop-in ships in system_files/, enable the daemon) and tuned
# (system/hardware.nix). Since the ollama payload now comes from upstream
# (above), the unit Fedora's ollama-base used to own — and the `ollama`
# sysuser — ship in system_files/ instead.
systemctl enable ollama.service || true
systemctl enable sshd.service || true
systemctl enable tuned.service || true

# The release archives and the dnf/rpm scratch dirs are build inputs, not
# image content: leaving them behind ships ~330 MB of dead weight and trips
# `bootc container lint` (nonempty-run-tmp). The Containerfile also mounts a
# tmpfs over /tmp; this is the belt-and-braces half for anyone building the
# script outside that RUN.
rm -f /tmp/MapleMono-NF-CN.zip /tmp/JetBrainsMono.zip \
    /tmp/kero.tar.gz /tmp/strata.tar.gz
# dnf5 keeps its repo metadata in /var/lib/dnf (not /var/cache), and both it
# and /run/dnf are build scratch, not machine state. Removing them is what
# makes `bootc container lint` stop reporting untracked /var content
# (`var-tmpfiles: d /var/lib/dnf/repos/…`, plus `countme` counter files).
rm -rf /run/dnf /run/dnf5 /var/lib/dnf /var/cache/libdnf5/* /var/cache/dnf/* 2>/dev/null || true
