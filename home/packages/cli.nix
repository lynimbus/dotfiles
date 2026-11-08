{ pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim
    helix
    ripgrep
    fzf
    jq
    just
    nvd
    gh
    jjui
    fd
    eza
    bat
    fastfetch
    dig
    shellcheck
    libxml2
    file
    sing-box
  ];
}
