# ~/.config/fish/config.fish — atomic-workstation
#
# Port of home/programs/fish.nix (main branch): vi keybindings, no greeting,
# short aliases, the jjmsg commit-message generator. Tool init lines are
# guarded so this file stays safe on any machine/container (tools arrive via
# Homebrew on Bazzite) — that part follows the atomic branch's original
# config.fish.

if status is-interactive
    set -g fish_greeting ""
    # Name is `fish_vi_key_bindings` (two words + underscore). The port from
    # the main branch's fish.nix wrote `fish_vi_keybindings`, which is not a
    # fish function and makes every interactive shell print
    #   fish: Unknown command: fish_vi_keybindings
    fish_vi_key_bindings
end

# ~/.local/bin — GitHub-release apps (magpie, ghostty, opengrep, …) live here
fish_add_path -g ~/.local/bin

# Homebrew. Bazzite's /usr/share/fish/vendor_conf.d/ublue-brew.fish already
# does this — but only for the image's /usr/bin/fish, and only when
# interactive. Any other fish does not read that vendor dir at all, and
# non-interactive shells skip it, so add the path here too. base.Brewfile no
# longer installs a brew fish — the image owns fish. Appended, so a brew
# `dbus`/`just` never shadows the image's; fish_add_path is a no-op when the
# entry is already there.
if test -d /home/linuxbrew/.linuxbrew/bin
    fish_add_path --append --global --path /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin
end

# aliases (ported from NixOS)
alias la 'ls -a'
alias lla 'ls -la'
alias c 'clear'
alias z 'cd'

# Tools that arrive via Homebrew on Bazzite — guard so this file is safe
# on any machine/container even before brew is set up.
if type -q zoxide
    zoxide init fish --cmd cd | source
end
if type -q direnv
    direnv hook fish | source
end
if type -q starship
    starship init fish | source
end
