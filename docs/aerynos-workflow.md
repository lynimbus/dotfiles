# Running this machine the way AerynOS users run theirs

AerynOS gets its feel from `moss`: every change is one transaction, the running
`/usr` is swapped in place, and there is always a previous state to go back to.
NixOS reaches the same feel through different machinery. This page maps one set
of habits onto the other so the switch costs nothing to think about.

## Day to day

| You would type in AerynOS | Type this here |
| --- | --- |
| `moss sync` | `just switch` |
| `moss sync`, then reboot | `just stage`, then reboot |
| `moss state list` | `just gens` |
| `moss state activate N` | `just undo`, or pick the generation in the boot menu |
| `moss search foo` | `nix search nixpkgs foo` |
| `moss install foo` | `nix shell nixpkgs#foo`, or add it to `environment.systemPackages` |
| `moss install foo` for one run | `, foo` |
| `moss remove foo` | delete the line from the module, then `just switch` |
| `moss history` | `git log` in this repository |

## What each habit buys

`just stage` builds the new generation and makes it the boot default without
touching the running system. Nothing changes until you reboot, so a failed
build cannot leave a half-applied system behind. AerynOS gets this for free
because it swaps `/usr` in one `renameat2` call. NixOS gets it by deferring the
whole change to the next boot.

`just try` activates a generation now without making it the default, so the
next reboot returns to the generation that was already there. Use it when
changing a desktop config, because a generation that fails its boot check three
times gets skipped permanently and you do not want to spend those attempts on a
change you already know how to revert.

`just undo` returns to the previous generation and makes it the boot default.
`just gens` lists what `undo` can reach.

## Boot counting and rollback

`system/boot.nix` turns on systemd-boot boot counting. A new entry is written
with a count of 3. systemd-boot decrements it on each attempt. If the machine
reaches `boot-complete.target`, `systemd-bless-boot` removes the counter and
marks the entry good. If the count hits zero first, the entry is skipped and the
previous generation boots instead.

`system/boot-complete.nix` decides what counts as reaching that target. Without
it the target is satisfied the moment `sysinit.target` finishes, so a machine
with a broken GPU driver would still bless itself. The check waits for a DRM
card and a login prompt on tty1, which are the two things that are actually
missing when a boot is unusable here.

There is no display manager on this machine, so no Wayland session exists until
someone logs in at tty1. Waiting for a compositor socket would fail every boot,
which is why the check waits for the login prompt instead.

## What NixOS cannot do

AerynOS replaces the live `/usr` with a single `renameat2(RENAME_EXCHANGE)`
call. Running processes keep their open file descriptors and pick up new files
on their next `exec`. The swap either happened or it did not.

`/run/current-system` on NixOS is a tree of symlinks, not one directory that can
be exchanged, so there is no atomic swap primitive to call. `nixos-rebuild
switch` rewrites symlinks and restarts units one at a time, which has a middle
state by construction.

The choices are to accept the middle state with `just switch`, to defer the
whole change to a reboot with `just stage`, or to use a system whose package
manager swaps the root. There is no third option on NixOS.
