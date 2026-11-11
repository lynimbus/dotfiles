# The program that answers a file chooser. Both desktops run the same one. Each
# compositor's module keeps its own section, and this merges into it rather than
# replacing it, hence mkForce on niri's.
{ lib, ... }:

{
  xdg.portal.config = {
    niri."org.freedesktop.impl.portal.FileChooser" = lib.mkForce "strata;gtk";
    mango."org.freedesktop.impl.portal.FileChooser" = lib.mkForce "strata;gtk";
  };
}
