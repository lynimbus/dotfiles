{
  config,
  inputs,
  pkgs,
  username,
  email,
  ...
}:

{
  imports = [ inputs.deepseek-harness.homeModules.default ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [
    ripgrep
    fzf
    jq
    just
    nvd
    gh
    jjui
    pi-coding-agent
    ungoogled-chromium
    ayugram-desktop
    qq
  ];

  # ghostty / zed-editor 用 home-manager module 托管(能管理各自的配置文件),
  # 不塞进 home.packages。后续想改配置直接写 settings。
  programs.ghostty = {
    enable = true;
  };

  programs.zed-editor = {
    enable = true;
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user.name = username;
      user.email = email;
      ui.default-command = "log";
      ui.editor = "nvim";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = username;
      user.email = email;
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # 默认 shell 是 nushell（登录 shell 在 hosts/flakeos/configuration.nix 的
  # users.users.lynimbus.shell 里设置）。这里的配置由 home-manager 托管：
  # 生成的 ~/.config/nushell/config.nu 是指向 /nix/store 的只读符号链接，
  # 想改配置改这里再部署，别手改那个文件。
  programs.nushell = {
    enable = true;

    # 每项会被拍平成 $env.config.<key> = <value> 追加进 config.nu，
    # 未设置的键沿用 nushell 内置默认值。
    settings = {
      show_banner = false;
      edit_mode = "vi"; # nvim 用户习惯 vi 键位；想换回 emacs 改成 "emacs"
      table.mode = "rounded";
      history.file_format = "sqlite";
      completions.external = {
        enable = true;
        max_results = 200;
      };
    };

    environmentVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    shellAliases = {
      ll = "ls -la";
      la = "ls -a";
      g = "git";
      j = "jj";
    };
  };

  # dsh（DeepSeek Harness）。模块自己把组合后的包加进 home.packages，
  # 不要再往上面的 home.packages 里手写 dsh。
  # 裸 pkgs.dsh 的 defaultBundles 已经是 [ headless web-app ]，base 层总是自动
  # 注入，所以 profile 里只用写各自特有的 bundle。
  # profile key 会被物化为 $DSH_HOME/profiles/nix-<key>，引用时一律走
  # materializedName，不要硬写 "nix-tui" 这种字符串。
  programs.dsh = {
    enable = true;

    profiles = {
      tui.bundles = [ pkgs.dsh.bundles.tui ];
      web.bundles = [ pkgs.dsh.bundles.web-app ];
    };

    defaultProfile = config.programs.dsh.profiles.tui.materializedName;
  };

  services.dsh = {
    enable = true;
    profile = config.programs.dsh.profiles.web.materializedName;
    listenAddress = "127.0.0.1";
    port = 3080;
  };

  # home.file.".config/foo/config.toml".source = ../config/foo.toml;
  # home.file.".bashrc".text = "export EDITOR=vim\n";

  # home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "26.05";
}
