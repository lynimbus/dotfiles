{ inputs, ... }:

{
  imports = [
    inputs.luciole.homeModules.default
  ];

  programs.luciole = {
    enable = true;
    settings = {
      schema_version = 1;
      browser = {
        view_mode = "list";
        show_preview = true;
        use_ssd = true;
      };
    };
  };
}
