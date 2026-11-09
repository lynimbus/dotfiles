{
  email,
  pkgs,
  username,
  sshKey,
  ...
}:

let
  # The commit message drafter lives with the rest of the commit-style tooling
  # in docs/, and checks what it drafts with the linter next to it.
  jjmsg = pkgs.writeShellApplication {
    name = "jjmsg";
    runtimeInputs = with pkgs; [
      jj
      pig
      coreutils
      gnugrep
    ];
    text = builtins.readFile ../../docs/jjmsg.sh;
  };
in
{
  home.packages = with pkgs; [
    meld
    difftastic
    delta
    jjmsg
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
