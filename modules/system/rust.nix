{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    rustup
    cargo
    rust-analyzer
  ];

  systemd.services.rustup-update = {
    description = "Update Rustup daily";
    wantedBy = ["timers.target"];
    serviceConfig = {
      ExecStart = "${pkgs.rustup}/bin/rustup self update";
      Restart = "on-failure";
    };
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
