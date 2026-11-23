{
  liveFiles,
  ...
}:

{
  xdg.dataFile = liveFiles {
    from = "desktop/fcitx5/rime";
    into = "fcitx5/rime";
    files = [
      "default.custom.yaml"
    ];
  };
}
