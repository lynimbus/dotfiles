{
  inputs,
  liveFiles,
  ...
}:

{
  imports = [
    inputs.umbriel.homeModules.default
  ];

  programs.umbriel.enable = true;

  xdg.configFile = liveFiles {
    from = "desktop/umbriel/conf";
    into = "umbriel";
    files = [
      "config.toml"
    ];
  };
}
