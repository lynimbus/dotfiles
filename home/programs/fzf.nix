{ ... }:

{
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height=60%"
      "--layout=reverse"
      "--border=rounded"
      "--info=inline"
      "--cycle"
      "--bind=ctrl-/:toggle-preview,ctrl-u:preview-page-up,ctrl-d:preview-page-down"
    ];
    fileWidget = {
      command = "fd --type f --hidden --follow --exclude .git";
      options = [ "--preview='bat -n --color=always {}'" ];
    };
    changeDirWidget.command = "fd --type d --hidden --follow --exclude .git";
  };
}
