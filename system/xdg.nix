{ pkgs, ... }:

{
  xdg.terminal-exec = {
    enable = true;
    package = pkgs.xdg-terminal-exec;
    settings = {
      niri = [
        "foot.desktop"
        "Alacritty.desktop"
        "com.mitchellh.ghostty.desktop"
      ];
      default = [
        "foot.desktop"
        "Alacritty.desktop"
        "com.mitchellh.ghostty.desktop"
      ];
    };
  };

  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  # autostart 的 app 等 portal 起来再启动，避免首次打开文件选择器失败
  systemd.user.units."app-@autostart.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      After=xdg-desktop-portal.service xdg-desktop-portal-gtk.service xdg-desktop-portal-gnome.service
      Wants=xdg-desktop-portal.service xdg-desktop-portal-gtk.service xdg-desktop-portal-gnome.service
    '';
  };
}
