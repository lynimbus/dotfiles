{ inputs, ... }:
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ./secrets.nix
    ./core.nix
    ./packages/cli.nix
    ./packages/dev.nix
    ./packages/archive.nix
    ./packages/gui.nix
    ./programs/fish.nix
    ./programs/zed.nix
    ./programs/yazi.nix
    ./programs/jujutsu.nix
    ./programs/git.nix
    ./programs/ssh.nix
    ./programs/direnv.nix
    ./programs/zoxide.nix
    ./audio/rnnoise.nix
    ./programs/pi-agent.nix
    ./desktop/niri/default.nix
    ./desktop/noctalia/default.nix
    ./programs/foot.nix
    ./programs/alacritty.nix
    ./desktop/hypridle.nix
  ];
}
