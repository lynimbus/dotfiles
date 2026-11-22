{ ... }:

{
  programs.noctalia = {
    enable = true;
    # Home Manager manages and wraps the package in home/desktop/noctalia.
    package = null;
    recommendedServices.enable = true;
  };
}
