{ pkgs, ... }:

{
  users.users."lynimbus" = {
    isNormalUser = true;
    description = "lynimbus";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    # 登录 shell 换成 nushell。NixOS 会自动把它装进 systemPackages 并注册进 /etc/shells。
    # 当前会话仍是旧 shell，重新登录后生效。
    shell = pkgs.nushell;
  };

  # wheel 组 sudo 免密（旧配置沿用）
  security.sudo.wheelNeedsPassword = false;

}
