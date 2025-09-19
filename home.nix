{
  inputs,
  ...
}:
{
  imports = [
    (inputs.import-tree ./home)
  ];

  home.username = "lantianx";
  home.homeDirectory = "/home/lantianx";
  home.stateVersion = "25.05";
}
