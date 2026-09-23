{ pkgs, ... }:

let
  zedWithPiAuth = pkgs.symlinkJoin {
    name = "zed-editor-with-pi-auth";
    paths = [ pkgs.zed-editor ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/zed" \
        --run '
          auth="$HOME/.pi/agent/auth.json"
          if [ -r "$auth" ] && ${pkgs.jq}/bin/jq -e type "$auth" >/dev/null 2>&1; then
            read_key() {
              ${pkgs.jq}/bin/jq -r ".$1.key // empty" "$auth"
            }
            export SOL_API_KEY="''${SOL_API_KEY:-$(read_key sol)}"
            export ASTRA_API_KEY="''${ASTRA_API_KEY:-$(read_key astra)}"
            export LXII_API_KEY="''${LXII_API_KEY:-$(read_key lxii)}"
          fi
        '
    '';
    meta = pkgs.zed-editor.meta;
  };

  solModel = {
    provider = "sol";
    model = "gpt-5.6-sol";
    enable_thinking = true;
    effort = "max";
  };
  astraModel = {
    provider = "astra";
    model = "gpt-6-astra";
    enable_thinking = true;
    effort = "max";
  };
  deepseekModel = {
    provider = "lxii";
    model = "deepseek-v4.1-flash";
    enable_thinking = true;
    effort = "max";
  };
  kimiModel = {
    provider = "lxii";
    model = "kimi-k3";
    enable_thinking = true;
    effort = "max";
  };
  openAiCompatibleCapabilities = {
    tools = true;
    images = true;
    parallel_tool_calls = false;
    prompt_cache_key = false;
    chat_completions = false;
    interleaved_reasoning = false;
    max_tokens_parameter = false;
  };
  chatCompletionsCapabilities = openAiCompatibleCapabilities // {
    chat_completions = true;
    interleaved_reasoning = true;
    max_tokens_parameter = true;
  };
in
{
  programs.zed-editor = {
    enable = true;
    package = zedWithPiAuth;
    userSettings = {
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      vim_mode = true;
      ui_locale = "zh-CN";
      ui_font_size = 16;
      buffer_font_size = 16;
      buffer_font_family = "Intel One Mono";
      buffer_font_fallbacks = [
        "Maple Mono NF CN"
        "Noto Sans CJK SC"
      ];
      theme = {
        mode = "dark";
        light = "One Light";
        dark = "One Dark";
      };
      remove_trailing_whitespace_on_save = false;
      ensure_final_newline_on_save = true;
      agent = {
        default_model = solModel;
        subagent_model = solModel;
        inline_assistant_model = solModel;
        commit_message_model = solModel;
        thread_summary_model = solModel;
        compaction_model = solModel;
        inline_assistant_use_streaming_tools = true;
        favorite_models = [
          solModel
          astraModel
          deepseekModel
          kimiModel
        ];
      };
      language_models = {
        openai_compatible = {
          sol = {
            api_url = "https://api.like-ai.cc/v1";
            available_models = [
              {
                name = "gpt-5.6-sol";
                display_name = "GPT-5.6 Sol";
                max_tokens = 272000;
                max_output_tokens = 128000;
                reasoning_effort = "max";
                capabilities = openAiCompatibleCapabilities;
              }
            ];
          };
          astra = {
            api_url = "https://api.like-ai.cc/v1";
            available_models = [
              {
                name = "gpt-6-astra";
                display_name = "GPT-6 Astra";
                max_tokens = 272000;
                max_output_tokens = 128000;
                reasoning_effort = "max";
                capabilities = openAiCompatibleCapabilities;
              }
            ];
          };
          lxii = {
            api_url = "https://sub2.lxii.cc/v1";
            available_models = [
              {
                name = "deepseek-v4.1-flash";
                display_name = "DeepSeek V4.1 Flash";
                max_tokens = 1000000;
                max_output_tokens = 384000;
                reasoning_effort = "max";
                capabilities = chatCompletionsCapabilities;
              }
              {
                name = "kimi-k3";
                display_name = "Kimi K3";
                max_tokens = 1048576;
                max_output_tokens = 131072;
                reasoning_effort = "max";
                capabilities = chatCompletionsCapabilities;
              }
            ];
          };
        };
      };
    };
  };
}
