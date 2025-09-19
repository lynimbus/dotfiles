{ ... }:
{
  programs.git = {
    enable = true;
    userName = "lantianx";
    userEmail = "lantianx233@gmail.com";
    extraConfig = {
      merge = {
        conflictStyle = "diff3";
      };
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      git.sign-on-push = true;
      ui = {
        default-command = "log";
        editor = "nvim";
        # paginate = "never";
        pager = "delta";
        diff-formatter = ":git";
        merge-editor = "mergiraf";
      };
      user = {
        email = "lantianx233@gmail.com";
        name = "lantianx";
      };
    };
  };
}
