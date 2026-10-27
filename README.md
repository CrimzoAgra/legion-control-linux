# Legion Control for Linux

A small Lenovo Legion Space / Vantage replacement for Linux, built with [Quickshell](https://quickshell.org).
Made for the **Legion Pro 7 16IAX10H (Gen 10)**; other recent Legions may work in part.

## Features

- **Performance**: power modes (platform profile) and firmware power/temperature limits
  (CPU PL1/PL2, GPU TGP, Dynamic Boost…) through the `lenovo-wmi-gamezone` / `lenovo-wmi-other` kernel drivers
- **Lighting**: keyboard, front light bar and back (rear vent) light, per zone: static, breathing,
  rainbow wave, colour change, smooth, spiral, off or the original profile, plus brightness.
  Effects are saved into the keyboard controller, so they stay after reboots and on Windows
- **Battery & keyboard**: conservation mode (charge limit), USB charging while off, Fn lock
- **Updates**: BIOS and device firmware through fwupd / LVFS, plus system updates

The lid "LEGION" lettering isn't controllable yet (it's not on the keyboard controller, the
lighting WMI, or the Dynamic Lighting interface).

## Install

Needs Arch / CachyOS (the root installer uses pacman), `quickshell`, `python`, `polkit`.

```sh
bash install-user.sh
sudo bash ~/.local/share/legion-control/install.sh
```

Then open **Legion Control** from your app launcher, or run `legion-control`.

The root installer adds:
- `/usr/local/bin/legion-ctl`: a small helper that only reads and writes the settings above (values are checked)
- a polkit rule so users in `wheel` can run that helper without a password
- a udev rule giving the logged-in user access to the lighting controller (`048d:c197`)
- `fwupd` and `acpi_call-dkms`

Remove: `sudo rm /usr/local/bin/legion-ctl /etc/polkit-1/rules.d/50-legion-ctl.rules /etc/udev/rules.d/70-legion-rgb.rules`

## How the lighting works

`legion-rgb` speaks Lenovo's lighting protocol on the ITE `048d:c197` controller (HID feature
report `0x07`, 960 bytes), as documented by OpenRGB's Lenovo Gen 7/8/10 driver. Light ids are
`zone << 8 | number`: 0 keyboard, 1 front bar, 3 back vents. Before the first change the active
profile is backed up to `~/.config/legion-control/`, and the "Default" mode restores it.

## Files

| File | What it is |
| --- | --- |
| `shell.qml` | the app (Quickshell) |
| `legion-rgb` | lighting tool (runs as you) |
| `legion-ctl` | settings helper (root, through pkexec) |
| `install.sh` | root installer |
| `install-user.sh` | user installer |
