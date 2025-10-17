{ pkgs, ... }:
{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = with pkgs; [
    broot
    fastfetch
    hyfetch

    zip
    xz
    unzip
    p7zip

    ffmpeg
    jq
    poppler
    fd
    ripgrep
    fzf
    zoxide
    resvg
    imagemagick
    eza
    devenv
    devbox

    lazygit
    lazyjj
    jjui
    jj-fzf
    mergiraf
    delta

    vscode-fhs
    zed-editor-fhs
    telegram-desktop
    qq
    motrix
    obs-studio

    hmcl
    zulu
  ];
}
