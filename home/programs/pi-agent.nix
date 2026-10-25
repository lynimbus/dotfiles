{ pkgs, lib, ... }:

let
  ownedSettings = (pkgs.formats.json { }).generate "pi-owned-settings.json" {
    packages = [
      "npm:@pi-kaush/pi-tool-call-markers"
      "npm:@juicesharp/rpiv-ask-user-question"
      "npm:@aliou/pi-processes"
      "npm:@ff-labs/pi-fff"
      "npm:@jiangkoumo/pi-pstack"
      "npm:pi-subagents"
      "npm:pi-lens"
      "npm:pi-cached-compaction"
    ];
    defaultTools = [
      "codemode"
      "read"
      "bash"
      "edit"
      "write"
    ];
    codemode.mode = "only";
    codemode.inlineBudget = 6000;
  };
in
{
  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-coding-agent;
  };

  home.file.".pi/agent/skills/commit-style/SKILL.md".source = ../../docs/skills/commit-style.md;

  home.activation.piSettingsMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="$HOME/.pi/agent/settings.json"
    if [ -f "$target" ]; then
      merged=$(${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$target" "${ownedSettings}")
      $DRY_RUN_CMD printf '%s\n' "$merged" > "$target"
    else
      $DRY_RUN_CMD install -m 0644 "${ownedSettings}" "$target"
    fi
  '';
}
