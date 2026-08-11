# Fish 配置 ~/.config/fish/config.fish
# 非交互内容在外,交互内容在 is-interactive 块内

# ---------- 环境变量(所有模式生效) ----------
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_CACHE_HOME  $HOME/.cache
set -gx XDG_DATA_HOME   $HOME/.local/share
set -gx XDG_STATE_HOME  $HOME/.local/state

# 编辑器:nvim 优先,vim 兜底
if command -q nvim
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -gx MANPAGER 'nvim +Man!'
else if command -q vim
    set -gx EDITOR vim
    set -gx VISUAL vim
end

set -gx LESS '-RFiMx4'
set -gx LESSHISTFILE -

# 缓存归位到 XDG,不污染 $HOME
set -gx PYTHONPYCACHEPREFIX $XDG_CACHE_HOME/python
set -gx NPM_CONFIG_CACHE $XDG_CACHE_HOME/npm
set -gx CARGO_HOME $XDG_DATA_HOME/cargo
set -gx RUSTUP_HOME $XDG_DATA_HOME/rustup

# PATH:fish_add_path 去重、只加存在的目录
for d in $HOME/.local/bin $HOME/bin $CARGO_HOME/bin $HOME/.bun/bin $HOME/go/bin
    test -d $d; and fish_add_path -g $d
end

# ---------- 仅交互式 ----------
status is-interactive; or return

set -g fish_greeting
set -g fish_sequence_key_delay_ms 200    # Escape 等组合键响应更快

# man 高亮
set -gx LESS_TERMCAP_md (printf '\e[1;36m')    # 粗体=青
set -gx LESS_TERMCAP_me (printf '\e[0m')
set -gx LESS_TERMCAP_us (printf '\e[4;32m')    # 下划线=绿
set -gx LESS_TERMCAP_ue (printf '\e[0m')
set -gx LESS_TERMCAP_so (printf '\e[1;44;33m')
set -gx LESS_TERMCAP_se (printf '\e[0m')

# ---------- ls/cat 替代(包已由 home.nix 声明式安装,无需再判断) ----------
alias ls 'eza --group-directories-first --icons=auto'
alias ll 'eza -l --group-directories-first --icons=auto --git --time-style=long-iso'
alias la 'eza -la --group-directories-first --icons=auto --git --time-style=long-iso'
alias lt 'eza --tree --level=2 --icons=auto'

set -gx BAT_THEME ansi
alias b 'bat --paging=never'    # cat 不换 bat,避免管道/复制出错

alias ip 'ip -color=auto'
alias rm 'rm -I --preserve-root'
alias cp 'cp -i'
alias mv 'mv -i'
alias mkdir 'mkdir -p'
alias df 'df -h'
alias du 'du -h'
alias free 'free -h'

# ---------- abbr:敲空格即展开 ----------
# 目录
abbr -a -- - 'cd -'
# 注:.. 不需要定义,fish 隐式 cd 会把裸 .. 当作目录直接进入
abbr -a ... 'cd ../..'
abbr -a .... 'cd ../../..'

# git
abbr -a g git
abbr -a gs 'git status -sb'
abbr -a ga 'git add'
abbr -a gaa 'git add --all'
abbr -a gc 'git commit -v'
abbr -a gca 'git commit -v --amend'
abbr -a gco 'git checkout'
abbr -a gsw 'git switch'
abbr -a gsc 'git switch -c'
abbr -a gb 'git branch'
abbr -a gd 'git diff'
abbr -a gds 'git diff --staged'
abbr -a gl 'git log --oneline --graph --decorate -20'
abbr -a gll 'git log --graph --pretty=format:"%C(auto)%h%d %s %C(dim)(%cr) <%an>"'
abbr -a gp 'git push'
abbr -a gpf 'git push --force-with-lease'
abbr -a gpl 'git pull --rebase --autostash'
abbr -a gf 'git fetch --all --prune'
abbr -a gst 'git stash push'
abbr -a gsp 'git stash pop'
abbr -a grh 'git reset HEAD'

