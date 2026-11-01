#!/usr/bin/env bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Sway session stack — every name below exists in Fedora repos
# (verified against rawhide 2026-10; see docs/installation.md).
#
#  sway + sway-config-upstream : compositor; config-upstream adds
#      /usr/share/wayland-sessions/sway.desktop (SDDM/GDM session entry),
#      /usr/share/xdg-desktop-portal/sway-portals.conf, /etc/sway/config,
#      and pulls Xwayland, swaybg, polkit + recommends swayidle/swaylock.
#  The stock KDE desktop from Bazzite stays untouched — Sway is an ADDITIONAL
#  session you can pick (or ignore) at the login screen.
dnf5 -y install \
    sway \
    sway-config-upstream \
    swayidle \
    swaylock \
    swaybg \
    waybar \
    foot \
    mako \
    wofi \
    kanshi \
    grim \
    slurp \
    wl-clipboard \
    brightnessctl \
    playerctl \
    xdg-desktop-portal-wlr \
    xdg-desktop-portal-gtk

# polkit agent: reuse the one Bazzite already ships (KDE):
#   /usr/libexec/polkit-kde-authentication-agent-1
# It is started from the user's sway config (home/chezmoi/dot_config/sway/config).
# PipeWire / WirePlumber are already part of the Bazzite base image.

#### Example for enabling a System Unit File
# systemctl enable <unit>
