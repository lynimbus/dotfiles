{ pkgs, ... }:

{
  programs.pi-coding-agent = {
    enable = true;
    context = ../pi-agent/AGENTS.md;
    extraPackages = [ pkgs.nodejs ];

    settings = {
      defaultProvider = "deepseek";
      defaultModel = "deepseek-flash";
      defaultThinkingLevel = "max";
      packages = [
        "npm:pi-web-access"
        "npm:@juicesharp/rpiv-ask-user-question"
      ];
    };

    models.providers = {
      lxiid = {
        api = "openai-completions";
        baseUrl = "https://sub2.lxii.cc/v1";
        models = [
          {
            id = "deepseek-v4.1-flash";
            name = "DeepSeek V4.1 Flash";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
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
          {
            id = "kimi-k3";
            name = "Kimi K3";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            thinkingLevelMap.max = "max";
            contextWindow = 1048576;
            maxTokens = 131072;
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
}
