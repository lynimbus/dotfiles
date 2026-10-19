{ sshKey, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        forwardAgent = true;
      };
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = sshKey;
      };
    };
  };
}
