{
  email,
  pkgs,
  username,
  sshKey,
  ...
}:
{
  home.packages = with pkgs; [
    meld
    difftastic
    delta
  ];

  programs.jujutsu = {
    enable = true;
    settings = {
      user.name = username;
      user.email = email;
      git = {
        private-commits = "description(glob:'wip:*') | description(glob:'private:*')";
      };
      revsets = {
        git-sign-on-push = "~signed() & mine()";
      };
      ui = {
        default-command = "log";
        diff-formatter = "difft";
        diff-editor = ":builtin";
        merge-editor = "meld";
      };
      aliases.delta = [
        "diff"
        "--git"
        "--config"
        "ui.pager=[\"delta\", \"--navigate\"]"
      ];
      revset-aliases = {
        "immutable_heads()" = "untracked_remote_bookmarks()";
      };
      signing = {
        backend = "ssh";
        key = sshKey;
      };
    };
  };
}
