#!/usr/bin/env bash
# Installs Legion Control's parts that need root. Run with: sudo bash ~/.local/share/legion-control/install.sh
#  - fwupd (firmware/BIOS updates from Linux's firmware service, LVFS)
#  - /usr/local/bin/legion-ctl: the helper that reads/changes the laptop settings
#  - a polkit rule so admins (wheel) can use that helper without typing a password
#  - a udev rule so you can control the keyboard lighting
#  - acpi_call, for the firmware-controlled Legion logo light
# Remove: sudo rm /usr/local/bin/legion-ctl /etc/polkit-1/rules.d/50-legion-ctl.rules /etc/udev/rules.d/70-legion-rgb.rules
set -e
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }
src=$(dirname "$(readlink -f "$0")")

pacman -S --needed --noconfirm fwupd acpi_call-dkms
# acpi_call: lets the helper use Lenovo's lighting firmware method (Legion logo on the lid)
echo acpi_call >/etc/modules-load.d/acpi_call.conf
modprobe acpi_call || echo "acpi_call didn't load (it may need a reboot after a kernel update)"
install -m 755 "$src/legion-ctl" /usr/local/bin/legion-ctl

cat >/etc/polkit-1/rules.d/50-legion-ctl.rules <<'EOF'
// Legion Control: admins may run the settings helper without a password
polkit.addRule(function (action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program") == "/usr/local/bin/legion-ctl" &&
        subject.local && subject.active && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
chmod 644 /etc/polkit-1/rules.d/50-legion-ctl.rules

# Keyboard lighting: let the logged-in user use the Lenovo Lighting device (standard HID LampArray)
cat >/etc/udev/rules.d/70-legion-rgb.rules <<'EOF'
# Legion Control: lighting for the logged-in user
#   048d:c197 keyboard, light bars and logo (Lenovo lighting protocol)
#   048d:c193 Dynamic Lighting interface (its "branding" lights may be the lid lettering)
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="048d", ATTRS{idProduct}=="c197", TAG+="uaccess"
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="048d", ATTRS{idProduct}=="c193", TAG+="uaccess"
EOF
udevadm control --reload-rules
udevadm trigger --subsystem-match=hidraw --action=change

echo "== settings now:"
/usr/local/bin/legion-ctl get | python3 -m json.tool | head -40
echo
echo "== firmware devices fwupd knows:"
fwupdmgr get-devices 2>/dev/null | grep -E "^[^ │├└]|─" | head -20 || true
echo
echo "Done. Open Legion Control from the Super menu."
