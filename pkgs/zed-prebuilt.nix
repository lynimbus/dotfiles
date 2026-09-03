# zed-editor 官方预编译版（zed-linux-x86_64.tar.gz），不做源码编译——
# 一次 release 从源码编译要 1 小时起步（22G 内存还需砍 debuginfo 防 OOM），
# 而官方二进制实测（2026-08-28）已无启动/关闭延迟。
# 升级：改下方 ver / zipHash 为新 GitHub release → just switch。
# 关键坑：官方版运行时 dlopen 探测 wayland/EGL/gbm/drm/xkbcommon/xrandr/va 一套
# 图形库，NixOS 没有 ldconfig 会直接 panic（NoWaylandLib）。解法是用
# autoPatchelfHook 的 runtimeDependencies 把这些库写进最终 RPATH（注意 postFixup
# 手动 add-rpath 会被 autoPatchelf 重写覆盖，不可用）。
{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  libgcc,
  alsa-lib,
  glib,
  wayland,
  libxkbcommon,
  libdrm,
  libglvnd,
  mesa,
  libxrandr,
  libva,
}:

let
  # 官方 GitHub release 的版本与 hash
  ver = "1.18.0";
  zipHash = "sha256-G1Jl0/eXyv6zPi7Tywog9eGXogTpCEidZDGgm6JqNPc=";
in
stdenv.mkDerivation {
  pname = "zed-prebuilt";
  version = ver;

  src = fetchzip {
    url = "https://github.com/zed-industries/zed/releases/download/v${ver}/zed-linux-x86_64.tar.gz";
    hash = zipHash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    libgcc
    alsa-lib
    glib
    wayland
    libxkbcommon
    libdrm
    libglvnd
    mesa
    libxrandr
    libva
  ];

  runtimeDependencies = [
    glib
    wayland
    libxkbcommon
    libdrm
    libglvnd
    mesa
    libxrandr
    libva
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    if [ -d zed-linux-x86_64 ]; then
      cp -r zed-linux-x86_64/. "$out/"
    else
      cp -r . "$out/"
    fi
    # 兼容旧 nixpkgs 命名（bin/zeditor），防止脚本/别名还引用 zeditor
    ln -s "$out/bin/zed" "$out/bin/zeditor"
    runHook postInstall
  '';

  meta = {
    # home-manager programs.zed-editor 用 mainProgram 拼 EDITOR/VISUAL
    mainProgram = "zed";
    description = "Zed editor (official prebuilt v${ver})";
    homepage = "https://zed.dev";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
