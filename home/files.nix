{ lib, pkgs, ... }:
{
  xdg.configFile.".ripgreprc".source = ../assets/ripgreprc;
  xdg.configFile."starship.toml".source = ../assets/starship.toml;
  home.file.".local/share/fcitx5/rime/default.custom.yaml".source =
    ../assets/rime/default.custom.yaml;

  # https://wiki.archlinux.org.cn/title/Tencent_QQ#Empty_login_page_after_a_hot_update
  home.activation.qqRollbackScript = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash ${builtins.toPath ../assets/QQ/qq-version-rollback.sh}
  '';
}
