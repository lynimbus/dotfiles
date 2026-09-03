{ pkgs, ... }:

{
  # Home Manager 的 pi 模块声明式生成 settings.json、models.json 和 AGENTS.md。
  # auth.json、models-store.json、sessions/ 与 npm/node_modules/ 保持为本地可写状态。
  programs.pi-coding-agent = {
    enable = true;
    context = ../../../home/pi-agent/AGENTS.md;
    # settings.packages 的 npm:* 启动时 spawn npm；pi 默认包装器 PATH 不含 nodejs。
    extraPackages = [ pkgs.nodejs ];

    settings = {
      defaultProvider = "lxiic";
      defaultModel = "claude-opus-5-max";
      defaultThinkingLevel = "max";
      hideThinkingBlock = false;
      theme = "dark";
      quietStartup = false;
      collapseChangelog = true;
      enableInstallTelemetry = false;
      defaultProjectTrust = "ask";
      compaction = {
        enabled = true;
        reserveTokens = 32768;
        keepRecentTokens = 50000;
      };
      branchSummary = {
        reserveTokens = 32768;
        skipPrompt = false;
      };
      retry = {
        enabled = true;
        maxRetries = 3;
        baseDelayMs = 2000;
        provider = {
          timeoutMs = 3600000;
          maxRetries = 0;
          maxRetryDelayMs = 60000;
        };
      };
      steeringMode = "one-at-a-time";
      followUpMode = "one-at-a-time";
      transport = "auto";
      httpIdleTimeoutMs = 300000;
      websocketConnectTimeoutMs = 15000;
      terminal = {
        showImages = true;
        imageWidthCells = 60;
        clearOnShrink = true;
        showTerminalProgress = true;
      };
      images = {
        autoResize = true;
        blockImages = false;
      };
      markdown = {
        codeBlockIndent = "  ";
        mermaid = "final";
      };
      enableSkillCommands = true;
      warnings.anthropicExtraUsage = false;
      packages = [
        "npm:pi-web-access"
        "npm:@juicesharp/rpiv-ask-user-question"
      ];
      tuiMode = "regular";
      doubleEscapeAction = "tree";
      treeFilterMode = "all";
      fullscreenScrollbar = "auto";
      fullscreenExitOutput = "resume-hint";
      showCacheMissNotices = false;
      showHardwareCursor = true;
    };

    models.providers = {
      lxiid = {
        api = "openai-completions";
        baseUrl = "https://sub2.lxii.cc/v1";
        models = [
          {
            id = "deepseek-v4-flash";
            name = "DeepSeek V4 Flash";
            reasoning = true;
            input = [ "text" ];
            thinkingLevelMap.max = "max";
            contextWindow = 1000000;
            maxTokens = 384000;
            compat = {
              supportsStore = false;
              supportsDeveloperRole = false;
              supportsReasoningEffort = true;
              maxTokensField = "max_tokens";
              requiresReasoningContentOnAssistantMessages = true;
              thinkingFormat = "deepseek";
            };
          }
        ];
      };
      lxiic = {
        api = "anthropic-messages";
        baseUrl = "https://sub2.lxii.cc";
        models = [
          {
            id = "claude-opus-5-max";
            name = "Claude Opus 5 Max";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            thinkingLevelMap.max = "max";
            compat.forceAdaptiveThinking = true;
            contextWindow = 1000000;
            maxTokens = 128000;
          }
        ];
      };
    };
  };

  # 静态资源由 Home Manager 链接到 store；运行时可写状态见下方 activation。
  home.file = {
    ".pi/agent/extensions".source = ../../../home/pi-agent/extensions;
    ".pi/agent/skills".source = ../../../home/pi-agent/skills;
  };
}
