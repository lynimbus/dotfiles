#!/bin/sh
# 背光上调脚本：规避 amdgpu 在顶部亮度（99/100%）的显示异常，
# 封顶 98%，每按一次 +10%；内屏背光不可读时回退 ddcutil 控制外接显示器。
set -u

MAX_PCT=98
STEP_PCT=10

cur=$(brightnessctl get 2>/dev/null || true)
max=$(brightnessctl max 2>/dev/null || true)

if [ -n "$cur" ] && [ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null; then
    cur_pct=$((cur * 100 / max))

    if [ "$cur_pct" -ge "$MAX_PCT" ]; then
        # 当前已在顶部（含异常的 99/100），恢复到安全值 98%
        brightnessctl set "${MAX_PCT}%"
        exit 0
    fi

    target=$((cur_pct + STEP_PCT))
    [ "$target" -gt "$MAX_PCT" ] && target=$MAX_PCT
    brightnessctl set "${target}%"
else
    # 内屏背光不可读，回退 DDC 控制外接显示器
    ddcutil setvcp 10 + 10 || true
fi
