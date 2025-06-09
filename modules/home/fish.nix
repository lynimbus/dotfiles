{
  config,
  pkgs,
  ...
}: {
  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  programs.fish = {
    enable = true;
    shellInit = ''
      set -g fish_greeting
    '';
    shellAliases = {
      sw = "sudo nixos-rebuild switch --flake ~/dotfiles#nixos";
      fastpush = "git add . && git commit && git push";
      error = "journalctl -b -p err";
      v = "nvim";
      vim = "nvim";
      c = "clear";
      cd = "z";
      rsync = "rsync -avhzP";
      rm = "rm -I";
      cp = "cp -irnv";
      mv = "mv -inv";
      bye = "shutdown now";
      la = "ls -lah";
    };
    functions = {
      relpath = {
        body = ''
          if test (count $argv) -ne 1
                   echo "Usage: relpath /path/to/target"
                   return 1
                 end
                 realpath --relative-to=(pwd) $argv[1]
        '';
      };
    };
  };
}
