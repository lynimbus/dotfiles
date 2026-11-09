{ ... }:

{
  programs.niri.enable = true;

  # Portal preferences live in system/xdg.nix, together with the portal packages
  # both desktops install.
  systemd.user.services.niri = {
    overrideStrategy = "asDropin";
    environment = {
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_DESKTOP = "niri";
    };
  };

  # niri would otherwise pull nautilus in for its own file-manager needs; strata
  # is what this machine uses.
  programs.niri.useNautilus = false;
}
