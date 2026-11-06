# tests — atomic-workstation

## Layout

Each `tests/test_<name>.sh` file is one suite. `run.sh` auto-discovers every `tests/test_*.sh` (so adding a suite needs no registry edit); `lib.sh` holds the tiny assertion framework and the mock sandbox helpers (`t_setup` / `t_teardown`). Assertions are behavioural: they drive the capture/restore scripts through the real-named mocks in `tests/fixtures/bin/` and check the resulting files and output.

## Running

    ./tests/run.sh              every discovered tests/test_*.sh suite
    ./tests/run.sh flatpak      one discovered suite (by name)
    bash tests/test_inventory_data.sh   the canonical QQ data guard on its own

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
* chezmoi apply against a real $HOME (needs the chezmoi binary; the niri
  config syntax is exercised only when you apply it on the target machine)
