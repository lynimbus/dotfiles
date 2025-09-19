{
  inputs,
  username,
  ...
}:
{
  imports = [
    (inputs.import-tree ./home)
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";
}
