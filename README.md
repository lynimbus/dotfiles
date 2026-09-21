# NixOS 配置与重装恢复指南

这个仓库是主机 `nixos` 和用户 `lynimbus` 的 NixOS、Home Manager 配置。

- 仓库位置必须是 `/home/lynimbus/nixos`
- Git 远端是 `git@github.com:lynimbus/dotfiles.git`
- 系统配置入口是 `flake.nix`
- 当前 `system.stateVersion` 和 `home.stateVersion` 都是 `26.05`，重装时不要因为系统版本变化而修改它们

## 密钥恢复前提

当前 `secrets/pi-auth.json` 同时加密给两把 key：

- 当前系统的 `~/.ssh/id_ed25519`
- 密码管理器中的 recovery key，对应本机路径 `~/.ssh/id_ed25519_recovery`

原来的 SSH 私钥也有一份加密备份，保存在 `secrets/ssh-id_ed25519`，同样由这两把 key 保护。这份备份只用于手工恢复，不声明为 sops-nix secret。新系统必须在系统切换前将它恢复成持久保存的普通文件，再用它访问 GitHub 和解密其他 secret。

对应的 Pi 明文文件是：

```text
~/.pi/agent/auth.json
```

这意味着：

- 新系统可以直接恢复原来的 `~/.ssh/id_ed25519`，也可以从密码管理器导出 recovery 私钥，再手工解密原私钥的备份
- `~/.ssh/id_ed25519` 必须是权限为 `0600` 的持久普通文件，不能指向 `/run/user/<uid>/secrets.d` 中的运行时 secret
- 只有 `.pub` 公钥不够，公钥只能加密，不能解密
- 原来的 SSH 私钥同时用于 GitHub SSH、Jujutsu 签名和 sops-nix 解密
- sops-nix 的非交互服务要求用于自动解密的 SSH 私钥不带口令
- 私钥、age 私钥和任何明文 secret 都不能提交到仓库

## 重装前准备

### 1. 推送配置仓库

先确认新增的密文和配置已经提交并推送到远端。至少要包含：

```text
.sops.yaml
flake.nix
flake.lock
home/init.nix
home/secrets.nix
secrets/pi-auth.json
secrets/ssh-id_ed25519
```

恢复时不要重新生成 `flake.lock`，这样可以尽量还原原来的软件版本。

### 2. 备份 SSH 私钥

把当前私钥通过密码管理器、加密 U 盘或其他安全方式保存到仓库之外：

```fish
mkdir -p /path/to/secure-backup
cp ~/.ssh/id_ed25519 /path/to/secure-backup/id_ed25519
chmod 600 /path/to/secure-backup/id_ed25519
cp ~/.ssh/id_ed25519.pub /path/to/secure-backup/id_ed25519.pub
```

也可以备份下面这些非 Nix 管理的状态：

- `~/.ssh/known_hosts`
- `~/.pi/agent/sessions/`
- `~/.pi/agent/models-store.json`
- 浏览器、密码管理器和其他应用的用户数据
- 如果希望保持这台机器的 SSH 主机身份，备份 `/etc/ssh/ssh_host_*`

不要备份或提交由 sops-nix 生成的明文 `~/.pi/agent/auth.json` 到仓库。它的受控副本是 `secrets/pi-auth.json`。

### 3. 使用密码管理器里的 Ed25519 SSH key

密码管理器中标为 Ed25519 的 key 通常是 SSH key，公钥以 `ssh-ed25519` 开头。只需要导出公钥，不要把私钥发到聊天或提交到仓库。

先把公钥转换成 age recipient：

```fish
set recovery_ssh_pub 'ssh-ed25519 AAAA... comment'
set recovery_age_pub (printf '%s\n' "$recovery_ssh_pub" | ssh-to-age)
echo $recovery_age_pub
```

把输出的 `age1...` 加入 `.sops.yaml`，例如：

```yaml
keys:
  - &lynimbus age1...
  - &recovery age1...

creation_rules:
  - path_regex: secrets/.*
    key_groups:
      - age:
          - *lynimbus
          - *recovery
```

然后用当前系统的 SSH 私钥重新写入密文的 recipient：

