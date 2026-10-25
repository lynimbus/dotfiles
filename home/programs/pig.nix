{ pkgs, lib, ... }:

let
  ownedSettings = (pkgs.formats.json { }).generate "pi-owned-settings.json" {
    quietStartup = "header";
    packages = [
      "npm:@pi-kaush/pi-tool-call-markers"
      "npm:@juicesharp/rpiv-ask-user-question"
      "npm:@aliou/pi-processes"
      "npm:@ff-labs/pi-fff"
      "npm:pi-web-access"
      "npm:pi-subagents"
      "npm:pi-lens"
      "npm:pi-purge"
      "npm:pi-cached-compaction"
    ];
    defaultTools = [
      "+codemode"
    ];
    codemode = {
      mode = "only";
      inlineBudget = 6000;
    };
    subagents.watchdog = {
      enabled = true;
      main = {
        model = "magpie/group/deepseek";
        thinking = "max";
      };
    };
  };
in
{
  # The package wrapper points PiG at Pi's ~/.pi/agent, where the settings
  # below, the sops-injected auth.json, the sessions and the npm packages
  # already live. PiG's own state stays in ~/.pig.
  home.packages = [ pkgs.pig ];

  home.file.".pi/agent/skills/commit-style/SKILL.md".source = ../../docs/skills/commit-style.md;

  home.activation.pigSettingsMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.pi/agent/settings.json"
    if [ -f "$target" ]; then
      merged=$(${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$target" "${ownedSettings}")
      $DRY_RUN_CMD printf '%s\n' "$merged" > "$target"
    else
      $DRY_RUN_CMD install -m 0644 "${ownedSettings}" "$target"
    fi
  '';
}
