{ config, lib, pkgs, ... }:

# MIME 默认程序声明式管理（xdg.mimeApps）
# 生成 ~/.config/mimeapps.list（store 符号链接，只读）：
#   - Thunar/其他桌面右键"设为默认"会写入失败 → 改默认必须改本文件 + home-manager switch
# 历史背景：原为手管文件（含 zed/claude-cli/sing-box 关联），2026-08-14 迁入 HM，
# 备份在 ~/.config/mimeapps.list.bak-20260814。
{
  xdg.mimeApps = {
    enable = true;

    defaultApplications = {
      # --- 文件夹 / 网页 ---
      "inode/directory" = [ "thunar.desktop" ];
      "text/html" = [ "chromium.desktop" ];
      "application/xhtml+xml" = [ "chromium.desktop" ];
      "x-scheme-handler/http" = [ "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium.desktop" ];
      "x-scheme-handler/mailto" = [ "chromium.desktop" ];
      # 专用 scheme handler
      "x-scheme-handler/claude-cli" = [ "claude-code-url-handler.desktop" ];
      "x-scheme-handler/sing-box" = [ "sing-box-reF1nd.desktop" ];

      # --- 文档 → zed（md 走 marktext） ---
      "application/json" = [ "dev.zed.Zed.desktop" ];
      "application/schema+json" = [ "dev.zed.Zed.desktop" ];
      "application/x-docbook+xml" = [ "dev.zed.Zed.desktop" ];
      "application/x-yaml" = [ "dev.zed.Zed.desktop" ];
      "text/markdown" = [ "marktext.desktop" ];
      "text/plain" = [ "dev.zed.Zed.desktop" ];
      "text/tab-separated-values" = [ "dev.zed.Zed.desktop" ];
      "text/xml" = [ "dev.zed.Zed.desktop" ];
      "text/x-csv" = [ "dev.zed.Zed.desktop" ];

      # --- 代码 → zed ---
      "text/x-c" = [ "dev.zed.Zed.desktop" ];
      "text/x-c++" = [ "dev.zed.Zed.desktop" ];
      "text/x-cmake" = [ "dev.zed.Zed.desktop" ];
      "text/x-go" = [ "dev.zed.Zed.desktop" ];
      "text/x-java" = [ "dev.zed.Zed.desktop" ];
      "text/x-perl" = [ "dev.zed.Zed.desktop" ];
      "text/x-python" = [ "dev.zed.Zed.desktop" ];
      "text/x-ruby" = [ "dev.zed.Zed.desktop" ];
      "text/x-rust" = [ "dev.zed.Zed.desktop" ];
      "text/x-shellscript" = [ "dev.zed.Zed.desktop" ];
      "text/x-tex" = [ "dev.zed.Zed.desktop" ];

      # --- 文档 → zathura(mupdf) ---
      "application/epub+zip" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/oxps" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/x-fictionbook" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/x-mobipocket-ebook" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];

      # --- 图片 → ristretto ---
      "image/bmp" = [ "org.xfce.ristretto.desktop" ];
      "image/gif" = [ "org.xfce.ristretto.desktop" ];
      "image/jpeg" = [ "org.xfce.ristretto.desktop" ];
      "image/png" = [ "org.xfce.ristretto.desktop" ];
      "image/svg+xml" = [ "org.xfce.ristretto.desktop" ];
      "image/tiff" = [ "org.xfce.ristretto.desktop" ];
      "image/webp" = [ "org.xfce.ristretto.desktop" ];
      "image/x-pixmap" = [ "org.xfce.ristretto.desktop" ];
      "image/x-xpixmap" = [ "org.xfce.ristretto.desktop" ];

      # --- 压缩包 → ark ---
      "application/arj" = [ "org.kde.ark.desktop" ];
      "application/vnd.debian.binary-package" = [ "org.kde.ark.desktop" ];
      "application/vnd.ms-cab-compressed" = [ "org.kde.ark.desktop" ];
      "application/vnd.rar" = [ "org.kde.ark.desktop" ];
      "application/x-7z-compressed" = [ "org.kde.ark.desktop" ];
      "application/x-archive" = [ "org.kde.ark.desktop" ];
      "application/x-arj" = [ "org.kde.ark.desktop" ];
      "application/x-bzip2" = [ "org.kde.ark.desktop" ];
      "application/x-cd-image" = [ "org.kde.ark.desktop" ];
      "application/x-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-bzip2-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-xz-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-zstd-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-deb" = [ "org.kde.ark.desktop" ];
      "application/x-java-archive" = [ "org.kde.ark.desktop" ];
      "application/x-rpm" = [ "org.kde.ark.desktop" ];
      "application/x-tar" = [ "org.kde.ark.desktop" ];
      "application/x-xz" = [ "org.kde.ark.desktop" ];
      "application/gzip" = [ "org.kde.ark.desktop" ];
      "application/zip" = [ "org.kde.ark.desktop" ];
      "application/zstd" = [ "org.kde.ark.desktop" ];

      # --- 视频 → vlc ---
      "video/3gpp" = [ "vlc.desktop" ];
      "video/3gpp2" = [ "vlc.desktop" ];
      "video/divx" = [ "vlc.desktop" ];
      "video/mp2t" = [ "vlc.desktop" ];
      "video/mp4" = [ "vlc.desktop" ];
      "video/mpeg" = [ "vlc.desktop" ];
      "video/ogg" = [ "vlc.desktop" ];
      "video/quicktime" = [ "vlc.desktop" ];
      "video/vnd.rn-realvideo" = [ "vlc.desktop" ];
      "video/webm" = [ "vlc.desktop" ];
      "video/x-flv" = [ "vlc.desktop" ];
      "video/x-m4v" = [ "vlc.desktop" ];
      "video/x-matroska" = [ "vlc.desktop" ];
      "video/x-ms-asf" = [ "vlc.desktop" ];
      "video/x-ms-wmv" = [ "vlc.desktop" ];
      "video/x-msvideo" = [ "vlc.desktop" ];

      # --- 音频 → vlc ---
      "audio/aac" = [ "vlc.desktop" ];
      "audio/ac3" = [ "vlc.desktop" ];
      "audio/flac" = [ "vlc.desktop" ];
      "audio/midi" = [ "vlc.desktop" ];
      "audio/mp4" = [ "vlc.desktop" ];
      "audio/mpeg" = [ "vlc.desktop" ];
      "audio/ogg" = [ "vlc.desktop" ];
      "audio/opus" = [ "vlc.desktop" ];
      "audio/vorbis" = [ "vlc.desktop" ];
      "audio/wav" = [ "vlc.desktop" ];
      "audio/x-ape" = [ "vlc.desktop" ];
      "audio/x-flac" = [ "vlc.desktop" ];
      "audio/x-m4a" = [ "vlc.desktop" ];
      "audio/x-midi" = [ "vlc.desktop" ];
      "audio/x-mpegurl" = [ "vlc.desktop" ];
      "audio/x-ms-wma" = [ "vlc.desktop" ];
      "audio/x-wav" = [ "vlc.desktop" ];
      "audio/x-wavpack" = [ "vlc.desktop" ];
    };

    # "打开方式"菜单里的备选应用
    associations.added = {
      "application/json" = [ "dev.zed.Zed.desktop" ];
      "application/schema+json" = [ "dev.zed.Zed.desktop" ];
      "application/x-docbook+xml" = [ "dev.zed.Zed.desktop" ];
      "application/x-yaml" = [ "dev.zed.Zed.desktop" ];
      "application/epub+zip" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/oxps" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/pdf" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/x-fictionbook" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/x-mobipocket-ebook" = [ "org.pwmt.zathura-pdf-mupdf.desktop" ];
      "application/xhtml+xml" = [ "chromium.desktop" ];
      "text/html" = [ "chromium.desktop" ];
      "text/markdown" = [ "marktext.desktop" "dev.zed.Zed.desktop" ];
      "text/plain" = [ "dev.zed.Zed.desktop" ];
      "text/x-cmake" = [ "dev.zed.Zed.desktop" ];
      "text/x-shellscript" = [ "dev.zed.Zed.desktop" ];
      "text/xml" = [ "dev.zed.Zed.desktop" ];
      "text/x-c" = [ "dev.zed.Zed.desktop" ];
      "text/x-c++" = [ "dev.zed.Zed.desktop" ];
      "text/x-csv" = [ "dev.zed.Zed.desktop" ];
      "text/x-go" = [ "dev.zed.Zed.desktop" ];
      "text/x-java" = [ "dev.zed.Zed.desktop" ];
      "text/x-perl" = [ "dev.zed.Zed.desktop" ];
      "text/x-python" = [ "dev.zed.Zed.desktop" ];
      "text/x-ruby" = [ "dev.zed.Zed.desktop" ];
      "text/x-rust" = [ "dev.zed.Zed.desktop" ];
      "text/x-tex" = [ "dev.zed.Zed.desktop" ];
      "text/tab-separated-values" = [ "dev.zed.Zed.desktop" ];
      "image/bmp" = [ "org.xfce.ristretto.desktop" ];
      "image/gif" = [ "org.xfce.ristretto.desktop" ];
      "image/jpeg" = [ "org.xfce.ristretto.desktop" ];
      "image/png" = [ "org.xfce.ristretto.desktop" ];
      "image/svg+xml" = [ "org.xfce.ristretto.desktop" ];
      "image/tiff" = [ "org.xfce.ristretto.desktop" ];
      "image/webp" = [ "org.xfce.ristretto.desktop" ];
      "image/x-pixmap" = [ "org.xfce.ristretto.desktop" ];
      "image/x-xpixmap" = [ "org.xfce.ristretto.desktop" ];
      "application/zip" = [ "org.kde.ark.desktop" ];
      "application/x-7z-compressed" = [ "org.kde.ark.desktop" ];
      "application/x-tar" = [ "org.kde.ark.desktop" ];
      "application/gzip" = [ "org.kde.ark.desktop" ];
      "application/x-bzip2" = [ "org.kde.ark.desktop" ];
      "application/x-xz" = [ "org.kde.ark.desktop" ];
      "application/zstd" = [ "org.kde.ark.desktop" ];
      "application/x-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-bzip2-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-xz-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-zstd-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/vnd.rar" = [ "org.kde.ark.desktop" ];
      "application/x-cd-image" = [ "org.kde.ark.desktop" ];
      "application/x-deb" = [ "org.kde.ark.desktop" ];
      "application/vnd.debian.binary-package" = [ "org.kde.ark.desktop" ];
      "application/x-java-archive" = [ "org.kde.ark.desktop" ];
      "application/x-rpm" = [ "org.kde.ark.desktop" ];
      "application/x-archive" = [ "org.kde.ark.desktop" ];
      "application/x-arj" = [ "org.kde.ark.desktop" ];
      "application/vnd.ms-cab-compressed" = [ "org.kde.ark.desktop" ];
      "video/mp4" = [ "vlc.desktop" ];
      "video/x-matroska" = [ "vlc.desktop" ];
      "video/webm" = [ "vlc.desktop" ];
      "video/x-msvideo" = [ "vlc.desktop" ];
      "video/quicktime" = [ "vlc.desktop" ];
      "video/mpeg" = [ "vlc.desktop" ];
      "video/mp2t" = [ "vlc.desktop" ];
      "video/3gpp" = [ "vlc.desktop" ];
      "video/3gpp2" = [ "vlc.desktop" ];
      "video/x-flv" = [ "vlc.desktop" ];
      "video/ogg" = [ "vlc.desktop" ];
      "video/x-m4v" = [ "vlc.desktop" ];
      "video/x-ms-wmv" = [ "vlc.desktop" ];
      "video/x-ms-asf" = [ "vlc.desktop" ];
      "video/divx" = [ "vlc.desktop" ];
      "video/vnd.rn-realvideo" = [ "vlc.desktop" ];
      "audio/mpeg" = [ "vlc.desktop" ];
      "audio/mp4" = [ "vlc.desktop" ];
      "audio/aac" = [ "vlc.desktop" ];
      "audio/flac" = [ "vlc.desktop" ];
      "audio/x-flac" = [ "vlc.desktop" ];
      "audio/ogg" = [ "vlc.desktop" ];
      "audio/vorbis" = [ "vlc.desktop" ];
      "audio/opus" = [ "vlc.desktop" ];
      "audio/wav" = [ "vlc.desktop" ];
      "audio/x-wav" = [ "vlc.desktop" ];
      "audio/x-m4a" = [ "vlc.desktop" ];
      "audio/x-ms-wma" = [ "vlc.desktop" ];
      "audio/midi" = [ "vlc.desktop" ];
      "audio/x-midi" = [ "vlc.desktop" ];
      "audio/ac3" = [ "vlc.desktop" ];
      "audio/x-ape" = [ "vlc.desktop" ];
      "audio/x-wavpack" = [ "vlc.desktop" ];
      "audio/x-mpegurl" = [ "vlc.desktop" ];
      "x-scheme-handler/http" = [ "chromium.desktop" ];
      "x-scheme-handler/https" = [ "chromium.desktop" ];
    };
  };
}
