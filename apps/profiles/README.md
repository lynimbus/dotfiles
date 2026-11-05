# apps/profiles — optional seed lists

A "profile" is a machine name (`WORKSTATION_PROFILE`, default: hostname).
Inventories are captured per profile:

    apps/flatpak/inventory/<profile>.json     — generated, commit it
    apps/brew/inventory/<profile>/Brewfile    — generated, commit it

This directory holds OPTIONAL hand-written seed lists for brand-new machines
(what to install before the first capture exists). `base.flatpak.txt` is one
flatpak ID per line with `#` comments; apply it with:

    just flatpak-seed
    # equivalent, if you prefer the raw command (the grep drops the comments —
    # xargs does NOT ignore them and chokes on the apostrophes in prose). Note
    # there is NO --user/--system here on purpose: `just flatpak-seed` detects
    # the scope that owns the flathub remote (system on Bazzite) and a wrong
    # hard-coded scope fails with "no remote refs found for flathub":
    grep -Ev '^[[:space:]]*(#|$)' apps/profiles/base.flatpak.txt \
      | xargs -r flatpak install --noninteractive flathub || true

`base.Brewfile` is a normal Brewfile:

    just brew-seed
    # equivalent: brew bundle --file apps/profiles/base.Brewfile

Nothing automatic uses these files — they are a convenience for
first-boot setup, not a package manager.
