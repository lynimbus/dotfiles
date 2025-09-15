{ ... }:
{
  services.xserver.enable = true;

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.sddm.settings.General.DisplayServer = "wayland";

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "lantianx";

  services.desktopManager.plasma6.enable = true;
}
