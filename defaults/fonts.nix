# Shared fontconfig defaults and CJK alias rules used by both NixOS system
# fontconfig and Home Manager's per-user fontconfig (which Steam's Pressure
# Vessel sandbox reads via 50-user.conf while shadowing /etc/fonts).
{
  defaultFonts = {
    sansSerif = [
      "Noto Sans"
      "Noto Sans CJK SC"
      "Noto Sans CJK TC"
      "Noto Sans CJK JP"
      "DejaVu Sans"
    ];
    serif = [
      "Noto Serif"
      "Noto Serif CJK SC"
      "Noto Serif CJK TC"
      "Noto Serif CJK JP"
      "DejaVu Serif"
    ];
    monospace = [
      "DejaVu Sans Mono"
      "Noto Sans Mono"
      "Noto Sans Mono CJK SC"
      "Noto Sans Mono CJK TC"
      "Noto Sans Mono CJK JP"
    ];
    emoji = [ "Noto Color Emoji" ];
  };

  cjkAliasesXml = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <match target="pattern">
        <test qual="any" name="family"><string>system-ui</string></test>
        <edit name="family" mode="assign" binding="same"><string>sans-serif</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>ui-sans-serif</string></test>
        <edit name="family" mode="assign" binding="same"><string>sans-serif</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>ui-serif</string></test>
        <edit name="family" mode="assign" binding="same"><string>serif</string></edit>
      </match>
      <match target="pattern">
        <test qual="any" name="family"><string>ui-monospace</string></test>
        <edit name="family" mode="assign" binding="same"><string>monospace</string></edit>
      </match>

      <alias>
        <family>Motiva Sans</family>
        <default><family>sans-serif</family></default>
      </alias>
      <alias>
        <family>Microsoft YaHei</family>
        <prefer><family>Noto Sans CJK SC</family></prefer>
      </alias>
      <alias>
        <family>Microsoft YaHei UI</family>
        <prefer><family>Noto Sans CJK SC</family></prefer>
      </alias>
      <alias>
        <family>PingFang SC</family>
        <prefer><family>Noto Sans CJK SC</family></prefer>
      </alias>
      <alias>
        <family>Hiragino Sans GB</family>
        <prefer><family>Noto Sans CJK SC</family></prefer>
      </alias>
      <alias>
        <family>SimHei</family>
        <prefer><family>Noto Sans CJK SC</family></prefer>
      </alias>
      <alias>
        <family>WenQuanYi Zen Hei</family>
        <prefer><family>Noto Sans CJK SC</family></prefer>
      </alias>
      <alias>
        <family>WenQuanYi Micro Hei</family>
        <prefer><family>Noto Sans CJK SC</family></prefer>
      </alias>
      <alias>
        <family>Noto Sans SC</family>
        <prefer><family>Noto Sans CJK SC</family></prefer>
      </alias>
      <alias>
        <family>PingFang TC</family>
        <prefer><family>Noto Sans CJK TC</family></prefer>
      </alias>
      <alias>
        <family>Microsoft JhengHei</family>
        <prefer><family>Noto Sans CJK TC</family></prefer>
      </alias>
      <alias>
        <family>SimSun</family>
        <prefer><family>Noto Serif CJK SC</family></prefer>
      </alias>
      <alias>
        <family>NSimSun</family>
        <prefer><family>Noto Serif CJK SC</family></prefer>
      </alias>
      <alias>
        <family>Songti SC</family>
        <prefer><family>Noto Serif CJK SC</family></prefer>
      </alias>
    </fontconfig>
  '';
}
