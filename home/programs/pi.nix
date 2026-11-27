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
  # pi (from the upstream flake) keeps settings, sessions, extensions, and npm
  # packages in ~/.pi/agent. rtk on PATH serves extensions/rtk.ts.
  home.packages = [
    pkgs.pi
    pkgs.rtk
  ];

  # Upstream pi is store-managed, so suppress npm update checks at startup.
  home.sessionVariables.PI_SKIP_VERSION_CHECK = "1";

  home.activation.piSettingsMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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
