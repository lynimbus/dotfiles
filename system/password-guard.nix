{
  config,
  lib,
  username,
  ...
}:

let
  hashFile = config.users.users.${username}.hashedPasswordFile;
in

{
  # update-users-groups.pl 只会为「/etc/shadow 里还不存在的用户」去读
  # hashedPassword / hashedPasswordFile；文件缺失时它仅 warn 一句，然后照默认
  # 值 "!" 写入 shadow —— 账户就此锁死，现象是能出登录提示符但密码一律认证失败。
  #
  # 平时这个坑不会露头：mutableUsers 默认 true，已存在的 shadow 行被原样保留，
  # 那条断掉的 hashedPasswordFile 永远轮不到生效。一旦 /etc 换成 overlay、
  # 上层是全新空目录，用户行就得重建，问题立刻显形（实测踩过）。
  #
  # 注意激活脚本的环境：PATH 在 /empty 之上只加了 coreutils、grep、findutils、
  # getent、glibc、shadow、util-linux，没有 awk。这里只用 shell 内建和参数
  # 展开，否则一句 "awk: command not found" 就会被 ERR trap 记成激活失败。
  system.activationScripts.password-hash-guard = lib.mkIf (hashFile != null) {
    deps = [ "specialfs" ];
    text = ''
      pwg_file=${toString hashFile}
      pwg_user=${username}

      pwg_warn() {
        echo "password-hash-guard: $*" >&2
      }

      # 取 /etc/shadow 里该用户的密码字段，纯 shell 解析。
      pwg_shadow_field() {
        pwg_field=""
        if [ -f /etc/shadow ]; then
          while IFS=: read -r pwg_name pwg_rest; do
            if [ "$pwg_name" = "$pwg_user" ]; then
              pwg_field=''${pwg_rest%%:*}
              break
            fi
          done < /etc/shadow
        fi
      }

      if [ ! -e "$pwg_file" ]; then
        pwg_shadow_field
        case "$pwg_field" in
          "" | "!" | "!!" | "*")
            pwg_warn "$pwg_file 不存在，/etc/shadow 里也没有 '$pwg_user' 的可用 hash。"
            pwg_warn "照这样往下走，update-users-groups.pl 会把密码字段写成 '!'，账户锁死、登录进不来。"
            pwg_warn "先 sudo passwd $pwg_user 交互设一次密码，下次激活会自动把它补写进那个文件。"
            false
            ;;
          *)
            ( umask 077; printf '%s\n' "$pwg_field" > "$pwg_file" )
            echo "password-hash-guard: 已用 /etc/shadow 里现成的 hash 补写 $pwg_file"
            ;;
        esac
      fi

      # 文件在了，但 /etc/shadow 里那行可能已经是 '!'（上一次被锁留下的）。
      # mutableUsers 原样保留旧行，补文件不会自动救回来，所以要喊一声。
      pwg_shadow_field
      case "$pwg_field" in
        "!" | "!!" | "*")
          pwg_warn "/etc/shadow 里 '$pwg_user' 的密码字段是 '$pwg_field'，账户是锁的，输密码会一直失败。"
          pwg_warn "mutableUsers 会原样保留这一行，补文件救不回来。修法：sudo passwd $pwg_user"
          ;;
      esac
    '';
  };

  # 必须排在 users（即 update-users-groups.pl）之前，否则补写的文件赶不上这次激活。
  system.activationScripts.users.deps = lib.mkIf (
    !config.systemd.sysusers.enable && !config.services.userborn.enable
  ) (lib.mkAfter [ "password-hash-guard" ]);
}
