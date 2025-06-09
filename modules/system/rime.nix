{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  nixpkgs.overlays = [
    (final: prev: {
      librime =
        (prev.librime.override {
          plugins = [
            #           (pkgs.fetchFromGitHub {
            #             owner = "hchunhui";
            #             repo = "librime-lua";
            #             rev = "e3912a4b3ac2c202d89face3fef3d41eb1d7fcd6";
            #             sha256 = "sha256-zx0F41szn5qlc2MNjt1vizLIsIFQ67fp5cb8U8UUgtY=";
            #           })
            pkgs.librime-lua
            pkgs.librime-octagram
          ];
        }).overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [pkgs.luajit]; # 用luajit
          #         buildInputs = (old.buildInputs or []) ++ [pkgs.lua5_4]; # 用lua5.4
        });
    })
  ];

  #   i18n.inputMethod.enable = false;

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      rime-data # 如果你不需要内置数据可以注释掉，我就注释掉了
      fcitx5-gtk
      kdePackages.fcitx5-qt
      fcitx5-rime
      fcitx5-nord # 主题
      #       fcitx5-material-color # 主题
    ];
  };

  #   i18n.inputMethod = {
  #     type = "ibus"; # 用iBus框架
  #     enable = true;
  #     ibus.engines = with pkgs.ibus-engines; [
  #       rime
  #     ];
  #   };
}
