<p align="center">
  <img src="../data/legion-control.svg" alt="Legion Control" width="128">
</p>

# How Legion Control works

Legion Control is a Quickshell app (`shell.qml`) with two helpers. Settings that need root go through `legion-ctl`,
which the app runs with `pkexec`. Lighting goes through `legion-rgb`, which runs as you and talks to the lighting
controller directly. Updates go through `fwupdmgr` and pacman, paru and Flatpak.

## Files

| File | What it is |
| --- | --- |
| `shell.qml` | the app (Quickshell) |
| `legion-rgb` | lighting tool (runs as you) |
| `legion-ctl` | settings helper (root, through pkexec) |
| `install.sh` | root installer |
| `install-user.sh` | user installer |
| `data/legion-control` | the `legion-control` launcher: `qs -p ~/.local/share/legion-control` |
| `data/legion-control.desktop` | the app launcher entry |
| `data/legion-control.svg` | the icon |

## Installing

`install-user.sh` needs no root. It copies `shell.qml`, `legion-ctl`, `legion-rgb` and `install.sh` to
`~/.local/share/legion-control`, the launcher to `~/.local/bin/legion-control`, the icon to
`~/.local/share/icons/hicolor/scalable/apps`, and the desktop entry to `~/.local/share/applications` (with `@HOME@`
filled in).

### What the root installer adds

`sudo bash ~/.local/share/legion-control/install.sh` adds:

- `/usr/local/bin/legion-ctl`: a small helper that only reads and writes the settings below (values are checked)
- a polkit rule (`/etc/polkit-1/rules.d/50-legion-ctl.rules`) so users in `wheel` can run that helper without a
  password. It applies only to `pkexec /usr/local/bin/legion-ctl`, from a local, active session.
- a udev rule (`/etc/udev/rules.d/70-legion-rgb.rules`) giving the logged-in user (`uaccess`) access to the lighting
  controller (`048d:c197`) and to the Dynamic Lighting interface (`048d:c193`)
- `fwupd` and `acpi_call-dkms`, with `acpi_call` loaded at boot (`/etc/modules-load.d/acpi_call.conf`)

It needs pacman. At the end it prints `legion-ctl get` and the devices fwupd knows.

Remove: `sudo rm /usr/local/bin/legion-ctl /etc/polkit-1/rules.d/50-legion-ctl.rules /etc/udev/rules.d/70-legion-rgb.rules`.
That leaves `/etc/modules-load.d/acpi_call.conf` and the fwupd and acpi_call-dkms packages in place.

## The settings helper: legion-ctl

A Python script run as root through pkexec. It only touches these settings and checks every value first:

```
legion-ctl get                 all settings as JSON
legion-ctl set <key> <value>   change one setting
legion-ctl light <id>          read a firmware light (Lenovo lighting WMI, through acpi_call)
```

| Key | Where it goes | Allowed values |
| --- | --- | --- |
| `profile` | `/sys/firmware/acpi/platform_profile` | one of `platform_profile_choices` |
| `conservation`, `usb_charging`, `fn_lock` | `conservation_mode`, `usb_charging`, `fn_lock` under `/sys/bus/platform/devices/VPC2004:00` (ideapad) | `0` or `1` |
| `attr:<name>` | `/sys/class/firmware-attributes/lenovo-wmi-other-*/attributes/<name>/current_value` | a number within the attribute's `min_value` and `max_value` |
| `light:<id>` | Lenovo lighting WMI method `\_SB_.GZFD.WMAF` through `/proc/acpi/call` | id 0-7, value `"a,b"` (0-255 each) |

The power modes come from the `lenovo-wmi-gamezone` kernel driver (the platform profile) and the power and
temperature limits from `lenovo-wmi-other` (firmware attributes). After a `set`, the helper prints the settings again,
which the app uses to refresh. The app queues changes, so only one `legion-ctl` runs at a time.

The app shows a slider for every attribute with a minimum and maximum, and has friendly names for the known ones
(`ppt_pl1_spl`, `ppt_pl2_sppt`, `ppt_pl1_tau`, `ppt_cpu_cl`, `cpu_temp`, `gpu_nv_ctgp`, `gpu_nv_ppab`,
`gpu_nv_cpu_boost`, `gpu_nv_ac_offset`, `gpu_temp`).

## How the lighting works

`legion-rgb` speaks Lenovo's lighting protocol on the ITE `048d:c197` controller (HID feature report `0x07`, 960
bytes), as documented by OpenRGB's Lenovo Gen 7/8/10 driver. Light ids are `zone << 8 | number`: 0 keyboard, 1 front
bar, 3 back vents, 5 lid logo. Before the first change the active profile is backed up to `~/.config/legion-control/`
(`lenovo-profile-<n>.bin`), and the "Default" mode restores it.

```
legion-rgb info           profile, brightness and number of lights (read-only)
legion-rgb apply [json]   apply these settings (default: ~/.config/legion-control/rgb.json)
```

The app saves its lighting settings to `~/.config/legion-control/rgb.json` and passes them to `legion-rgb apply`
directly:

```json
{"brightness": 0-100,
 "zones": {"keyboard"|"front"|"back"|"logo":
           {"mode": "default|off|static|breathing|wave|cycle|smooth|spiral",
            "color": "#rrggbb", "speed": 1-10}}}
```

`apply` writes one group per zone into the active profile with `SAVE_PROFILE`, switches to that profile, and sets the
brightness. Zones set to `off` are left out of every group. Brightness 0-100 maps to the controller's 0-9, speed 1-10
to its 1-3. The `logo` zone isn't shown in the app; it follows the **All** setting.

The lid "LEGION" lettering isn't controllable yet: it's not on the keyboard controller, the lighting WMI or the
Dynamic Lighting interface.

## Updates

- **Firmware**: `fwupdmgr get-devices --json`, then `fwupdmgr refresh --force` and `fwupdmgr get-updates --json`. The
  app lists updatable and internal devices. **Install** runs `fwupdmgr update` in Alacritty.
- **Apps and system**: **Update now** runs `sudo pacman -Syu; paru -Sua; flatpak update` in Alacritty. The "last run"
  time is read from `/var/log/auto-update.log`, AgrOS's boot-time updater, when it exists.

## The app

`shell.qml` reads the laptop model from `/sys/class/dmi/id/product_version` and checks that
`/usr/local/bin/legion-ctl` exists; if not, it shows the install command. Its colours come from Caelestia's
`~/.local/state/caelestia/scheme.json` (with built-in defaults when that file is missing). It uses the Rubik and
Material Symbols Rounded fonts.

## Development

Edit the files in the repo, then run `bash install-user.sh` again to copy them into place. Run the root installer
again after changing `legion-ctl`.

## Credits

The lighting protocol comes from [OpenRGB](https://gitlab.com/CalcProgrammer1/OpenRGB)'s Lenovo USB controller
documentation and driver.

Back to the [README](../README.md)
