{
  imports = [
    ./core.nix
    ./fonts.nix
    ./packages.nix
    ./mimeapps.nix

    ./programs/fish.nix
    ./programs/git.nix
    ./programs/jujutsu.nix
    ./programs/ssh.nix
    ./programs/direnv.nix
    ./programs/zoxide.nix
    ./programs/yazi.nix
    ./programs/ghostty.nix
    ./programs/hourly-chime.nix
    ./programs/hy-mt2.nix
    ./programs/memo.nix
    ./programs/pig.nix
    ./programs/magpie.nix
    ./programs/blackhole.nix
    ./programs/nsh.nix
    ./programs/rust.nix
    ./audio/rnnoise.nix

    ./desktop/keyboard-backlight.nix
    ./desktop/umbriel/default.nix
    ./desktop/mango/default.nix
    ./desktop/noctalia/default.nix
    ./desktop/luciole/default.nix
    ./desktop/fcitx5/default.nix
  ];
}
