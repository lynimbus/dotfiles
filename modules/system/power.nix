{
  config,
  pkgs,
  ...
}: {
  services.power-profiles-daemon.enable = false;
  powerManagement.enable = true;
  services.thermald.enable = true;
  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "powersave";
        turbo = "never";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };
}
