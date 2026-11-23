{ ... }:

{
  # pkgs.sing-box comes from overlay.nix (pkgs/sing-box.nix, upstream prerelease
  # binaries with libcronet.so and the systemd/dbus/polkit assets NixOS expects).
  # Leaving settings empty makes services.sing-box read /etc/sing-box/*.json
  # instead of generating /run/sing-box/config.json, so the configuration stays
  # outside the Nix store and out of git via the mutable /etc overlay
  # (system/core.nix).
  services.sing-box.enable = true;

  # Skip starting when /etc/sing-box has no config yet (e.g. on first switch
  # before config.json is placed there) rather than crash-looping.
  systemd.services.sing-box.unitConfig.ConditionDirectoryNotEmpty = "/etc/sing-box";
}
