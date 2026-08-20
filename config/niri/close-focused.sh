#!/usr/bin/env bash
# 关闭当前焦点窗口。
# chromium 走 SIGTERM 优雅退出（写 exit_type=Normal，避免崩溃导致的 Cookie 丢失/恢复页面）；
# 其余应用走 niri 的 close-window。
set -u

appid=$(niri msg -j focused-window 2>/dev/null | jq -r '.app_id // empty')

if [ "$appid" = "chromium" ]; then
    # 只对主进程发 SIGTERM（命令行不含 --type= 的才是主进程），
    # 由主进程统一关闭子进程并正常落盘，避免子进程先死被误判为崩溃。
    for pid in $(pgrep -x chromium); do
        if ! tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q -- '--type='; then
            kill -TERM "$pid"
            exit 0
        fi
    done
    # 找不到主进程则回退到普通关闭
    niri msg action close-window
else
    niri msg action close-window
fi
