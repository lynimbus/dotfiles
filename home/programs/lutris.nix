{ pkgs, ... }:

let
  yaml = pkgs.formats.yaml { };

  # Lutris hardcodes FHS Vulkan ICD paths and omits NixOS's /run/opengl-driver*,
  # which causes selecting a discrete GPU in Lutris to export an empty
  # VK_DRIVER_FILES / VK_ICD_FILENAMES. Patch gpu.py so per-GPU Vulkan ICD
  # filtering and DXVK_FILTER_DEVICE_UUID work properly, and expose the gaming
  # toolchain inside Lutris's FHS sandbox.
  lutrisPkg = pkgs.lutris.override {
    lutris-unwrapped = pkgs.lutris-unwrapped.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace lutris/util/graphics/gpu.py \
          --replace-fail '"/usr/share",' '"/usr/share", "/run/opengl-driver/share", "/run/opengl-driver-32/share",'
      '';
    });
    extraPkgs =
      p: with p; [
        vulkan-tools
        pciutils
        gamemode
        gamescope
        mangohud
        umu-launcher
        wineWow64Packages.stagingFull
        winetricks
      ];
    extraLibraries =
      p: with p; [
        gamemode
        mangohud
      ];
  };
in
{
  home.packages = [ lutrisPkg ];

  # Lutris uses ~/.local/share/lutris as its config dir when ~/.config/lutris
  # does not exist (deprecated upstream). Keep per-game YAML files and pga.db
  # writable while declaring global system and Wine runner defaults here.
  xdg.dataFile."lutris/system.yml".source = yaml.generate "lutris-system.yml" {
    system = {
      gpu = "card0";
      gamemode = true;
      disable_runtime = false;
      prefer_system_libs = true;
      env = {
        # Run Proton/Wine directly on Wayland (winewayland.drv) instead of XWayland.
        # Set here because Lutris's is_winewayland_available() only inspects its own
        # runners/wine dir and misses Steam compatibilitytools.d Proton installs.
        PROTON_ENABLE_WAYLAND = "1";
        PROTON_NO_WM_DECORATION = "1";
        PROTON_HIDE_APU = "1";
        PROTON_LOCAL_SHADER_CACHE = "1";
        PROTON_DXVK_LOWLATENCY = "1";
        # Raise NVIDIA shader disk cache from 1 GiB default to 10 GiB to prevent eviction,
        # and read across numbered Wine helper slots (explorer.exe/xalia.exe/game.exe) so
        # process startup order or Wayland/XWayland changes never miss compiled shaders.
        __GL_SHADER_DISK_CACHE_APP_NAME = "steamapp_shader_cache";
        __GL_SHADER_DISK_CACHE_READ_ONLY_APP_NAME = "steamapp_shader_cache0;steamapp_shader_cache1;steamapp_shader_cache2;steamapp_shader_cache3;steamapp_merged_shader_cache";
        __GL_SHADER_DISK_CACHE_SIZE = "10737418240";
        __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
        __GL_THREADED_OPTIMIZATIONS = "1";
      };
    };
  };

  xdg.dataFile."lutris/runners/wine.yml".source = yaml.generate "lutris-wine.yml" {
    wine = {
      version = "Proton-CachyOS Latest-x86_64_v3";
      Graphics = "wayland";
      dxvk = true;
      vkd3d = true;
      dxvk_nvapi = true;
      d3d_extras = true;
      esync = true;
      fsync = true;
      show_debug = "-all";
    };
  };
}
