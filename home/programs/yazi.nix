{ ... }:

{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";

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
    };
  };
}
