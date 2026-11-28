{ pkgs, ... }:

{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";

    extraPackages = with pkgs; [
      ouch
      unar
      unrar
      mediainfo
      glow
      ripdrag
      trash-cli
      nushell
    ];

    plugins = with pkgs.yaziPlugins; {
      inherit
        compress
        ouch
        smart-enter
        chmod
        mount
        restore
        git
        mediainfo
        piper
        diff
        drag
        sudo
        ;
    };

    initLua = ''
      require("git"):setup { order = 1500 }
      require("restore"):setup {
        show_confirm = true,
        suppress_success_notification = false,
      }
    '';

    settings = {
      mgr = {
        ratio = [
          1
          3
          4
        ];
        sort_by = "alphabetical";
        sort_sensitive = false;
        sort_dir_first = true;
        linemode = "size";
        show_symlink = true;
      };
      preview = {
        wrap = "yes";
      };
      opener = {
        extract = [
          {
            run = "ya pub extract --list %s";
            desc = "Extract here";
          }
          {
            run = "unar %s";
            desc = "Extract with unar (CJK encoding)";
            for = "unix";
          }
          {
            run = "ouch d -y %s";
            desc = "Extract with ouch";
            for = "unix";
          }
        ];
      };
      plugin = {
        prepend_fetchers = [
          {
            url = "*";
            run = "git";
            group = "git";
          }
          {
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
        prepend_preloaders = [
          {
            mime = "{audio,video,image}/*";
            run = "mediainfo";
          }
          {
            mime = "application/{subrip,postscript,illustrator,dvb.ait,vnd.adobe.illustrator,eps}";
            run = "mediainfo";
          }
          {
            url = "*.{ai,eps,ait}";
            run = "mediainfo";
          }
        ];
        prepend_previewers = [
          {
            mime = "application/{*zip,tar,bzip2,7z*,rar,xz,zstd,java-archive}";
            run = "ouch --show-file-icons";
          }
          {
            mime = "{audio,video,image}/*";
            run = "mediainfo";
          }
          {
            mime = "application/{subrip,postscript,illustrator,dvb.ait,vnd.adobe.illustrator,eps}";
            run = "mediainfo";
          }
          {
            url = "*.{ai,eps,ait}";
            run = "mediainfo";
          }
          {
            url = "*.md";
            run = ''piper -- CLICOLOR_FORCE=1 glow -w=$w -s=dark "$1"'';
          }
        ];
      };
    };

    keymap = {
      mgr.prepend_keymap = [
        {
          on = "l";
          run = "plugin smart-enter";
          desc = "Enter the child directory, or open the file";
        }
        {
          on = "C";
          run = "plugin ouch";
          desc = "Compress selected files with ouch";
        }
        {
          on = [
            "c"
            "a"
            "a"
          ];
          run = "plugin compress";
          desc = "Archive selected files";
        }
        {
          on = [
            "c"
            "a"
            "p"
          ];
          run = "plugin compress -p";
          desc = "Archive selected files (password)";
        }
        {
          on = [
            "c"
            "a"
            "h"
          ];
          run = "plugin compress -ph";
          desc = "Archive selected files (password + header)";
        }
        {
          on = [
            "c"
            "a"
            "l"
          ];
          run = "plugin compress -l";
          desc = "Archive selected files (compression level)";
        }
        {
          on = [
            "c"
            "a"
            "u"
          ];
          run = "plugin compress -phl";
          desc = "Archive selected files (password + header + level)";
        }
        {
          on = [
            "c"
            "m"
          ];
          run = "plugin chmod";
          desc = "Chmod on selected files";
        }
        {
          on = "M";
          run = "plugin mount";
          desc = "Open mount manager";
        }
        {
          on = "u";
          run = "plugin restore";
          desc = "Restore last trashed files/folders";
        }
        {
          on = "U";
          run = "plugin restore -- --interactive";
          desc = "Restore trashed files/folders interactively";
        }
        {
          on = "=";
          run = "plugin diff";
          desc = "Diff selected file with hovered file";
        }
        {
          on = "<C-g>";
          run = "plugin drag";
          desc = "Drag selected files with ripdrag";
        }
        {
          on = "<F3>";
          run = "plugin mediainfo -- toggle-metadata";
          desc = "Toggle media preview metadata";
        }
        {
          on = "<F4>";
          run = "plugin mediainfo -- toggle-preview";
          desc = "Toggle media preview image";
        }
        {
          on = [
            "R"
            "p"
            "p"
          ];
          run = "plugin sudo -- paste";
          desc = "Sudo paste";
        }
        {
          on = [
            "R"
            "P"
          ];
          run = "plugin sudo -- paste --force";
          desc = "Sudo paste (overwrite)";
        }
        {
          on = [
            "R"
            "r"
          ];
          run = "plugin sudo -- rename";
          desc = "Sudo rename/bulk-rename";
        }
        {
          on = [
            "R"
            "p"
            "l"
          ];
          run = "plugin sudo -- link";
          desc = "Sudo symlink (absolute)";
        }
        {
          on = [
            "R"
            "p"
            "r"
          ];
          run = "plugin sudo -- link --relative";
          desc = "Sudo symlink (relative)";
        }
        {
          on = [
            "R"
            "p"
            "L"
          ];
          run = "plugin sudo -- hardlink";
          desc = "Sudo hardlink";
        }
        {
          on = [
            "R"
            "a"
          ];
          run = "plugin sudo -- create";
          desc = "Sudo create";
        }
        {
          on = [
            "R"
            "d"
          ];
          run = "plugin sudo -- remove";
          desc = "Sudo trash";
        }
        {
          on = [
            "R"
            "D"
          ];
          run = "plugin sudo -- remove --permanently";
          desc = "Sudo delete permanently";
        }
        {
          on = [
            "R"
            "m"
          ];
          run = "plugin sudo -- chmod";
          desc = "Sudo chmod";
        }
      ];
    };
  };
}
