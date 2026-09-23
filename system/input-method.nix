{ pkgs, ... }:

{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      ignoreUserConfig = true;
      addons = with pkgs; [
        qingjian
        (fcitx5-rime.override {
          rimeDataPkgs = [ rime-ice ];
        })
      ];
      settings = {
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "qingjian";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "qingjian";
          GroupOrder."0" = "Default";
        };
      };
    };
  };
}
