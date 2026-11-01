# tests — atomic-workstation

## Layout

| path | purpose |
| --- | --- |
| `run.sh` | runs every suite (or one: `./tests/run.sh flatpak`) |
| `lib.sh` | tiny assertion framework + sandbox helpers (`t_setup`/`t_teardown`) |
| `test_flatpak.sh` | capture/restore/status/prune against the mock CLI |
| `test_brew.sh` | Brewfile dump/restore, absent-brew, failures |
| `test_distrobox.sh` | container capture/restore, idempotency |
| `test_inventory.sh` | inventory.sh argument parsing / profile handling (regression tests) |
| `test_git.sh` | sync.sh git behaviour (throwaway copy, never the real repo) |
| `test_systemd.sh` | unit-file validation + timer semantics |
| `fixtures/bin/mock-*` | test doubles for flatpak / brew / distrobox |

## Mocks

The mocks speak exactly the CLI surface the real scripts use:

* **mock-flatpak** — `--version`, `list --app --columns=… --user|--system`
  (emits the 5 columns incl. installation), `remotes --columns=…`,
  `remote-add --if-not-exists`, `install`, `uninstall`;
  state in `$MOCK_STATE/flatpak/<scope>/*.tsv`
* **mock-brew** — `--version`, `leaves`, `list [--formula|--cask]`,
  `bundle dump`, `bundle`; state in `$MOCK_STATE/brew/*.txt`
* `mock-distrobox` — `--version`, `list`, `assemble create --file`, `enter`;
  state in `$MOCK_STATE/distrobox/containers.tsv`

`t_setup` links each mock into a sandbox PATH under its REAL name
(`flatpak`, `brew`, `distrobox`), so the scripts under test resolve them
exactly as they would resolve the real binaries on Bazzite.

## What is NOT covered here

* building the OCI image (needs podman + multi-GB base image pull — see
  `docs/installation.md`, "local build")
* real flatpak/brew/distrobox behaviour (only our usage of them)
* chezmoi apply against a real $HOME (needs the chezmoi binary; the sway
  config syntax is exercised only when you apply it on the target machine)
