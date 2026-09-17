{ pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim
    helix
    git
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
    zoxide
    dig
    shellcheck
    libxml2
    file
  ];
}
