{
  pkgs,
  lib,
  config,
  ...
}: {
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    #        fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      (fcitx5-rime.override {
        rimeDataPkgs = with pkgs.nur.repos.linyinfeng.rimePackages;
          withRimeDeps [
            rime-ice
          ];
      })
      fcitx5-gtk
      fcitx5-configtool
    ];
    #    type = "ibus";
    #    ibus.engines = with pkgs.ibus-engines; [
    #      (rime.override {
    #        rimeDataPkgs = with pkgs.nur.repos.linyinfeng.rimePackages;
    #          withRimeDeps [
    #            rime-ice
    #          ];
    #      })
    #    ];
  };
}
# copy to ~/.local/share/fcitx5/rime/default.custom.yaml or ~/.config/ibus/rime/default.custom.yaml
# patch:
#  __include: rime_ice_suggestion:/
#  __patch:
#    menu/page_size: 5
#    key_binder/bindings/+:
#      - { when: paging, accept: comma, send: Page_Up }
#      - { when: has_menu, accept: period, send: Page_Down }

