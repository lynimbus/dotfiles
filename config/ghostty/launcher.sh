#!/bin/sh
# Ghostty 启动包装器（由 home-manager 托管）
#
# 问题：Nix 打包的 ghostty 自带 libglvnd，自动发现系统 EGL vendor 驱动失败
# （既不加载 libEGL_mesa 也不加载 libEGL_nvidia），导致：
#   "failed to make GL context current: 创建 EGL 显示失败" -> 窗口无法渲染
# 解决：启动前显式指定 mesa（AMD 核显）的 EGL 实现。
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
exec /home/lynimbus/.nix-profile/bin/ghostty "$@"
