//@ pragma AppId legion-control
// Legion Control: Lenovo Legion settings and updates, in Caelestia's style.
// Settings go through /usr/local/bin/legion-ctl (root helper, allowed without a password by polkit).
// Run: legion-control   (installed by: sudo bash ~/.local/share/legion-control/install.sh)
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // ---- theme: Caelestia's current colours ----
    property var c: ({})

    function col(name: string, fallback: string): color {
        return "#" + (c[name] ?? fallback);
    }

    readonly property color primary: col("primary", "c2c1ff")
    readonly property color fgOnPrimary: col("onPrimary", "2a2a60")
    readonly property color primaryContainer: col("primaryContainer", "7171ac")
    readonly property color fgOnPrimaryContainer: col("onPrimaryContainer", "ffffff")
    readonly property color secondaryContainer: col("secondaryContainer", "45455c")
    readonly property color fgOnSecondaryContainer: col("onSecondaryContainer", "e2e0f9")
    readonly property color surface: col("surface", "131317")
    readonly property color surfaceContainerLow: col("surfaceContainerLow", "1b1b1f")
    readonly property color surfaceContainer: col("surfaceContainer", "201f23")
    readonly property color surfaceContainerHigh: col("surfaceContainerHigh", "2a292e")
    readonly property color surfaceContainerHighest: col("surfaceContainerHighest", "353438")
    readonly property color fg: col("onSurface", "e5e1e7")
    readonly property color fgVariant: col("onSurfaceVariant", "c8c5d1")
    readonly property color outline: col("outline", "918f9a")
    readonly property color outlineVariant: col("outlineVariant", "47464f")
    readonly property color error: col("error", "ffb4ab")
    readonly property string font: "Rubik"
    readonly property string iconFont: "Material Symbols Rounded"

    FileView {
        path: `${Quickshell.env("HOME")}/.local/state/caelestia/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.c = JSON.parse(text()).colours;
            } catch (e) {}
        }
    }

    // ---- laptop state (from legion-ctl) ----
    property var st: ({})
    property bool installed: true
    property string status
    property string model

    readonly property var profileInfo: ({
            "low-power": { label: "Quiet", icon: "energy_savings_leaf", desc: "Silent, longest battery" },
            "balanced": { label: "Balanced", icon: "balance", desc: "Everyday use" },
            "performance": { label: "Performance", icon: "speed", desc: "Gaming and heavy work" },
            "max-power": { label: "Extreme", icon: "local_fire_department", desc: "Maximum power, loud fans" },
            "custom": { label: "Custom", icon: "tune", desc: "Your own power limits" }
        })

    readonly property var attrInfo: ({
            "ppt_pl1_spl": { label: "CPU sustained power (PL1)", unit: "W" },
            "ppt_pl2_sppt": { label: "CPU boost power (PL2)", unit: "W" },
            "ppt_pl1_tau": { label: "CPU boost duration", unit: "s" },
            "ppt_cpu_cl": { label: "CPU power when GPU is busy", unit: "W" },
            "cpu_temp": { label: "CPU temperature limit", unit: "°C" },
            "gpu_nv_ctgp": { label: "GPU power (TGP)", unit: "W" },
            "gpu_nv_ppab": { label: "GPU Dynamic Boost", unit: "W" },
            "gpu_nv_cpu_boost": { label: "GPU to CPU power shift", unit: "W" },
            "gpu_nv_ac_offset": { label: "GPU power offset on AC", unit: "W" },
            "gpu_temp": { label: "GPU temperature limit", unit: "°C" }
        })

    function ctl(args: var): void {
        ctlProc.command = ["pkexec", "/usr/local/bin/legion-ctl", ...args];
        ctlProc.running = true;
    }

    function setValue(key: string, value: string): void {
        if (ctlProc.running)
            pending.push([key, value]);
        else
            ctl(["set", key, value]);
    }

    property var pending: []

    Process {
        id: ctlProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.st = JSON.parse(text);
                    root.status = "";
                } catch (e) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.status = text.trim()
        }
        onExited: code => {
            if (code === 127 || code === 126 && !root.st.profile)
                root.installed = false;
            const next = root.pending.shift();
            if (next)
                root.ctl(["set", ...next]);
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "cat /sys/class/dmi/id/product_version; [ -x /usr/local/bin/legion-ctl ] && echo ok"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.model = lines[0] ?? "";
                root.installed = lines.includes("ok");
                if (root.installed)
                    root.ctl(["get"]);
            }
        }
    }

    // ---- lighting: settings in rgb.json, applied by legion-rgb ----
    // Zones: keyboard, front light bar, back (rear vents), lid logo; each has its own effect
    readonly property var zoneNames: [
        { key: "all", label: "All", icon: "select_all" },
        { key: "keyboard", label: "Keyboard", icon: "keyboard" },
        { key: "front", label: "Front light", icon: "horizontal_rule" },
        { key: "back", label: "Back light", icon: "flip_to_back" }
        // The lid lettering isn't reachable from Linux yet (tested: keyboard zones, firmware light, Dynamic Lighting)
    ]
    readonly property var zoneKeys: ["keyboard", "front", "back", "logo"] // logo: small light, kept in sync with "All"
    readonly property var zoneDefault: ({ mode: "default", color: "#c2c1ff", speed: 5 })
    property var rgb: ({ brightness: 100, zones: {} })
    property string rgbZone: "all"
    // Settings of the selected zone ("All": the shared value, or null where zones differ)
    readonly property var cur: {
        const zs = rgbZone === "all" ? zoneKeys : [rgbZone];
        const vals = zs.map(z => Object.assign({}, zoneDefault, rgb.zones?.[z] ?? {}));
        const same = f => vals.every(v => v[f] === vals[0][f]) ? vals[0][f] : null;
        return { mode: same("mode"), color: same("color") ?? "", speed: same("speed") ?? vals[0].speed };
    }
    property string rgbInfo
    property bool rgbOk: true
    // Lighting goes through legion-rgb (Lenovo's protocol on 048d:c197, as in OpenRGB's Gen 10 driver)
    readonly property bool rgbWorks: rgbOk

    readonly property var rgbModes: [
        { mode: "default", label: "Lenovo default", icon: "auto_awesome", desc: "Your lighting from before" },
        { mode: "static", label: "Static", icon: "lightbulb", desc: "One colour" },
        { mode: "breathing", label: "Breathing", icon: "air", desc: "Fades in and out" },
        { mode: "wave", label: "Rainbow wave", icon: "waves", desc: "Colours flow across" },
        { mode: "spiral", label: "Spiral rainbow", icon: "cyclone", desc: "Rainbow swirl" },
        { mode: "cycle", label: "Colour change", icon: "palette", desc: "All lights change colour" },
        { mode: "smooth", label: "Smooth", icon: "gradient", desc: "Slow colour fade" },
        { mode: "off", label: "Off", icon: "light_off", desc: "No lighting" }
    ]
    readonly property var swatches: ["#" + (c.primary ?? "c2c1ff"), "#ffffff", "#e2231a", "#ff6a00", "#ffd000", "#3ddc84", "#00d8ff", "#2f6bff", "#8a3ffc", "#ff3fa4"]

    // Change the selected zone(s); a change while one is being applied is applied right after it
    function setZone(changes: var): void {
        const zones = Object.assign({}, rgb.zones);
        for (const z of (rgbZone === "all" ? zoneKeys : [rgbZone]))
            zones[z] = Object.assign({}, zoneDefault, zones[z] ?? {}, changes);
        saveRgb(Object.assign({}, rgb, { zones }));
    }

    function saveRgb(next: var): void {
        rgb = next;
        rgbFile.setText(JSON.stringify(rgb, null, 2) + "\n");
        if (rgbApply.running)
            rgbApplyAgain = true;
        else
            runRgbApply();
    }

    // The settings go to legion-rgb directly, so it never reads an older saved file
    function runRgbApply(): void {
        rgbApply.command = [`${Quickshell.env("HOME")}/.local/share/legion-control/legion-rgb`, "apply", JSON.stringify(rgb)];
        rgbApply.running = true;
    }

    property bool rgbApplyAgain

    Process {
        id: rgbApply

        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.status = text.trim()
        }
        onExited: {
            if (root.rgbApplyAgain) {
                root.rgbApplyAgain = false;
                Qt.callLater(root.runRgbApply);
            }
        }
    }

    FileView {
        id: rgbFile

        path: `${Quickshell.env("HOME")}/.config/legion-control/rgb.json`
        onLoaded: {
            try {
                const raw = JSON.parse(text());
                // Older single-setting files: same setting for every zone
                const flat = {};
                for (const k of ["mode", "color", "speed"])
                    if (raw[k] !== undefined)
                        flat[k] = raw[k];
                const zones = {};
                for (const z of root.zoneKeys)
                    zones[z] = Object.assign({}, root.zoneDefault, flat, raw.zones?.[z] ?? {});
                root.rgb = { brightness: raw.brightness ?? 100, zones };
            } catch (e) {}
        }
    }

    Process {
        running: true
        command: [`${Quickshell.env("HOME")}/.local/share/legion-control/legion-rgb`, "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/(\d+) lights/);
                if (m)
                    root.rgbInfo = "Keyboard, front light and back light. Effects run in the laptop itself and stay after a restart. The lid lettering can only be changed from Legion Space on Windows for now";
            }
        }
        onExited: code => root.rgbOk = code === 0
    }

    // ---- updates ----
    property var fwDevices: []
    property var fwUpdates: []
    property bool fwChecking
    property string fwStatus: "Not checked yet"
    property string lastSysUpdate

    function checkFirmware(): void {
        fwChecking = true;
        fwStatus = "Checking…";
        fwProc.running = true;
    }

    Process {
        id: fwProc

        command: ["sh", "-c", "command -v fwupdmgr >/dev/null || { echo NOFWUPD; exit; }; fwupdmgr get-devices --json 2>/dev/null; echo '@@SPLIT@@'; fwupdmgr refresh --force >/dev/null 2>&1; fwupdmgr get-updates --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fwChecking = false;
                if (text.includes("NOFWUPD")) {
                    root.fwStatus = "fwupd isn't installed (run the Legion Control installer)";
                    return;
                }
                const [devs, ups] = text.split("@@SPLIT@@");
                try {
                    root.fwDevices = (JSON.parse(devs).Devices ?? []).filter(d => (d.Flags ?? []).includes("updatable") || (d.Flags ?? []).includes("internal"));
                } catch (e) {
                    root.fwDevices = [];
                }
                try {
                    root.fwUpdates = JSON.parse(ups).Devices ?? [];
                } catch (e) {
                    root.fwUpdates = [];
                }
                root.fwStatus = root.fwUpdates.length ? `${root.fwUpdates.length} update${root.fwUpdates.length > 1 ? "s" : ""} available` : "Everything is up to date";
            }
        }
    }

    Process {
        id: sysUpdateProc

        running: true
        command: ["sh", "-c", "grep -E '^===== (done )?' /var/log/auto-update.log 2>/dev/null | tail -1 | sed -E 's/^===== (done )?//; s/ =====$//'"]
        stdout: StdioCollector {
            onStreamFinished: root.lastSysUpdate = text.trim()
        }
    }

    function inTerminal(script: string): void {
        Quickshell.execDetached(["alacritty", "--title", "Legion Control: updates", "-e", "sh", "-c", `${script}; echo; read -p 'Press Enter to close' _`]);
    }

    // ---- window ----
    property int page: 0

    FloatingWindow {
        id: win

        title: "Legion Control"
        color: root.surface
        implicitWidth: 980
        implicitHeight: 680

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Navigation rail
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 248
                color: root.surfaceContainerLow

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 6

                    RowLayout {
                        Layout.bottomMargin: 18
                        spacing: 12

                        Image {
                            source: `file://${Quickshell.env("HOME")}/.local/share/icons/hicolor/scalable/apps/legion-control.svg`
                            sourceSize.width: 88
                            sourceSize.height: 88
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                        }

                        ColumnLayout {
                            spacing: 0

                            Label {
                                text: "Legion Control"
                                size: 17
                                weight: Font.Medium
                            }

                            Label {
                                text: root.model || "Lenovo Legion"
                                size: 12
                                color: root.fgVariant
                            }
                        }
                    }

                    NavItem {
                        index: 0
                        icon: "speed"
                        label: "Performance"
                    }

                    NavItem {
                        index: 1
                        icon: "backlight_high"
                        label: "Lighting"
                    }

                    NavItem {
                        index: 2
                        icon: "battery_charging_full"
                        label: "Battery & keyboard"
                    }

                    NavItem {
                        index: 3
                        icon: "system_update_alt"
                        label: "Updates"
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: !!root.status
                        text: root.status
                        color: root.error
                        size: 12
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Pages
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: pages.implicitHeight + 64
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: pages

                    x: 32
                    y: 32
                    width: parent.width - 64
                    spacing: 18

                    Card {
                        visible: !root.installed
                        Layout.fillWidth: true
                        color: Qt.alpha(root.error, 0.15)

                        Label {
                            Layout.fillWidth: true
                            text: "Legion Control isn't installed yet. Run:\nsudo bash ~/.local/share/legion-control/install.sh"
                            wrapMode: Text.Wrap
                        }
                    }

                    // ---------- Performance ----------
                    ColumnLayout {
                        visible: root.page === 0
                        Layout.fillWidth: true
                        spacing: 18

                        PageTitle {
                            text: "Performance"
                            sub: "How much power the CPU and GPU may use. Higher modes are faster but louder and hotter."
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 5
                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: (root.st.profiles ?? ["low-power", "balanced", "performance", "max-power", "custom"]).filter(p => root.profileInfo[p])

                                ModeTile {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    profile: modelData
                                }
                            }
                        }

                        Card {
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: "Custom tuning"
                                        size: 16
                                        weight: Font.Medium
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: root.st.profile === "custom" ? "Changes apply when you let go of a slider." : "Choose the Custom mode above to change these."
                                        color: root.fgVariant
                                        size: 13
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            Repeater {
                                model: Object.keys(root.st.attrs ?? {}).filter(k => root.st.attrs[k].min !== null && root.st.attrs[k].max !== null && Number(root.st.attrs[k].max) > Number(root.st.attrs[k].min))

                                AttrSlider {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    key: modelData
                                }
                            }

                            Label {
                                visible: !Object.keys(root.st.attrs ?? {}).length
                                text: "No adjustable limits found."
                                color: root.fgVariant
                                size: 13
                            }
                        }
                    }

                    // ---------- Lighting ----------
                    ColumnLayout {
                        visible: root.page === 1
                        Layout.fillWidth: true
                        spacing: 18

                        PageTitle {
                            text: "Lighting"
                            sub: root.rgbInfo ? `${root.rgbInfo}.` : "Keyboard, front light and back light."
                        }

                        Card {
                            Layout.fillWidth: true
                            visible: !root.rgbWorks

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Icon {
                                    text: "info"
                                    size: 26
                                    color: root.primary
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: "Can't reach the keyboard lighting. Run the Legion Control installer again (sudo bash ~/.local/share/legion-control/install.sh), then reopen this app."
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        Flow {
                            visible: root.rgbWorks
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: root.zoneNames

                                Rectangle {
                                    id: chip

                                    required property var modelData
                                    readonly property bool active: root.rgbZone === modelData.key

                                    width: chipRow.implicitWidth + 32
                                    height: 40
                                    radius: 20
                                    color: active ? root.secondaryContainer : chipMouse.containsMouse ? root.surfaceContainerHigh : "transparent"
                                    border.width: active ? 0 : 1
                                    border.color: root.outlineVariant

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }

                                    RowLayout {
                                        id: chipRow

                                        anchors.centerIn: parent
                                        spacing: 8

                                        Icon {
                                            text: chip.active ? "check" : chip.modelData.icon
                                            size: 18
                                            color: chip.active ? root.fgOnSecondaryContainer : root.fgVariant
                                        }

                                        Label {
                                            text: chip.modelData.label
                                            weight: Font.Medium
                                            color: chip.active ? root.fgOnSecondaryContainer : root.fg
                                        }
                                    }

                                    MouseArea {
                                        id: chipMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.rgbZone = chip.modelData.key
                                    }
                                }
                            }
                        }

                        GridLayout {
                            visible: root.rgbWorks
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: 12
                            rowSpacing: 12

                            Repeater {
                                model: root.rgbModes

                                LightTile {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    info: modelData
                                }
                            }
                        }

                        Card {
                            Layout.fillWidth: true
                            visible: root.rgbWorks && ["static", "breathing"].includes(root.cur.mode)

                            Label {
                                text: "Colour"
                                size: 16
                                weight: Font.Medium
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 12

                                Repeater {
                                    model: root.swatches

                                    Rectangle {
                                        id: sw

                                        required property string modelData
                                        required property int index
                                        readonly property bool active: root.cur.color.toLowerCase() === modelData.toLowerCase()

                                        width: 44
                                        height: 44
                                        radius: 22
                                        color: modelData
                                        border.width: active ? 3 : 0
                                        border.color: root.fg

                                        Icon {
                                            anchors.centerIn: parent
                                            visible: sw.index === 0
                                            text: "colors"
                                            size: 18
                                            color: Qt.rgba(0, 0, 0, 0.55)
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.setZone({ color: sw.modelData })
                                        }
                                    }
                                }
                            }

                            Label {
                                text: "The first colour is your Caelestia accent colour."
                                size: 12
                                color: root.fgVariant
                            }
                        }

                        Card {
                            Layout.fillWidth: true
                            visible: root.rgbWorks

                            ValueSlider {
                                Layout.fillWidth: true
                                label: "Brightness"
                                unit: "%"
                                from: 5
                                to: 100
                                value: root.rgb.brightness ?? 100
                                onMoved: v => root.saveRgb(Object.assign({}, root.rgb, { brightness: v }))
                            }

                            ValueSlider {
                                Layout.fillWidth: true
                                visible: ["breathing", "wave", "cycle", "smooth", "spiral"].includes(root.cur.mode)
                                label: "Speed"
                                from: 1
                                to: 10
                                value: root.cur.speed
                                onMoved: v => root.setZone({ speed: v })
                            }
                        }
                    }

                    // ---------- Battery & keyboard ----------
                    ColumnLayout {
                        visible: root.page === 2
                        Layout.fillWidth: true
                        spacing: 18

                        PageTitle {
                            text: "Battery & keyboard"
                            sub: "Charging and keyboard options from Lenovo Vantage."
                        }

                        Card {
                            Layout.fillWidth: true

                            SwitchRow {
                                key: "conservation"
                                icon: "battery_saver"
                                label: "Battery conservation"
                                desc: "Stops charging at about 80%. Best when the laptop is usually plugged in, as it slows battery wear."
                            }

                            Divider {}

                            SwitchRow {
                                key: "usb_charging"
                                icon: "usb"
                                label: "Always-on USB charging"
                                desc: "Charge phones and other devices from the USB ports while the laptop is off or asleep."
                            }

                            Divider {}

                            SwitchRow {
                                key: "fn_lock"
                                icon: "keyboard"
                                label: "Fn lock"
                                desc: "F1 to F12 work as function keys without holding Fn (media keys then need Fn)."
                            }
                        }
                    }

                    // ---------- Updates ----------
                    ColumnLayout {
                        visible: root.page === 3
                        Layout.fillWidth: true
                        spacing: 18

                        PageTitle {
                            text: "Updates"
                            sub: "Firmware (BIOS and devices) through fwupd, and your apps and system."
                        }

                        Card {
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Icon {
                                    text: "memory"
                                    size: 26
                                    color: root.primary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: "Firmware"
                                        size: 16
                                        weight: Font.Medium
                                    }

                                    Label {
                                        text: root.fwStatus
                                        color: root.fgVariant
                                        size: 13
                                    }
                                }

                                Button {
                                    text: root.fwChecking ? "Checking…" : "Check for updates"
                                    enabled: !root.fwChecking
                                    onClicked: root.checkFirmware()
                                }

                                Button {
                                    visible: root.fwUpdates.length > 0
                                    filled: true
                                    text: "Install"
                                    onClicked: root.inTerminal("fwupdmgr update")
                                }
                            }

                            Repeater {
                                model: root.fwDevices

                                RowLayout {
                                    id: dev

                                    required property var modelData
                                    readonly property var update: root.fwUpdates.find(u => u.DeviceId === modelData.DeviceId)

                                    Layout.fillWidth: true
                                    Layout.leftMargin: 40
                                    spacing: 12

                                    Label {
                                        Layout.fillWidth: true
                                        text: dev.modelData.Name ?? ""
                                        size: 14
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        text: dev.update ? `${dev.modelData.Version} → ${dev.update.Releases?.[0]?.Version ?? "new"}` : (dev.modelData.Version ?? "")
                                        color: dev.update ? root.primary : root.fgVariant
                                        size: 13
                                    }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                visible: root.fwDevices.length > 0 && !root.fwUpdates.length
                                text: "Lenovo doesn't publish every Legion BIOS for Linux. If a BIOS update shows on Lenovo's site but not here, it needs Windows or Lenovo's own updater."
                                color: root.fgVariant
                                size: 12
                                wrapMode: Text.Wrap
                            }
                        }

                        Card {
                            Layout.fillWidth: true

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Icon {
                                    text: "deployed_code_update"
                                    size: 26
                                    color: root.primary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Label {
                                        text: "Apps and system"
                                        size: 16
                                        weight: Font.Medium
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: root.lastSysUpdate ? `Updated automatically at every boot. Last run: ${root.lastSysUpdate}` : "Updated automatically at every boot."
                                        color: root.fgVariant
                                        size: 13
                                        wrapMode: Text.Wrap
                                    }
                                }

                                Button {
                                    filled: true
                                    text: "Update now"
                                    onClicked: root.inTerminal("sudo pacman -Syu; paru -Sua; flatpak update")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- components ----------
    component Label: Text {
        property real size: 14
        property int weight: Font.Normal

        renderType: Text.NativeRendering
        color: root.fg
        font.family: root.font
        font.pixelSize: size
        font.weight: weight
    }

    component Icon: Text {
        property real size: 22
        property real fill: 0

        renderType: Text.NativeRendering
        font.family: root.iconFont
        font.pixelSize: size
        font.variableAxes: ({ FILL: fill })
        color: root.fg
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    component PageTitle: ColumnLayout {
        property alias text: title.text
        property alias sub: subtitle.text

        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 4

        Label {
            id: title

            size: 28
            weight: Font.Medium
        }

        Label {
            id: subtitle

            Layout.fillWidth: true
            color: root.fgVariant
            wrapMode: Text.Wrap
        }
    }

    component Card: Rectangle {
        default property alias content: inner.data

        implicitHeight: inner.implicitHeight + 40
        radius: 24
        color: root.surfaceContainer

        ColumnLayout {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 14
        }
    }

    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.outlineVariant
        opacity: 0.6
    }

    component NavItem: Rectangle {
        id: nav

        required property int index
        required property string icon
        required property string label
        readonly property bool active: root.page === index

        Layout.fillWidth: true
        implicitHeight: 48
        radius: height / 2
        color: active ? root.secondaryContainer : navMouse.containsMouse ? Qt.alpha(root.fg, 0.06) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            spacing: 14

            Icon {
                text: nav.icon
                fill: nav.active ? 1 : 0
                color: nav.active ? root.fgOnSecondaryContainer : root.fgVariant
            }

            Label {
                Layout.fillWidth: true
                text: nav.label
                weight: nav.active ? Font.Medium : Font.Normal
                color: nav.active ? root.fgOnSecondaryContainer : root.fgVariant
            }
        }

        MouseArea {
            id: navMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.page = nav.index
        }
    }

    component ModeTile: Rectangle {
        id: tile

        required property string profile
        readonly property var info: root.profileInfo[profile]
        readonly property bool active: root.st.profile === profile

        implicitHeight: 132
        radius: 24
        color: active ? root.primaryContainer : tileMouse.containsMouse ? root.surfaceContainerHigh : root.surfaceContainer

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6

            Icon {
                Layout.alignment: Qt.AlignLeft
                text: tile.info.icon
                size: 30
                fill: tile.active ? 1 : 0
                color: tile.active ? root.fgOnPrimaryContainer : root.primary
            }

            Item {
                Layout.fillHeight: true
            }

            Label {
                text: tile.info.label
                size: 16
                weight: Font.Medium
                color: tile.active ? root.fgOnPrimaryContainer : root.fg
            }

            Label {
                Layout.fillWidth: true
                text: tile.info.desc
                size: 12
                color: tile.active ? Qt.alpha(root.fgOnPrimaryContainer, 0.85) : root.fgVariant
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tileMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setValue("profile", tile.profile)
        }
    }

    component SwitchRow: RowLayout {
        id: row

        required property string key
        required property string icon
        required property string label
        required property string desc
        readonly property bool isOn: root.st[key] === "1"
        readonly property bool available: root.st[key] !== null && root.st[key] !== undefined

        Layout.fillWidth: true
        spacing: 16
        opacity: available ? 1 : 0.5

        Icon {
            text: row.icon
            size: 24
            color: root.primary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                text: row.label
                size: 15
                weight: Font.Medium
            }

            Label {
                Layout.fillWidth: true
                text: row.desc
                size: 13
                color: root.fgVariant
                wrapMode: Text.Wrap
            }
        }

        // Material 3 switch
        Rectangle {
            implicitWidth: 52
            implicitHeight: 32
            radius: 16
            color: row.isOn ? root.primary : root.surfaceContainerHighest
            border.width: row.isOn ? 0 : 2
            border.color: root.outline

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Rectangle {
                property real knob: row.isOn ? 24 : 16

                x: row.isOn ? parent.width - width - 4 : 8
                anchors.verticalCenter: parent.verticalCenter
                width: knob
                height: knob
                radius: knob / 2
                color: row.isOn ? root.fgOnPrimary : root.outline

                Behavior on x {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }

                Behavior on knob {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: row.available
                onClicked: root.setValue(row.key, row.isOn ? "0" : "1")
            }
        }
    }

    component AttrSlider: ColumnLayout {
        id: sl

        required property string key
        readonly property var a: root.st.attrs?.[key] ?? {}
        readonly property var info: root.attrInfo[key] ?? { label: a.name ?? key, unit: "" }
        readonly property real lo: Number(a.min)
        readonly property real hi: Number(a.max)
        readonly property real stepSize: Math.max(1, Number(a.step) || 1)
        readonly property bool editable: root.st.profile === "custom"
        property real shown: Number(a.value)
        property bool dragging

        onAChanged: if (!dragging) shown = Number(a.value)

        Layout.fillWidth: true
        spacing: 6
        opacity: editable ? 1 : 0.55

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: sl.info.label
                size: 14
            }

            Label {
                text: `${Math.round(sl.shown)} ${sl.info.unit}`
                size: 14
                weight: Font.Medium
                color: root.primary
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 28

            readonly property real frac: sl.hi > sl.lo ? (sl.shown - sl.lo) / (sl.hi - sl.lo) : 0

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: root.surfaceContainerHighest
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(8, parent.frac * parent.width)
                height: 8
                radius: 4
                color: root.primary
            }

            Rectangle {
                x: parent.frac * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 28
                radius: 3
                color: root.primary
            }

            MouseArea {
                anchors.fill: parent
                enabled: sl.editable
                cursorShape: Qt.PointingHandCursor

                function valueAt(x: real): real {
                    const f = Math.max(0, Math.min(1, x / width));
                    return Math.round((sl.lo + f * (sl.hi - sl.lo)) / sl.stepSize) * sl.stepSize;
                }

                onPressed: event => {
                    sl.dragging = true;
                    sl.shown = valueAt(event.x);
                }
                onPositionChanged: event => sl.shown = valueAt(event.x)
                onReleased: {
                    sl.dragging = false;
                    root.setValue(`attr:${sl.key}`, String(Math.round(sl.shown)));
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: `${sl.lo} ${sl.info.unit}`
                size: 11
                color: root.fgVariant
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                text: `${sl.hi} ${sl.info.unit}`
                size: 11
                color: root.fgVariant
            }
        }
    }

    component LightTile: Rectangle {
        id: lt

        required property var info
        readonly property bool active: root.cur.mode === info.mode

        implicitHeight: 118
        radius: 24
        color: active ? root.primaryContainer : ltMouse.containsMouse ? root.surfaceContainerHigh : root.surfaceContainer

        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 2

            Icon {
                Layout.alignment: Qt.AlignLeft
                Layout.bottomMargin: 6
                text: lt.info.icon
                size: 28
                fill: lt.active ? 1 : 0
                color: lt.active ? root.fgOnPrimaryContainer : root.primary
            }

            Item {
                Layout.fillHeight: true
            }

            Label {
                Layout.fillWidth: true
                text: lt.info.label
                size: 15
                weight: Font.Medium
                color: lt.active ? root.fgOnPrimaryContainer : root.fg
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                text: lt.info.desc
                size: 12
                color: lt.active ? Qt.alpha(root.fgOnPrimaryContainer, 0.85) : root.fgVariant
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: ltMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setZone({ mode: lt.info.mode })
        }
    }

    component ValueSlider: ColumnLayout {
        id: vs

        property string label
        property string unit
        property real from: 0
        property real to: 100
        property real value: 0
        property real shown: value
        property bool dragging

        signal moved(real v)

        onValueChanged: if (!dragging) shown = value

        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: vs.label
            }

            Label {
                text: `${Math.round(vs.shown)}${vs.unit}`
                weight: Font.Medium
                color: root.primary
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 28

            readonly property real frac: (vs.shown - vs.from) / Math.max(1, vs.to - vs.from)

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: root.surfaceContainerHighest
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(8, parent.frac * parent.width)
                height: 8
                radius: 4
                color: root.primary
            }

            Rectangle {
                x: parent.frac * (parent.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 28
                radius: 3
                color: root.primary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                function valueAt(x: real): real {
                    const f = Math.max(0, Math.min(1, x / width));
                    return Math.round(vs.from + f * (vs.to - vs.from));
                }

                onPressed: event => {
                    vs.dragging = true;
                    vs.shown = valueAt(event.x);
                }
                onPositionChanged: event => vs.shown = valueAt(event.x)
                onReleased: {
                    vs.dragging = false;
                    vs.moved(vs.shown);
                }
            }
        }
    }

    component Button: Rectangle {
        id: btn

        property string text
        property bool filled

        signal clicked

        implicitWidth: btnLabel.implicitWidth + 40
        implicitHeight: 40
        radius: 20
        opacity: enabled ? 1 : 0.6
        color: filled ? (btnMouse.containsMouse ? Qt.lighter(root.primary, 1.08) : root.primary) : (btnMouse.containsMouse ? root.surfaceContainerHighest : root.surfaceContainerHigh)

        Label {
            id: btnLabel

            anchors.centerIn: parent
            text: btn.text
            weight: Font.Medium
            color: btn.filled ? root.fgOnPrimary : root.fg
        }

        MouseArea {
            id: btnMouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
