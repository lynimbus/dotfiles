# atomic-workstation — Bazzite + a niri session (bootc image)
#
# Built with the mechanism from https://github.com/ublue-os/image-template
# (Containerfile + build_files/build.sh + system_files/, built through the
# image-* recipes in the justfile and .github/workflows/build.yml).
#
# The session stack is a port of the NixOS configuration on the main branch
# of this repository (system/desktop-niri.nix, home/desktop/niri/…,
# home/desktop/noctalia/…): niri compositor + noctalia shell + kero terminal
# + strata file manager, with fcitx5 (rime) input, the same font set, and
# PipeWire/LADSPA plumbing. KDE stays as the fallback session from the base
# image. See docs/nixos-port-map.md for the full module-by-module mapping.

# Base image — configurable at build time:
#   just image-build                    (default from image-template.env)
#   BASE_IMAGE=ghcr.io/ublue-os/bazzite:stable just image-build
#
# Pick the variant that matches your hardware (details in docs/installation.md):
#   AMD / Intel (default): ghcr.io/ublue-os/bazzite:stable
#   NVIDIA proprietary:    ghcr.io/ublue-os/bazzite-nvidia:stable
#   NVIDIA open module:    ghcr.io/ublue-os/bazzite-nvidia-open:stable
#   Steam Deck / HTPC:     ghcr.io/ublue-os/bazzite-deck:stable
#   GNOME flavour:         ghcr.io/ublue-os/bazzite-gnome:stable
#
# The ARG must stay BEFORE the first FROM: an ARG declared inside a stage is
# invisible to later stages, leaving FROM ${BASE_IMAGE} empty ("no FROM
# statement found").
ARG BASE_IMAGE="ghcr.io/ublue-os/bazzite:stable"

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

FROM ${BASE_IMAGE}

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/base-main:latest
# FROM ghcr.io/ublue-os/fedora-bootc:44

# Overlay system_files/ into the image and install the niri session stack:
# Fedora-packaged compositors/shell first (niri, noctalia, foot fallback),
# then the release-tarball apps that only ship GitHub binaries (kero,
# strata), then fonts Fedora does not carry (Maple Mono NF CN, JetBrainsMono
# Nerd Font). Every package below exists in Fedora repositories or is pinned
# by sha256 in build_files/build.sh (verified against rawhide 2026-11).
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    /ctx/build.sh
