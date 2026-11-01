# ~/.config/fish/config.fish — atomic-workstation
#
# Ported from this repo's NixOS config (home/programs/fish.nix):
# vi keybindings, no greeting, short aliases.

if status is-interactive
    set -g fish_greeting ""
    fish_vi_keybindings
end

# aliases (ported from NixOS)
alias la 'ls -a'
alias lla 'ls -la'
alias c 'clear'
alias z 'cd'

# Tools that arrive via Homebrew on Bazzite — guard so this file is safe
# on any machine/container even before brew is set up.
if type -q zoxide
    zoxide init fish | source
end
if type -q direnv
    direnv hook fish | source
end
if type -q starship
    starship init fish | source
end
