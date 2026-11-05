#!/usr/bin/env bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages
#
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
    ollama-base \
    ollama-vulkan \
    openssh-server \
    tuned

### Fonts Fedora does not package
#
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

### kero — terminal (Mod+Return), GitHub release only
#
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

### strata — file manager + FileChooser portal, GitHub release only
#
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

### Refresh font + icon caches so the new entries resolve on first boot
fc-cache -f || true
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true

### Services
#
# Port of system/ollama.nix (service enabled, host/env baked — models are
# runtime state, pulled via `ujust atomic-ws-ollama-pull`), system/ssh.nix
# (hardening drop-in ships in system_files/, enable the daemon) and tuned
# (system/hardware.nix).
systemctl enable ollama.service || true
systemctl enable sshd.service || true
systemctl enable tuned.service || true

### Clean up build scratch space
#
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

#### Example for enabling a System Unit File
# systemctl enable <unit>
