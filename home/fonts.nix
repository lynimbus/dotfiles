{ ... }:

let
  fontDefaults = import ../defaults/fonts.nix;
in
{
  # Steam's Pressure Vessel container shadows /etc/fonts and only reads
  # per-user fontconfig under ~/.config/fontconfig/conf.d.
  fonts.fontconfig = {
    defaultFonts = fontDefaults.defaultFonts;
    configFile."cjk-aliases" = {
      enable = true;
      priority = 53;
      text = fontDefaults.cjkAliasesXml;
    };
  };
}