```fish
set -lx SOPS_AGE_KEY_CMD "ssh-to-age -private-key -i $HOME/.ssh/id_ed25519"
sops updatekeys secrets/pi-auth.json
sops updatekeys secrets/ssh-id_ed25519
```

仅添加 recovery recipient 就可以让它手工解密 secret。只有 recovery 私钥时，可以临时指定它：

```fish
set -lx SOPS_AGE_KEY_CMD "ssh-to-age -private-key -i $HOME/.ssh/id_ed25519_recovery"
sops -d secrets/pi-auth.json >/dev/null
```

本仓库已经在 `home/secrets.nix` 中配置了备用解密路径：

```nix
sops.age.sshKeyPaths = [
  "${config.home.homeDirectory}/.ssh/id_ed25519"
  "${config.home.homeDirectory}/.ssh/id_ed25519_recovery"
];
```

当前配置会尝试这两把 key，但不会生成或接管它们。只有 recovery 私钥时，必须按下面的步骤手工恢复原 SSH 私钥，不能指望系统切换自动恢复。原私钥已经持久保存且验证可用后，recovery 私钥不需要常驻磁盘。

`ssh-to-age` 和 sops-nix 的非交互解密需要不带口令的 SSH 私钥；密码管理器导出的私钥若带口令，应先在受控环境中准备临时的无口令副本，恢复完成后妥善清理。

## 新系统恢复步骤

### 1. 安装基础 NixOS

使用 NixOS 安装器完成分区、挂载和最小系统安装。本仓库没有 disko 配置，磁盘分区需要手动完成。

尽量使用相同的：

- 主机名：`nixos`
- 用户名：`lynimbus`
- 用户 home：`/home/lynimbus`

### 2. 检查硬件配置

当前 `system/hardware-configuration.nix` 包含本机磁盘 UUID、XFS 根分区、EFI 分区和 AMD CPU 配置。重装时如果重新格式化了分区，UUID 通常会变化，不能直接照用旧文件。

如果在安装器中已经把目标根分区挂载到 `/mnt`，可以生成目标系统的硬件配置：

```fish
sudo nixos-generate-config --root /mnt
```

然后将 `/mnt/etc/nixos/hardware-configuration.nix` 与 `system/hardware-configuration.nix` 对照。系统已经启动后，也可以只打印当前硬件配置：

```fish
sudo nixos-generate-config --show-hardware-config
```

必要时更新 `system/hardware-configuration.nix`，不要覆盖其他模块中的配置。

### 3. 克隆仓库

如果原来的 SSH 私钥已经可用，可以直接使用 SSH 克隆：

```fish
git clone git@github.com:lynimbus/dotfiles.git ~/nixos
cd ~/nixos
```

否则先用 HTTPS 或其他方式把仓库放到 `/home/lynimbus/nixos`，再恢复私钥：

```fish
git clone https://github.com/lynimbus/dotfiles.git ~/nixos
cd ~/nixos
```

### 4. 持久化恢复原 SSH 私钥

以下两种方式任选其一，必须在第一次系统切换前完成。先准备只允许自己访问的目录：

```fish
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

**方式 A：直接恢复原私钥备份。**

```fish
install -m 600 /path/to/secure-backup/id_ed25519 ~/.ssh/id_ed25519
```

**方式 B：使用 recovery 私钥解密仓库中的备份。**

先从密码管理器导出 recovery 私钥：

```fish
install -m 600 /path/to/password-manager/id_ed25519_recovery ~/.ssh/id_ed25519_recovery
```

如果基础系统还没有解密工具，先进入临时工具环境：

```fish
nix shell nixpkgs#sops nixpkgs#ssh-to-age nixpkgs#fish -c fish
```

在仓库根目录执行。先解密到 `~/.ssh` 下由 `mktemp` 创建的私有临时文件，验证私钥有效后再替换目标；解密失败不会覆盖已有私钥，`mv -fT` 也不会沿旧的符号链接写入运行时目录：

```fish
begin
    set -lx SOPS_AGE_KEY_CMD "ssh-to-age -private-key -i $HOME/.ssh/id_ed25519_recovery"
    set restored_key (mktemp "$HOME/.ssh/id_ed25519.restore.XXXXXX")
    if test -n "$restored_key"
        if sops --decrypt --input-type binary --output-type binary secrets/ssh-id_ed25519 > "$restored_key"
            and ssh-keygen -y -P '' -f "$restored_key" >/dev/null
            and chmod 600 "$restored_key"
            and mv -fT "$restored_key" ~/.ssh/id_ed25519
            echo "SSH private key restored"
        else
            rm -f "$restored_key"
            echo "SSH private key restore failed; do not switch" >&2
        end
    end
