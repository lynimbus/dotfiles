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

      # qbittorrent
      "application/x-bittorrent" = [ "org.qbittorrent.qBittorrent.desktop" ];
      "x-scheme-handler/magnet" = [ "org.qbittorrent.qBittorrent.desktop" ];

      # haruna: double-clicking a video opens the GUI player; mpv itself is the
      # CLI and keeps its own desktop entry for "Open with".
      "video/mp4" = [ "org.kde.haruna.desktop" ];
      "video/mp2t" = [ "org.kde.haruna.desktop" ];
      "video/mpeg" = [ "org.kde.haruna.desktop" ];
      "video/ogg" = [ "org.kde.haruna.desktop" ];
      "video/quicktime" = [ "org.kde.haruna.desktop" ];
      "video/vnd.avi" = [ "org.kde.haruna.desktop" ];
      "video/webm" = [ "org.kde.haruna.desktop" ];
      "video/x-flv" = [ "org.kde.haruna.desktop" ];
      "video/x-matroska" = [ "org.kde.haruna.desktop" ];
      "video/x-ms-wmv" = [ "org.kde.haruna.desktop" ];
      "video/x-msvideo" = [ "org.kde.haruna.desktop" ];

      # luciole
      "inode/directory" = [ "dev.noctalia.luciole.desktop" ];

      # file-roller: browse/extract/create archives instead of opening folders
      "application/bzip2" = [ "org.gnome.FileRoller.desktop" ];
      "application/gzip" = [ "org.gnome.FileRoller.desktop" ];
      "application/vnd.ms-cab-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/vnd.rar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-archive" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-bzip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-bzip-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-cd-image" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-compress" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-cpio" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-gzip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-lha" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-lz4" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-lz4-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-lzip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-lzip-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-lzma" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-lzma-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-ms-wim" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-rar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-rar-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-xz" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-xz-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-zip-compressed" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-zstd-compressed-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/zstd" = [ "org.gnome.FileRoller.desktop" ];
    };
  };
}
