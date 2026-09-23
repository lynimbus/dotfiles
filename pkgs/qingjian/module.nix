{ config, lib, pkgs, ... }:

let
  cfg = config.programs.qingjian;
  tomlFormat = pkgs.formats.toml { };
  configFile = tomlFormat.generate "qingjian-config.toml" cfg.settings;
in
{
  options.programs.qingjian = {
    enable = lib.mkEnableOption "青简输入法 server";

    package = lib.mkPackageOption pkgs "qingjian" { };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      example = lib.literalExpression ''
        {
          general.learning_language = "en";
          general.scheme = "xiaohe";
          fuzzy.z_zh = true;
        }
      '';
      description = ''
        青简 config.toml 的内容。分节与键名同上游模板（general / shortcut / fuzzy / apps /
        dictionaries / aux_code / predict / model / update），没写的键由青简自己补默认值。
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."qingjian/config.toml".source = configFile;

    systemd.user.services.qingjian = {
      Unit = {
        Description = "Qingjian input method server";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/qingjian-linux-server";
        Restart = "on-failure";
        # server 只在启动时读配置；把配置文件嵌进单元，配置变化时 sd-switch 自动重启服务
        Environment = "QINGJIAN_CONFIG_FILE=${configFile}";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
