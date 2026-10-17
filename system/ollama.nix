{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    host = "127.0.0.1";
    port = 11434;
    loadModels = [ "kev:4b-q4_K_M" ];
    syncModels = true;
    environmentVariables = {
      OLLAMA_VULKAN = "1";
      OLLAMA_KEEP_ALIVE = "30m";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_CONTEXT_LENGTH = "8192";
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NO_CLOUD = "1";
    };
  };

  systemd.services.ollama.serviceConfig.DeviceAllow = [
    "char-drm"
    "char-nvidia"
    "char-nvidiactl"
    "char-nvidia-uvm"
    "char-nvidia-caps"
    "char-nvidia-modeset"
  ];
}
