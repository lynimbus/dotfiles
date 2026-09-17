{ email, username, ... }:

{
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
      };
      revset-aliases = {
        "immutable_heads()" = "untracked_remote_bookmarks()";
      };
      signing = {
        backend = "ssh";
        key = "/home/${username}/.ssh/id_ed25519";
      };
    };
  };
}
