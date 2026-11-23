{
  config,
  repoRoot,
  ...
}:

let
  repo = import ../../lib.nix { inherit config repoRoot; };
in
{
  xdg.dataFile = repo.liveFiles {
    from = "desktop/fcitx5/rime";
    into = "fcitx5/rime";
    files = [
      "default.custom.yaml"
    ];
  };
}
