{
  inputs,
  config,
  repoRoot,
  ...
}:

let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;

  repoFile = path: mkSymlink "${repoRoot}/home/desktop/noctalia/${path}";

  linkFiles =
    dir: files:
    builtins.listToAttrs (
      map (file: {
        name = "noctalia/${dir}/${file}";
        value.source = repoFile "${dir}/${file}";
      }) files
    );
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    settings = ./config.toml;
  };

  xdg.configFile = linkFiles "templates" [
    "gtk-3.0.css"
    "gtk-4.0.css"
    "mango.conf"
    "fcitx5"
  ];
}
