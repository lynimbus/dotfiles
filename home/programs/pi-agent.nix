{ pkgs, ... }:

let
  settings = (pkgs.formats.json { }).generate "pi-settings.json" {
    packages = [
      "npm:pi-web-access"
      "npm:@juicesharp/rpiv-ask-user-question"
    ];
  };
in
{
  programs.pi-coding-agent = {
    enable = true;
    extraPackages = [ pkgs.nodejs ];
  };

  systemd.user.tmpfiles.rules = [
    "C %h/.pi/agent/settings.json 0644 - - - ${settings}"
    "C %h/.pi/agent/AGENTS.md 0644 - - - ${../pi-agent/AGENTS.md}"
  ];
}
