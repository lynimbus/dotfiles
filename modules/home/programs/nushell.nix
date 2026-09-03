{ ... }:

{
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

}
