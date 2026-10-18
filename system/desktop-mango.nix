{ ... }:

{
  programs.mango.enable = true;

  xdg.portal.config.mango."org.freedesktop.impl.portal.FileChooser" = "strata;gtk";
}
