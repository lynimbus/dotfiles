{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zip
    unzip
    p7zip
    xz
    ffmpeg
    imagemagick
    poppler
  ];
}
