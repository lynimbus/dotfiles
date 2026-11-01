# atomic-workstation — Bazzite + an additional Sway session (bootc image)
#
# Built with the mechanism from https://github.com/ublue-os/image-template
# (Containerfile + build_files/build.sh + system_files/, built through the
# image-* recipes in the justfile and .github/workflows/build.yml).
# User configuration is NOT baked in here — it is managed by chezmoi from
# home/chezmoi/. See docs/installation.md.

# Base image — configurable at build time:
#   just image-build                    (default from image-template.env)
#   BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia:stable just image-build
#
# Pick the variant that matches your hardware (details in docs/installation.md):
#   AMD / Intel (default): ghcr.io/ublue-os/bazzite:stable
#   NVIDIA proprietary:    ghcr.io/ublue-os/bazzite-nvidia:stable
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

# Overlay system_files/ into the image and install the Sway session stack.
# Every package below exists in Fedora repositories (verified against rawhide
# 2026-10). sway-config-upstream ships /usr/share/wayland-sessions/sway.desktop
# (the display-manager session entry, discovered by SDDM) and
# /usr/share/xdg-desktop-portal/sway-portals.conf.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Bootc lint check
RUN bootc container lint
