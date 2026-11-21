{ pkgs, ... }:

let
  hyMtServer = pkgs.writeShellApplication {
    name = "hy-mt2-server";
    runtimeInputs = with pkgs; [
      findutils
      llama-cpp-vulkan
    ];
    text = ''
      cache_home="''${XDG_CACHE_HOME:-$HOME/.cache}"
      extra_args=()

      # Once the GGUF is cached locally (HF hub cache or llama.cpp cache), force
      # offline mode so startup does not block or fail when offline.
      if [ -n "$(find "$cache_home/huggingface/hub/models--tencent--Hy-MT2-1.8B-GGUF" "$cache_home/llama.cpp" -name '*Hy-MT2-1.8B*Q8_0*.gguf' -print -quit 2>/dev/null || true)" ]; then
        extra_args+=(--offline)
      fi

      exec llama-server \
        -hf tencent/Hy-MT2-1.8B-GGUF:Q8_0 \
        --jinja \
        --host 127.0.0.1 \
        --port 11435 \
        --device Vulkan0 \
        --flash-attn on \
        -ctk q8_0 \
        -ctv q8_0 \
        --parallel 2 \
        -c 4096 \
        -ngl 99 \
        --cache-prompt \
        --alias hy-mt2-1.8b \
        "''${extra_args[@]}"
    '';
    meta = {
      description = "Local llama.cpp OpenAI-compatible server for tencent/Hy-MT2-1.8B";
      mainProgram = "hy-mt2-server";
    };
  };
in
{
  home.packages = [
    pkgs.llama-cpp-vulkan
    hyMtServer
  ];

  systemd.user.services.hy-mt2-server = {
    Unit = {
      Description = "Local Hy-MT2-1.8B translation server (llama.cpp Vulkan)";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${hyMtServer}/bin/hy-mt2-server";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
