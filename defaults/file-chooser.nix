# The program that answers a file chooser. Both desktops run the same one. Each
# compositor's module keeps its own section, and this merges into it rather than
# replacing it, hence mkForce.
{ lib, ... }:

{
  xdg.portal.config = {
    umbriel."org.freedesktop.impl.portal.FileChooser" = lib.mkForce "gnome;gtk";
    mango."org.freedesktop.impl.portal.FileChooser" = lib.mkForce "gnome;gtk";
  };
}
