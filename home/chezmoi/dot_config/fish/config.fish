# ~/.config/fish/config.fish — atomic-workstation
#
# Port of home/programs/fish.nix (main branch): vi keybindings, no greeting,
# short aliases, the jjmsg commit-message generator. Tool init lines are
# guarded so this file stays safe on any machine/container (tools arrive via
# Homebrew on Bazzite) — that part follows the atomic branch's original
# config.fish.

if status is-interactive
    set -g fish_greeting ""
    fish_vi_keybindings
end

# ~/.local/bin — GitHub-release apps (magpie, ghostty, pig, …) live here
fish_add_path -g ~/.local/bin

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
