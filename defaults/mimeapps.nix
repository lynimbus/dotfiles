# What each file type opens with. home-manager renders this into
# ~/.config/mimeapps.list, so this file is the whole of the default
# associations.
{ ... }:

{
  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      # chromium
      "application/xhtml+xml" = [ "chromium-browser.desktop" ];
      "text/html" = [ "chromium-browser.desktop" ];
      "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
      "x-scheme-handler/https" = [ "chromium-browser.desktop" ];

      # strata
      "inode/directory" = [ "io.github.lgse.Strata.desktop" ];
    };
  };
}
