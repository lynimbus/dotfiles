{ pkgs, ... }:

{
  # The video stack is libmpv: Haruna (home/packages.nix) is a GUI in front of
  # it, and this module configures the `mpv` command itself. Haruna keeps its
  # own playback settings in harunarc, so it is tuned from its settings dialog.
  programs.mpv = {
    enable = true;

    config = {
      # gpu-next is the current renderer (better HDR and Vulkan paths), and
      # auto-safe keeps decoding on the GPU only where the driver actually
      # offers a working path, falling back to software instead of failing.
      vo = "gpu-next";
      hwdec = "auto-safe";
      profile = "gpu-hq";

      # Resume where a file stopped instead of restarting it.
      save-position-on-quit = true;

      # Pick up sidecar audio/subtitle files next to the video, and prefer
      # Chinese, then Japanese, then English tracks (`chi` is the ISO 639-2
      # spelling the same tracks carry in older containers).
      sub-auto = "fuzzy";
      audio-file-auto = "fuzzy";
      alang = "zh,chi,ja,en";
      slang = "zh,chi,en";
    };

    # Vim-style seeking. `g` (a chord prefix in mpv), `j`/`J` (subtitle
    # cycling) and `G` (subtitle size) keep their stock meaning; `l` gives up
    # ab-loop, which moves to `a` where nothing else lives.
    bindings = {
      h = "seek -5";
      l = "seek 5";
      H = "seek -60";
      a = "ab-loop";
    };
  };

  # mpv's ytdl_hook shells out to yt-dlp; without it on PATH the player refuses
  # streaming URLs instead of playing them. Haruna uses the same hook.
  home.packages = [ pkgs.yt-dlp ];
}
