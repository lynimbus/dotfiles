{
  pkgs,
  lib,
  config,
  ...
}: {
  nixpkgs.overlays = [
    (final: prev: {
      librime =
        (prev.librime.override {
          plugins = [
            pkgs.librime-lua
            pkgs.librime-octagram
          ];
        }).overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [pkgs.luajit]; # 用luajit
          #buildInputs = (old.buildInputs or []) ++ [pkgs.lua5_4]; # 用lua5.4
        });
    })
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      (fcitx5-rime.override {
        rimeDataPkgs =
          with pkgs.nur.repos.linyinfeng.rimePackages;
            withRimeDeps [
              rime-ice
            ];
      })
      fcitx5-chinese-addons
      fcitx5-gtk
      kdePackages.fcitx5-qt
      fcitx5-nord
      fcitx5-material-color
    ];
  };

  environment.variables = lib.mkIf (!config.i18n.inputMethod.fcitx5.waylandFrontend) {
    INPUT_METHOD = "fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
    QT_IM_MODULES = "wayland;fcitx;ibus";
  };
}

# copy to .local/share/fcitx5/rime/default.custom.yaml

# patch:
#  # 仅使用「雾凇拼音」的默认配置，配置此行即可
#  __include: rime_ice_suggestion:/
#  # 以下根据自己所需自行定义，仅做参考。
#  # 针对对应处方的定制条目，请使用 <recipe>.custom.yaml 中配置，例如 rime_ice.custom.yaml
#  __patch:
#    menu/page_size: 5
#    key_binder/bindings/+:
#      # 开启逗号句号翻页
#      - { when: paging, accept: comma, send: Page_Up }
#      - { when: has_menu, accept: period, send: Page_Down }

