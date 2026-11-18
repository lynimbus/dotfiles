{
  config,
  inputs,
  repoRoot,
  ...
}:

let
  repo = import ../../lib.nix { inherit config repoRoot; };
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    settings = ./config.toml;
  };

  xdg.configFile = repo.liveFiles {
    from = "desktop/noctalia/templates";
    into = "noctalia/templates";
    files = [
      "umbriel-gtk"
      "fcitx5-mellow"
    ];
  };
}
