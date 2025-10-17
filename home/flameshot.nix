{ ... }:
{
  services.flameshot = {
    enable = true;
    settings = {
      General = {
        uiColor = "#ff78c5";
        disabledTrayIcon = true;
        useGrimAdapter = true;
        showHelp = false;
        showSidePanelButton = false;
        showDesktopNotification = false;
        showAbortNotification = false;
        showStartupLaunchMessage = false;
      };
    };
  };
}
