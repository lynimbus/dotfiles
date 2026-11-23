{ pkgs, ... }:

let
  # Three commands, one script: the name it was called as picks the job, so the
  # paths, the prompt and the idempotence rule exist in one place. The data
  # directory is the user's own ($XDG_DATA_HOME/memo), never this repository.
  script = pkgs.writeShellApplication {
    name = "memo";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      gnused
      findutils
      ripgrep
      bat
      pig
      libnotify
    ];
    text = builtins.readFile ./memo.sh;
    meta = {
      description = "Record a stray thought, then let a model group each day's records by theme";
      mainProgram = "memo";
    };
  };

  # writeShellApplication pins nixpkgs' non-interactive bash, which is built
  # without readline. There `read -e` silently degrades to a raw read: the tty
  # erases one byte per Backspace, which mangles a Chinese character, and
  # Ctrl-H is recorded as text instead of deleting. Keep the generated body --
  # its PATH setup and shellcheck -- swap only the shebang for bashInteractive,
  # and expose all three entrypoints on one derivation with pname set for overview.
  memo =
    pkgs.runCommandLocal "memo"
      {
        pname = "memo";
        inherit (script) meta;
      }
      ''
        mkdir -p $out/bin
        {
          printf '#!%s\n' "${pkgs.bashInteractive}/bin/bash"
          tail -n +2 ${script}/bin/memo
        } > $out/bin/memo
        chmod +x $out/bin/memo
        ln -s memo $out/bin/memo-digest
        ln -s memo $out/bin/memo-read
      '';
in
{
  home.packages = [ memo ];

  systemd.user.services.memo-digest = {
    Unit.Description = "Fold each day's memo records into a theme-grouped digest";
    # A broken gateway would otherwise retry every 15 minutes forever. Three
    # tries is enough to ride out the boot race, and the next night's timer run
    # is the real retry.
    Unit.StartLimitIntervalSec = "2h";
    Unit.StartLimitBurst = 3;
    Service = {
      Type = "oneshot";
      ExecStart = "${memo}/bin/memo-digest";
      # The digest talks to the model through magpie, which a fresh boot brings
      # up as a session app. A catch-up run that beats it there fails fast and
      # would otherwise wait a whole day, so it retries instead.
      Restart = "on-failure";
      RestartSec = "15min";
    };
  };

  systemd.user.timers.memo-digest = {
    Unit.Description = "Runs the memo digest once a night";
    Timer = {
      # A digest day runs 04:00 to 03:59, so this fires an hour after the day it
      # covers ends, and a thought written at 2am is on screen by breakfast.
      OnCalendar = "*-*-* 05:00:00";
      # A night the machine was off is caught up on the next run rather than
      # skipped. memo-digest also skips any day whose records have not changed,
      # so the two together cost one sha256sum per quiet day.
      Persistent = true;
      AccuracySec = "1m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
