{ ... }:

{
  # dbus-broker（旧配置沿用，消息总线更快）
  services.dbus.implementation = "broker";

  services.openssh.enable = true;

  hardware.bluetooth.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  services.libinput.enable = true;

}
