{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    maple-mono."NF-CN"
    fira-code
    intel-one-mono
    nerd-fonts.intone-mono
  ];
}
