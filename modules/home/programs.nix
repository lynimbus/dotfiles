{
  config,
  pkgs,
  ...
}: {
  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.ripgrep.enable = true;
  programs.fzf.enable = true;
  programs.tmux.enable = true;
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
