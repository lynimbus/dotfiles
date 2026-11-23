{ pkgs, ... }:

{
  system.stateVersion = "26.05";

  documentation.nixos.enable = false;

  # Keep generated /etc as a read-only lower layer with a writable upper layer
  # at /.rw-etc/upper so local edits survive reboots and upgrades rewrite only
  # the lower layer.
  system.etc.overlay = {
    enable = true;
    mutable = true;
  };

  time.timeZone = "Asia/Tokyo";

  i18n.defaultLocale = "en_SG.UTF-8";
  i18n.supportedLocales = [
    "en_SG.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
    "ja_JP.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];

  environment.systemPackages = with pkgs; [
    curl
    wget
  ];
}
