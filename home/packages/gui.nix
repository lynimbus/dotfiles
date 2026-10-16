{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ladspaPlugins
    rnnoise-plugin
    brightnessctl
    ddcutil
    wlsunset
    wl-clipboard
    tmux
    libnotify
    gvfs
    xwayland-satellite
    ungoogled-chromium
    ayugram-desktop
    qq
    wechat-uos
    strata
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
  ];
}
