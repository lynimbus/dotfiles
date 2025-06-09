{
  config,
  pkgs,
  inputs,
  ...
}: {
  home.packages = with pkgs; [
    lazygit
    diffedit3
    jj-fzf
    jjui
    lazyjj
    meld
  ];
  programs.git = {
    enable = true;
    userName = "lantianx";
    userEmail = "128837704+lantianx233@users.noreply.github.com";
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      git.sign-on-push = true;
      ui = {
        default-command = "log";
        editor = "nano";
        pager = ":builtin";
        diff-editor = "meld-3"; # Or `kdiff3`, or `diffedit3`, ...
        merge-editor = "meld-3"; # Or "vscode" or "vscodium" or "kdiff3" or "vimdiff"
      };
      user = {
        email = "128837704+lantianx233@users.noreply.github.com";
        name = "lantianx";
      };
      signing = {
        backend = "ssh";
        behavior = "own";
        key = "~/.ssh/id_ed25519.pub";
      };
    };
  };
}
