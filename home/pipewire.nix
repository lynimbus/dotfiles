{ pkgs, ... }:
{
  xdg.configFile."pipewire/pipewire.conf.d/99-rnnoise.conf".text = ''
    context.modules = [
      {
        name = libpipewire-module-filter-chain
        args = {
          node.description = "Auto Gain + Noise Cancel Source"
          media.name = "Auto Gain + Noise Cancel Source"

          filter.graph = {
            nodes = [
              {
                type = ladspa
                name = gain_control
                plugin = "${pkgs.ladspaPlugins}/lib/ladspa/dyson_compress_1403.so"
                label = dysonCompress
                control = {
                  "Input Gain" = 2.0
                  "Threshold" = -18.0
                  "Ratio" = 3.0
                  "Attack Time" = 0.02
                  "Release Time" = 0.2
                  "Makeup Gain" = 3.0
                }
              }
              {
                type = ladspa
                name = rnnoise
                plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so"
                label = noise_suppressor_mono
                control = {
                  "VAD Threshold (%)" = 80.0
                  "VAD Grace Period (ms)" = 200
                  "Retroactive VAD Grace (ms)" = 0
                }
              }
            ]
          }

          capture.props = {
            node.name = capture.rnnoise_source
            node.passive = true
            audio.rate = 48000
          }

          playback.props = {
            node.name = rnnoise_source
            media.class = Audio/Source
            audio.rate = 48000
          }
        }
      }
    ]
  '';
}