end
```

无论采用哪种方式，都要确认原私钥是权限为 `0600` 的普通文件，并重新生成公钥：

```fish
test -f ~/.ssh/id_ed25519
and not test -L ~/.ssh/id_ed25519
and test (stat -c %a ~/.ssh/id_ed25519) = 600
and ssh-keygen -y -P '' -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
and chmod 644 ~/.ssh/id_ed25519.pub
and nix run nixpkgs#ssh-to-age -- < ~/.ssh/id_ed25519.pub
```

所有检查必须成功，最后输出的 recipient 必须与 `.sops.yaml` 中的 `&lynimbus` 相同，否则不要执行系统切换。

### 5. 第一次切换系统

如果基础系统已经启用了 flakes：

```fish
sudo nixos-rebuild switch --flake /home/lynimbus/nixos#nixos
```

如果 flakes 尚未启用，可以临时传入实验特性：

```fish
sudo nixos-rebuild switch \
    --flake /home/lynimbus/nixos#nixos \
    --option extra-experimental-features "nix-command flakes"
```

这次切换会完成：

- 安装 NixOS 和 Home Manager 配置
- 安装 `sops`、`age` 和 `ssh-to-age`
- 启用 sops-nix 用户服务
- 用原 SSH 私钥或 recovery 私钥解密 secrets
- 保留已手工恢复的 `~/.ssh/id_ed25519` 普通文件，不将它替换为 secret 链接
- 将 `~/.pi/agent/auth.json` 替换为运行时 secret 的符号链接
- 恢复 Pi、SSH、Jujutsu、Fish、Niri 和桌面配置

### 6. 验证恢复结果

重新登录一次，让 systemd user 环境和 Home Manager 配置完全加载。必要时手动启动 secret 服务：

```fish
systemctl --user daemon-reload
systemctl --user restart sops-nix.service
```

然后只验证文件类型和 JSON 格式，不要把 secret 打印到终端：

```fish
test -f ~/.ssh/id_ed25519
and not test -L ~/.ssh/id_ed25519
and test (stat -c %a ~/.ssh/id_ed25519) = 600
test -L ~/.pi/agent/auth.json
jq -e 'type == "object"' ~/.pi/agent/auth.json >/dev/null
sops -d secrets/pi-auth.json >/dev/null
ssh -T git@github.com
```

## 当前配置中的机器相关项

重装同一台机器通常不需要修改这些内容，但更换硬件或改变路径时要检查：

- `system/hardware-configuration.nix`：磁盘 UUID、文件系统、initrd 模块和 CPU 平台
- `home/desktop/niri/conf/niri-hardware.kdl`：当前写死了 `eDP-1` 和 `2560x1600@240`，外接显示器或换机器时需要调整
- `system/hardware.nix`：包含针对当前笔记本键盘恢复的 `serio0` workaround
- `system/nix.nix`：`programs.nh.flake` 写死为 `/home/lynimbus/nixos`，并使用清华 Nix substituter
- `home/desktop/niri/default.nix` 和 `home/desktop/noctalia/default.nix`：使用 out-of-store symlink，仓库必须位于 `/home/lynimbus/nixos`
- `home/programs/ssh.nix`：GitHub SSH 使用 `~/.ssh/id_ed25519`
- `home/programs/jujutsu.nix`：提交签名使用同一把 SSH 私钥
- `system/users.nix`：创建用户 `lynimbus`，并启用 wheel 免密码 sudo

如果只是更新软件或 Nix 配置，不要重新生成硬件配置，也不要修改两个 `stateVersion`。如果只是恢复同一台机器，保留现有的 `flake.lock`。

## 日常使用

修改普通配置后：

```fish
nh os switch .
```

修改 Pi 认证信息时：

```fish
sops secrets/pi-auth.json
```

`sops-nix` 会在激活时重新生成运行时文件，不要直接编辑 `~/.pi/agent/auth.json`。不要使用 `builtins.readFile`、`writeText` 或环境变量把明文 token 写入 Nix 表达式，否则明文可能进入 `/nix/store`。

## 添加和修改加密内容

### 修改 Pi 的 auth.json

`home/secrets.nix` 使用 `key = ""`，所以 `secrets/pi-auth.json` 解密后会作为完整 JSON 写入 `~/.pi/agent/auth.json`。添加 provider、token 或其他字段时，直接编辑加密文件：

```fish
sops secrets/pi-auth.json
```

编辑器里看到的是临时解密内容；保存并退出后，sops 会自动重新加密。不要使用下面这种方式把明文保存到磁盘：

```fish
sops -d secrets/pi-auth.json > /tmp/auth.json
```

如果当前 shell 还没有 Home Manager 设置的环境变量，先执行：

```fish
set -lx SOPS_AGE_KEY_CMD "ssh-to-age -private-key -i $HOME/.ssh/id_ed25519"
sops secrets/pi-auth.json
```

修改后可以只验证 JSON 有效，不打印内容：

```fish
sops -d secrets/pi-auth.json >/dev/null
```

### 添加独立的 secret 文件

`.sops.yaml` 会给 `secrets/` 目录下的文件统一加密。因此可以直接创建新的 JSON、YAML、dotenv 或 INI 文件：

```fish
sops secrets/my-service.json
```

例如编辑为：

```json
{
  "token": "<new-secret>",
  "privateKey": "<private-key>"
}
```

保存后提交 `secrets/my-service.json`。仓库中只会出现密文。

如果应用需要通过文件读取这个 secret，需要在 `home/secrets.nix` 中声明它：

```nix
sops.secrets."my-service" = {
  sopsFile = ../secrets/my-service.json;
  format = "json";
  key = "";
  path = "${config.home.homeDirectory}/.config/my-service/secret.json";
  mode = "0600";
};
```

`key = ""` 表示输出整个 JSON 文件；如果只需要顶层的 `token` 字段，可以写 `key = "token"`。嵌套字段使用 `/`，例如 `key = "service/token"`。

如果 secret 只应该在运行时存在，可以使用运行时路径：

```nix
path = "%r/my-service-token";
```

添加新的 Nix 配置后执行：

```fish
nh os switch .
```

加密文件必须放在 `secrets/` 下并纳入 Git/jj 版本控制。不要把私钥、age 私钥或解密后的临时文件放进仓库。

### 新增 recipient 或轮换密钥

修改 `.sops.yaml` 后，需要为已有的每个加密文件更新 recipient，包括用于手工恢复的私钥备份：

```fish
sops updatekeys secrets/pi-auth.json
sops updatekeys secrets/ssh-id_ed25519
```

更新 recipient 不会更新备份中的私钥内容。轮换原 SSH 私钥时，还需要重新加密并验证 `secrets/ssh-id_ed25519`，确认新备份能恢复正确的 SSH 身份后再移除旧密钥。


## 无法解密时的处理顺序

1. 确认仓库中的 `.sops.yaml` 和 `secrets/pi-auth.json` 没有被替换。
2. 确认当前使用的是原来的 `~/.ssh/id_ed25519`，而不是新生成的同名密钥。
3. 检查私钥是否为权限 `0600` 的持久普通文件；若它是指向运行时 secret 的链接，删除 Nix 声明本身不会将其恢复为普通文件。
4. 用 `ssh-keygen -y` 重新生成公钥，再用 `ssh-to-age` 检查 recipient。
5. 如果旧私钥丢失或链接失效，按“持久化恢复原 SSH 私钥”一节从备份或 recovery 私钥手工恢复。不要直接向失效链接重定向解密输出。
6. 本配置禁止将 `sops.age.sshKeyPaths` 中的路径同时作为 `sops.secrets.*.path`；先修正配置并恢复持久私钥，再执行系统切换和重启 `sops-nix.service`。
7. 如果两把解密私钥都丢失，撤销旧的 API token，生成新的 `auth.json`，再用新 recipient 重新加密。
