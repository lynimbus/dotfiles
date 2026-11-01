# apps/profiles — optional seed lists

A "profile" is a machine name (`WORKSTATION_PROFILE`, default: hostname).
Inventories are captured per profile:

    apps/flatpak/inventory/<profile>.json     — generated, commit it
    apps/brew/inventory/<profile>/Brewfile    — generated, commit it

This directory holds OPTIONAL hand-written seed lists for brand-new machines
(what to install before the first capture exists). They are plain text, one
flatpak ID per line, applied with:

    xargs -a apps/profiles/base.flatpak.txt flatpak install --user --noninteractive flathub || true

Nothing automatic uses these files — they are a convenience for
first-boot setup, not a package manager.
