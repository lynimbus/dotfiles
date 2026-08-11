{ config, lib, pkgs, ... }:

{
  # ==========================================================================
  # git：本体由 pacman 管理（package = null 只托管配置）。
  #   - delta 已装但一直没用，这里配为默认 pager + diff 渲染
  #   - user.name/email 沿用 jj 里的身份（lynimbus / GitHub noreply）
  #   - 常用安全默认：rebase 拉取、自动 upstream、prune、rerere、zdiff3
  # ==========================================================================
  programs.git = {
    enable = true;
    package = null;    # 保留 pacman git，避免 PATH 上双份

    settings = {
      user = {
        name = "lynimbus";
        email = "128837704+lynimbus@users.noreply.github.com";
      };

      core = {
        pager = "delta";
      };

      # delta：git diff 高亮渲染器
      delta = {
        navigate = true;        # 用 n/N 在 diff 块之间跳转
        line-numbers = true;
        dark = true;            # 终端是深色主题（One Dark），强制深色配色
      };

      interactive.diffFilter = "delta --color-only";   # git add -p 也走 delta

      merge.conflictstyle = "zdiff3";  # 三向冲突带 base 段
      diff.colorMoved = "default";     # 移动的代码块着色
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      fetch.prune = true;
      rerere.enabled = true;
    };

    # 全局忽略（原 config/git/ignore，由 HM 自动写 core.excludesfile）
    ignores = [
      "**/.claude/settings.local.json"
    ];
  };

  # ==========================================================================
  # jujutsu：本体由 Nix 管理；配置声明式化（原手改 ~/.config/jj/config.toml）
  # ==========================================================================
  programs.jujutsu = {
    enable = true;

    settings = {
      ui."default-command" = "log";
      user = {
        name = "lynimbus";
        email = "128837704+lynimbus@users.noreply.github.com";
      };
    };
  };
}
