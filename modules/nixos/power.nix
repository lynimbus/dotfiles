{ ... }:

{
  # 翼龙15Pro (GM5HG0A) 固件怪癖：s2idle 挂起期间 8042 会收到假键盘中断，
  # 上游 spurious_8042 quirk 目前只覆盖同系的 GM5HG7A，本机仍需 workaround。
  # 现象：用内置键盘唤醒时 IRQ1 顺带清掉了控制器状态；用其他方式
  # （电源键/合盖/USB 键鼠）唤醒后 PS/2 键盘留在坏状态，atkbd 不再上报事件。
  # 方案：恢复后强制重新绑定 atkbd = 向键盘发 0xFF 复位指令重同步，
  # 该症状的社区通用解（/sys/bus/serio/drivers/atkbd/ unbind+bind）。
  # serio0 即 i8042 的 PNP0303 键盘口（本机无 PS/2 AUX 口）。
  powerManagement.resumeCommands = ''
    echo -n "serio0" > /sys/bus/serio/drivers/atkbd/unbind 2>/dev/null || true
    echo -n "serio0" > /sys/bus/serio/drivers/atkbd/bind   2>/dev/null || true
  '';

}
