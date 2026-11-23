{ pkgs, lib, ... }:

let
  ownedSettings = (pkgs.formats.json { }).generate "pi-owned-settings.json" {
    enableAnalytics = false;
    quietStartup = "header";
    defaultTools = [
      "+codemode"
    ];
    packages = [
      "npm:@pi-kaush/pi-tool-call-markers"
      "npm:@juicesharp/rpiv-ask-user-question"
      "npm:@chensl/pi-unified-exec"
      "npm:@aliou/pi-processes"
      "npm:@ff-labs/pi-fff"
      "npm:pi-web-access"
    ];
  };
in
{
  # Both pi (from the upstream flake) and pig (with PIG_USE_PI_DIRS=1) share
  # ~/.pi/agent for settings, sessions, extensions, and npm packages; pig's own
  # state stays in ~/.pig. rtk on PATH serves extensions/rtk.ts for both, and
  # pig-swarm fans pig out over one problem with a bd epic as the ledger.
  home.packages = [
    pkgs.pi
    pkgs.pig
    pkgs.pig-swarm
    pkgs.rtk
  ];

  # Upstream pi is store-managed, so suppress npm update checks at startup.
  home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";

  home.activation.pigSettingsMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.pi/agent/settings.json"
    merged="$(mktemp)"
    if [ -f "$target" ]; then
      ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$target" "${ownedSettings}" > "$merged"
    else
      cp "${ownedSettings}" "$merged"
    fi
    $DRY_RUN_CMD mkdir -p "$(dirname "$target")"
    $DRY_RUN_CMD install -m 0644 "$merged" "$target"
    rm -f "$merged"
  '';
}
