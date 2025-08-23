{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;

    plugins = with pkgs.yaziPlugins; {
      inherit
        nord
        yatline
        full-border
        smart-enter
        ouch
        jump-to-char
        bypass
        ;
    };

    flavors = { inherit (pkgs.yaziPlugins) nord; };

    theme.flavor = {
      light = "nord";
      dark = "nord";
    };

    initLua = ''
      require("yatline"):setup({
        theme = require("nord"):setup(),
      })
      require("full-border"):setup()
    '';

    keymap = {
      mgr.prepend_keymap = [
        {
          on = [ "h" ];
          run = "plugin bypass reverse";
        }
        {
          on = [ "<Left>" ];
          run = "plugin bypass reverse";
        }
        {
          on = [ "l" ];
          run = "plugin bypass smart-enter";
        }
        {
          on = [ "<Enter>" ];
          run = "plugin bypass smart-enter";
        }
        {
          on = [ "<Right>" ];
          run = "plugin bypass smart-enter";
        }
        {
          on = [ "C" ];
          run = "plugin ouch";
        }
        {
          on = [ "f" ];
          run = "plugin jump-to-char";
        }
      ];
    };
    settings = {
      plugin = {
        prepend_previewers = [
          {
            mime = "application/*zip";
            run = "ouch";
          }
          {
            mime = "application/x-tar";
            run = "ouch";
          }
          {
            mime = "application/x-bzip2";
            run = "ouch";
          }
          {
            mime = "application/x-7z-compressed";
            run = "ouch";
          }
          {
            mime = "application/x-rar";
            run = "ouch";
          }
          {
            mime = "application/vnd.rar";
            run = "ouch";
          }
          {
            mime = "application/x-xz";
            run = "ouch";
          }
          {
            mime = "application/xz";
            run = "ouch";
          }
          {
            mime = "application/x-zstd";
            run = "ouch";
          }
          {
            mime = "application/zstd";
            run = "ouch";
          }
          {
            mime = "application/java-archive";
            run = "ouch";
          }
        ];
      };
    };
  };
}
