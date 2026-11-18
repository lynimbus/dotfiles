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
    inputs.umbriel.homeModules.default
  ];

  programs.umbriel.enable = true;

  xdg.configFile = repo.liveFiles {
    from = "desktop/umbriel/conf";
    into = "umbriel";
    files = [
      "config.toml"
    ];
  };
}
