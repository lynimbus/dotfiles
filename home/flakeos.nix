{ username, ... }:

{
  imports = [
    ../modules/home/core.nix
    ../modules/home/desktop/niri.nix
    ../modules/home/desktop/noctalia.nix
    ../modules/home/programs/nushell.nix
    ../modules/home/services/dsh.nix
    ../modules/home/tools/pi-agent.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";
}
