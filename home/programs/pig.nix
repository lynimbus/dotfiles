{ pkgs, lib, ... }:

let
  ownedSettings = (pkgs.formats.json { }).generate "pi-owned-settings.json" {
    theme = "system";
    quietStartup = "header";
    packages = [
      "npm:@pi-kaush/pi-tool-call-markers"
      "npm:@juicesharp/rpiv-ask-user-question"
      "npm:@chensl/pi-unified-exec"
      "npm:@aliou/pi-processes"
      "npm:@ff-labs/pi-fff"
      "npm:pi-web-access"
    ];
    defaultTools = [
      "+codemode"
    ];
    codemode = {
      mode = "only";
      inlineBudget = 6000;
    };
    enableAnalytics = false;
  };
in
{
  # The package wrapper points PiG at Pi's ~/.pi/agent, where the settings
  # below, the sessions and the npm packages already live. PiG's own state stays
  # in ~/.pig.
  home.packages = [ pkgs.pig ];

  home.activation.pigSettingsMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.pi/agent/settings.json"
    merged="$(mktemp)"
    if [ -f "$target" ]; then
      ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$target" "${ownedSettings}" > "$merged"
    else
      cp "${ownedSettings}" "$merged"
    fi
    $DRY_RUN_CMD install -m 0644 "$merged" "$target"
    rm -f "$merged"
  '';
}
