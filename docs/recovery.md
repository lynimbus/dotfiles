# recovery — atomic-workstation

Disaster recovery: new machine, broken update, lost data.

## New machine bootstrap (the full flow)

```bash
# 0. install Bazzite from its ISO (or rebase an existing ostree host)
sudo bootc switch ghcr.io/<owner>/atomic-workstation:latest && sudo systemctl reboot

# 1. log into the SWAY session once (verify the image works)

# 2. get the repo
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/  # if missing
git clone git@github.com:<owner>/<repo>.git ~/dotfiles

# 3. run the guided restore (config → flatpak → brew → distrobox → timer)
~/dotfiles/scripts/restore.sh
```

`restore.sh` shows the chezmoi diff BEFORE applying anything and asks for
confirmation. Reboot (or just log out) and enjoy.

## System update fails / boots badly

bootc/Bazzite keeps the previous deployment. At the boot menu (GRUB/SDDM
gear icon) choose the previous entry, or from a working boot:

```bash
sudo bootc rollback            # pin the previous deployment
sudo systemctl reboot
```

You are back on the last good image. Then:

* Bad custom image? Fix in git, let CI rebuild, `sudo bootc upgrade`.
* Want stock Bazzite back? `sudo bootc switch ghcr.io/ublue-os/bazzite:stable`.

## Restore data (restic)

```bash
# one-time: point at your backup location
cp .env.example ~/.config/atomic-workstation/backup.env && edit it

./scripts/backup.sh snapshots   # what exists
mkdir -p ~/Documents
restic restore latest --target ~   # or: restic mount /tmp/restic
```

Backups are USER DATA only (`~/Documents`, `~/Pictures` by default — never
the whole home; caches and container images are excluded). See
`.env.example` for the knobs.

## Git conflicts during sync

`sync.sh` refuses to act during a merge/rebase and tells you:

```bash
git -C ~/dotfiles status          # see what's in progress
git -C ~/dotfiles rebase --continue   # or --abort
# then re-run
./scripts/sync.sh --commit --push
```

It never resets, never force-pushes. If the remote rejected a push
(non-fast-forward), it stops with instructions — you resolve manually.

## Lost the whole machine

1. Bazzite ISO → install (or restore from your bare-metal backup if any)
2. `bootc switch` to the custom image
3. clone the repo → `restore.sh`
4. restic restore user data
5. verify: `./scripts/doctor.sh`

The repo IS the machine definition: image (Containerfile), config
(home/chezmoi), apps (inventory), dev boxes (distrobox.ini).

## Chezmoi says a file would be overwritten

You have a local file chezmoi wants to manage (e.g. an old
`~/.config/sway/config`):

```bash
chezmoi --source ~/dotfiles/home/chezmoi diff        # see the change
mv ~/.config/sway/config ~/.config/sway/config.bak   # keep yours
chezmoi --source ~/dotfiles/home/chezmoi apply        # apply ours
diff ~/.config/sway/config.bak ~/.config/sway/config # merge by hand
```
