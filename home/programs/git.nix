{ email, username, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = username;
      user.email = email;
      init.defaultBranch = "main";
      pull.rebase = true;
      merge.conflictstyle = "zdiff3";
      diff.colorMoved = "default";
      push.autoSetupRemote = true;
      fetch.prune = true;
      rerere.enabled = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      dark = true;
    };
  };
}