# pacman/aur(pac 前缀避免撞 pi/pr 等真实命令)
abbr -a pacs 'sudo pacman -S'
abbr -a pacss 'pacman -Ss'
abbr -a pacsi 'pacman -Si'
abbr -a pacqs 'pacman -Qs'
abbr -a pacrm 'sudo pacman -Rns'
abbr -a pacu 'sudo pacman -Syu'
abbr -a pacorphan 'pacman -Qtdq'
abbr -a pacclean 'sudo pacman -Sc'
abbr -a pacown 'pacman -Qo'
# AUR 助手固定 paru(AGENTS.md:paru 为 pacman 工具链,系统级)
abbr -a a paru
abbr -a au 'paru -Sua'

# systemd
abbr -a sc 'sudo systemctl'
abbr -a scu 'systemctl --user'
abbr -a scs 'systemctl status'
abbr -a jc 'journalctl -xe'
abbr -a jcf 'journalctl -f'
abbr -a jcu 'journalctl -u'

# 杂项
abbr -a v nvim
abbr -a vf 'nvim (fzf)'
abbr -a fishrc '$EDITOR ~/nix-config/config/fish/config.fish'   # 源文件(HM 托管的是 store 符号链接,勿直接编辑)
abbr -a reload 'exec fish'
abbr -a ports 'ss -tulpn'
abbr -a myip 'curl -s https://ifconfig.me; echo'
abbr -a path 'string join \n -- $PATH'
abbr -a now 'date +"%Y-%m-%d %H:%M:%S"'

# ---------- 函数 ----------
# 建目录并进入
function mkcd
    test -z "$argv[1]"; and echo 'mkcd: 需要目录名' >&2; and return 1
    mkdir -p -- $argv[1]; and cd -- $argv[1]
end

# 按扩展名自动解压
function extract
    for f in $argv
        if not test -f $f
            echo "extract: '$f' 不是文件" >&2
            continue
        end
        switch $f
            case '*.tar.bz2' '*.tbz2'; tar xjf $f
            case '*.tar.gz' '*.tgz';   tar xzf $f
            case '*.tar.xz' '*.txz';   tar xJf $f
            case '*.tar.zst';          tar --zstd -xf $f
            case '*.tar';              tar xf $f
            case '*.bz2';              bunzip2 $f
            case '*.gz';               gunzip $f
            case '*.zip' '*.jar';      unzip $f
            case '*.rar';              unrar x $f
            case '*.7z';               7z x $f
            case '*.zst';              unzstd $f
            case '*';                  echo "extract: 不认识的格式 '$f'" >&2
        end
    end
end

# 带时间戳备份
function bak
    for f in $argv
        cp -a -- $f $f.(date +%Y%m%d-%H%M%S).bak
    end
end

# sudo 重跑上一条命令
function please
    eval command sudo $history[1]
end

# 当前目录起 HTTP 服务,默认仅 127.0.0.1(--lan 才暴露,无鉴权)
function serve
    set -l port 8000
    test -n "$argv[1]"; and set port $argv[1]
    set -l host 127.0.0.1
    if contains -- --lan $argv
        set host 0.0.0.0
        echo "警告:已监听 0.0.0.0,当前目录对整个网络可读" >&2
    end
    echo "http://$host:$port  (Ctrl-C 停止)"
    python3 -m http.server --bind $host $port
end

# 目录用量 Top N(装了 dust 不覆盖)
if not command -q dust
    function dust
        set -l n 20
        test -n "$argv[1]"; and set n $argv[1]
        find . -mindepth 1 -maxdepth 1 -print0 \
            | du -sh --files0-from=- 2>/dev/null \
            | sort -rh | head -n $n
    end
end

# 查名字是别名/函数/二进制
function wtf
    for a in $argv
        type -a $a 2>/dev/null; or echo "wtf: 找不到 $a" >&2
    end
end

# ---------- 第三方(zoxide → fzf → starship 均已声明式安装;direnv 未装则跳过) ----------
zoxide init --cmd cd fish | source

set -gx FZF_DEFAULT_OPTS '--height=60% --layout=reverse --border=rounded --info=inline --cycle --bind=ctrl-/:toggle-preview,ctrl-u:preview-page-up,ctrl-d:preview-page-down'
set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_OPTS '--preview="bat -n --color=always {}"'
fzf --fish | source

command -q direnv; and direnv hook fish | source
starship init fish | source

# ---------- 键位 ----------
bind ctrl-z 'fg 2>/dev/null; commandline -f repaint'
bind alt-. history-token-search-backward
bind ctrl-l 'clear; commandline -f repaint'
