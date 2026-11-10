{
  imports = [
    ./core.nix
    ./packages.nix

    ./programs/fish.nix
    ./programs/git.nix
    ./programs/jujutsu.nix
    ./programs/ssh.nix
    ./programs/direnv.nix
    ./programs/zoxide.nix
    ./programs/ghostty.nix
    ./programs/hourly-chime.nix
    ./programs/pig.nix
    ./programs/magpie.nix
    ./audio/rnnoise.nix

    ./desktop/screenshot.nix
    ./desktop/keyboard-backlight.nix
    ./desktop/niri/default.nix
    ./desktop/mango/default.nix
    ./desktop/noctalia/default.nix
  ];
}
