host := "flakeos"

default:
    @just --list

switch:
    nh os switch .

build:
    nh os build .

boot:
    nh os boot .

update:
    nix flake update
    nh os switch .

update-input input:
    nix flake update {{input}}

check:
    nix flake check --no-build

fmt:
    nix fmt

rollback:
    sudo nixos-rebuild switch --rollback --flake .#{{host}}

generations:
    nixos-rebuild list-generations

diff:
    nh os build . --diff always

diff-gen a b:
    nvd diff /nix/var/nix/profiles/system-{{a}}-link /nix/var/nix/profiles/system-{{b}}-link

gc:
    sudo nix-collect-garbage -d --delete-older-than 14d
    nix store optimise

dsh-web:
    @url="$(journalctl --user -u dsh-web.service --no-pager | grep 'dsh web: http' | tail -1 | sed 's/.*dsh web: //')"; \
    if [ -z "$url" ]; then echo "未找到 dsh web URL，先启动服务：systemctl --user restart dsh-web.service" >&2; exit 1; fi; \
    echo "opening: $url"; \
    xdg-open "$url"
