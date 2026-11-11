# Installing

You need Arch or CachyOS (the root installer uses pacman), with `quickshell`, `python` and `polkit` installed.

## Install

Installing has two parts: one for your user, then one that needs root. From the repo's folder, run:

```sh
bash install-user.sh
sudo bash ~/.local/share/legion-control/install.sh
```

The first command puts the app in `~/.local/share/legion-control`, adds the `legion-control` command and the app
launcher entry. The second installs `fwupd` and `acpi_call-dkms`, a small settings helper, and the permissions it needs
(see [How it works](../docs/how-it-works.md#what-the-root-installer-adds)). At the end it shows your current settings
and the firmware devices fwupd knows about.

Then open **Legion Control** from your app launcher, or run `legion-control`.

Your user needs to be in the `wheel` group: that's what lets the app change settings without asking for your password.

## Remove

```sh
sudo rm /usr/local/bin/legion-ctl /etc/polkit-1/rules.d/50-legion-ctl.rules /etc/udev/rules.d/70-legion-rgb.rules
```

Next: [Performance](03-performance.md)
