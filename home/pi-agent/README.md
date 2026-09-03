# pi coding agent 配置管理

本目录由 NixOS + home-manager 统一管理 `~/.pi/agent`。包与 `settings.json` / `models.json` / `AGENTS.md` 走官方 Home Manager 模块 `programs.pi-coding-agent`（定义在 `modules/home/tools/pi-agent.nix`）。

## 文件组织

- **声明式配置**（`modules/home/tools/pi-agent.nix`）：
  - `programs.pi-coding-agent.settings` → `~/.pi/agent/settings.json`
  - `programs.pi-coding-agent.models` → `~/.pi/agent/models.json`
  - `programs.pi-coding-agent.context` → `~/.pi/agent/AGENTS.md`
  - `home.file` → `APPEND_SYSTEM.md`、`agent-tool-description.md`、`agents/`、`extensions/`、`skills/`、`npm/package.json` 与 `subagents.json`
  - 部署后这些是指向 `/nix/store` 的只读符号链接；在 TUI 中修改它们不会写回，要改仓库源文件再 `just switch`

- **可变状态**（`home/pi-agent-state/`）：`trust.json`
  - `home.activation` 仅在文件缺失时复制默认值，之后保留普通可写文件
  - 用 `just pi-sync` 同步运行时状态回仓库

## 工作流

### 改 settings / models / 默认模型

编辑 `modules/home/tools/pi-agent.nix` 里的 `programs.pi-coding-agent`，然后 `just check` → `just switch`。

### 修改静态资源（指令、agent、扩展、skills、依赖声明）

```bash
vim home/pi-agent/AGENTS.md
vim home/pi-agent/extensions/my-extension.ts
vim home/pi-agent/skills/my-skill/SKILL.md
just switch
```

`subagents.json` 是 `pi-subagents` 的全局只读默认配置，直接编辑 `home/pi-agent-state/subagents.json` 后部署。

### 同步运行时状态

```bash
just pi-sync          # 同步 trust.json
```

## 文件分类

| 类别 | 文件 | 托管方式 |
|---|---|---|
| 用户设置 | `settings.json` | `programs.pi-coding-agent.settings`（只读） |
| 自定义模型 | `models.json` | `programs.pi-coding-agent.models`（只读） |
| 静态指令 | `AGENTS.md`、`APPEND_SYSTEM.md`、`agent-tool-description.md` | `programs.pi-coding-agent.context` / `home.file`（只读） |
| 自定义 agent | `agents/*.md` | `home.file`（只读） |
| 扩展插件 | `extensions/*.{ts,json}` | `home.file`（只读） |
| Skills | `skills/**` | `home.file`（只读） |
| 依赖声明 | `npm/package.json` | `home.file`（只读） |
| 子代理默认设置 | `subagents.json` | `home.file`（只读） |
| 项目信任记录 | `trust.json` | activation 首次初始化，后续可写 |
| 敏感凭据 | `auth.json` | 本地保留（不进版本控制） |
| 运行时缓存 | `sessions/`, `npm/node_modules/`, `models-store.json` | 本地保留（不托管） |
