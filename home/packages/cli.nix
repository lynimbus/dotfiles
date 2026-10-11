{ inputs, pkgs, ... }:

{
  home.packages = with pkgs; [
    neovim
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
    sops
    age
    ssh-to-age
    libxml2
    file
    inputs.sing-box-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
    sing-box-reF1nd
  ];
}
