{
  config,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    userName = "lantianx";
    userEmail = "128837704+lantianx233@users.noreply.github.com";
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      git.sign-on-push = true;
      user = {
        email = "128837704+lantianx233@users.noreply.github.com";
        name = "lantianx";
      };
    };
  };
}
