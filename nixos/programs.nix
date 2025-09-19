{ ... }:
{
  programs.fish.enable = true;

  programs.firefox.enable = true;

  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  security.polkit.enable = true;
}
