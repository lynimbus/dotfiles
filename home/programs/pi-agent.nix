{ pkgs, ... }:

{
  programs.pi-coding-agent = {
    enable = true;
    context = ../pi-agent/AGENTS.md;
    extraPackages = [ pkgs.nodejs ];

    settings = {
      defaultProvider = "sol";
      defaultModel = "gpt-5.6-sol";
      defaultThinkingLevel = "max";
      packages = [
        "npm:pi-web-access"
        "npm:@juicesharp/rpiv-ask-user-question"
        "git:github.com/earendil-works/pi-review"
        {
          source = "git:github.com/shimo4228/search-first";
          skills = [ "+skills/search-first" ];
        }
        {
          source = "git:github.com/mattpocock/skills";
          skills = [
            "+skills/engineering/grill-with-docs"
            "+skills/productivity/grilling"
            "+skills/productivity/wait-what"
          ];
        }
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
      sol = {
        api = "openai-responses";
        baseUrl = "https://api.like-ai.cc/v1";
        models = [
          {
            id = "gpt-5.6-sol";
            name = "GPT-5.6 Sol";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 272000;
            maxTokens = 128000;
            thinkingLevelMap = {
              off = "none";
              minimal = null;
              low = "low";
              medium = "medium";
              high = "high";
              xhigh = "xhigh";
              max = "max";
            };
            compat = {
              supportsStrictMode = true;
              supportsOpenAIGrammarTools = true;
              supportsAdditionalTools = true;
              supportsToolSearch = true;
              supportsMidConvoSystemMessages = true;
              supportsExplicitPromptCacheMode = true;
            };
          }
        ];
      };
      astra = {
        api = "openai-responses";
        baseUrl = "https://api.like-ai.cc/v1";
        models = [
          {
            id = "gpt-6-astra";
            name = "GPT-6 Astra";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            contextWindow = 272000;
            maxTokens = 128000;
            thinkingLevelMap = {
              off = null;
              minimal = null;
              low = "low";
              medium = "medium";
              high = "high";
              xhigh = "xhigh";
              max = "max";
            };
            compat = {
              supportsStrictMode = true;
              supportsOpenAIGrammarTools = true;
              supportsAdditionalTools = true;
              supportsToolSearch = true;
              supportsMidConvoSystemMessages = true;
              supportsExplicitPromptCacheMode = true;
            };
          }
        ];
      };
    };
  };
}
