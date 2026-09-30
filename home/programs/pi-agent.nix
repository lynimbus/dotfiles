{ pkgs, inputs, ... }:

{
  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.pi-coding-agent;
    context = ../pi-agent/AGENTS.md;
    extraPackages = [
      pkgs.nodejs
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.qmd
    ];

    settings = {
      defaultProvider = "chatGPT";
      defaultModel = "gpt-6-sol";
      defaultThinkingLevel = "max";
      defaultTools = [ "+codemode" ];
      theme = "github-dark-pro";
      packages = [
        "npm:pi-compact-tools"
        "npm:pi-web-access"
        "npm:pi-memory"
        "npm:@juicesharp/rpiv-ask-user-question"
        "npm:@bacnh85/pi-init"
        "npm:@inobit/pi-retry"
        {
          source = "git:github.com/shimo4228/search-first";
          skills = [ "skills/search-first" ];
        }
        {
          source = "git:github.com/mattpocock/skills";
          skills = [
            "skills/engineering/grill-with-docs"
            "skills/productivity/grilling"
            "skills/productivity/wait-what"
          ];
        }
      ];
    };

    models.providers = {
      lxii = {
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
            contextWindow = 1000000;
            maxTokens = 384000;
            thinkingLevelMap = {
              off = null;
              minimal = null;
              low = "low";
              medium = null;
              high = "high";
              xhigh = null;
              max = "max";
            };
            compat = {
              supportsStore = false;
              supportsDeveloperRole = false;
              supportsReasoningEffort = true;
              maxTokensField = "max_tokens";
              requiresReasoningContentOnAssistantMessages = true;
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
            contextWindow = 1048576;
            maxTokens = 131072;
            thinkingLevelMap = {
              off = "none";
              minimal = null;
              low = "low";
              medium = null;
              high = "high";
              xhigh = null;
              max = "max";
            };
            compat = {
              supportsStore = false;
              supportsDeveloperRole = false;
              supportsReasoningEffort = true;
              maxTokensField = "max_tokens";
              supportsStrictMode = false;
              requiresReasoningContentOnAssistantMessages = true;
              supportsMidConvoSystemMessages = true;
              supportsMidConvoToolAdditions = true;
            };
          }
        ];
      };
      chatGPT = {
        api = "openai-responses";
        baseUrl = "https://api.like-ai.cc/v1";
        models = [
          {
            id = "gpt-6-sol";
            name = "GPT-6 Sol";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            thinkingLevelMap = {
              off = "none";
              minimal = null;
              low = "low";
              medium = "medium";
              high = "high";
              xhigh = "xhigh";
              max = "max";
            };
            contextWindow = 272000;
            maxTokens = 128000;
            compat = {
              supportsStrictMode = true;
              supportsOpenAIGrammarTools = true;
              supportsAdditionalTools = true;
              supportsToolSearch = true;
              supportsMidConvoSystemMessages = true;
              supportsExplicitPromptCacheMode = true;
            };
          }
          {
            id = "gpt-6-astra";
            name = "GPT-6 Astra";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            thinkingLevelMap = {
              off = null;
              minimal = null;
              low = "low";
              medium = "medium";
              high = "high";
              xhigh = "xhigh";
              max = "max";
            };
            contextWindow = 272000;
            maxTokens = 128000;
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
      claude = {
        api = "anthropic-messages";
        baseUrl = "https://api.like-ai.cc";
        models = [
          {
            id = "claude-opus-5-5";
            name = "Claude Opus 5.5";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            thinkingLevelMap = {
              off = null;
              minimal = null;
              low = "low";
              medium = "medium";
              high = "high";
              xhigh = "xhigh";
              max = "max";
            };
            contextWindow = 1000000;
            maxTokens = 128000;
            compat = {
              supportsMidConvoEffort = true;
              supportsMidConvoSystemMessages = true;
              supportsMidConvoToolChanges = true;
              forceAdaptiveThinking = true;
              supportsTemperature = false;
              supportsStrictTools = true;
            };
          }
        ];
      };
    };
  };
}
