{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ungoogled-chromium
    ayugram-desktop
    qq
    wechat-uos
    ladspaPlugins
    rnnoise-plugin
    brightnessctl
    ddcutil
    wlsunset
    tmux
    libnotify
    gvfs
  ];
}
