# Updates

The **Updates** page updates your laptop's firmware and your system.

## Firmware

This covers the BIOS and the laptop's other devices, through fwupd and Linux's firmware service, LVFS.

Click **Check for updates**. The page lists your devices with their versions, and shows the new version next to any
device that has an update. Click **Install** to install them: a terminal window opens and runs `fwupdmgr update`.

Lenovo doesn't publish every Legion BIOS for Linux. If a BIOS update shows on Lenovo's site but not here, it needs
Windows or Lenovo's own updater.

## Apps and system

**Update now** opens a terminal that updates your system packages, AUR packages and Flatpaks
(`sudo pacman -Syu`, then `paru -Sua` and `flatpak update` if you have paru and Flatpak). It uses the first
terminal you have of foot, Alacritty, kitty, Konsole and xterm. On AgrOS, where the system updates itself at every boot, the page
also shows when that last ran.

Next: [Troubleshooting](07-troubleshooting.md)
