{ config, pkgs, ... }:

{
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

}
