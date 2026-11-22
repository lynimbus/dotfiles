{ username, homeDirectory, ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "26.05";

  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
