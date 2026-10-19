{
  email,
  username,
  pkgs,
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
        sign-on-push = true;
        private-commits = "description(glob:'wip:*') | description(glob:'private:*')";
      };
      ui = {
        default-command = "log";
        editor = "nvim";
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
