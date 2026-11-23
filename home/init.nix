{ config, repoRoot, ... }:

{
  # Shared out-of-store symlink helper for desktop configs kept editable without
  # rebuilding, passed to every Home Manager module without relative imports.
  _module.args.liveFiles =
    {
      from,
      into,
      files,
    }:
    builtins.listToAttrs (
      map (file: {
        name = "${into}/${file}";
        value.source = config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/${from}/${file}";
      }) files
    );

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
    ./programs/fzf.nix
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
