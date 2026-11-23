{ pkgs, ... }:

let
  fontDefaults = import ../lib/fonts.nix;
in
{
  # Disable NixOS's default font set because it pulls in the CFF2 variable
  # noto-fonts-cjk-* (.otf.ttc) and unifont; older FreeType/Skia/CEF runtimes
  # (such as Steam's Pressure Vessel) can skip variable CFF2 TTC faces and fall
  # back to Maple Mono NF CN (1.2em wide CJK).
  fonts.enableDefaultPackages = false;

  fonts.packages = with pkgs; [
    dejavu_fonts
    liberation_ttf
    gyre-fonts
    freefont_ttf
    noto-fonts
    noto-fonts-cjk-sans-static
    noto-fonts-cjk-serif-static
    noto-fonts-color-emoji
    nerd-fonts.jetbrains-mono
    maple-mono."NF-CN"
    fira-code
    intel-one-mono
    nerd-fonts.intone-mono
  ];

  fonts.fontconfig = {
    defaultFonts = fontDefaults.defaultFonts;
    localConf = fontDefaults.cjkAliasesXml;
  };
}
