{
  config,
  pkgs,
  ...
}: {
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    wqy_zenhei
    maple-mono.NF-CN-unhinted
  ];
}
