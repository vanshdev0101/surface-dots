import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as Lib

// Standalone popup, same pattern as WifiMenu.qml. Right-click the bar's
// Bluetooth pill opens this instead of the old rfkill-toggle-only + external
// blueman-manager combo -- real device list, connect/disconnect/pair/forget,
// all in the same visual language as the rest of the shell.

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    screen: {
        const want = Quickshell.env("BTMENU_SCREEN") || ""
        for (var i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === want) return Quickshell.screens[i]
        for (var j = 0; j < Quickshell.screens.length; j++)
            if (Quickshell.screens[j].name !== "eDP-1") return Quickshell.screens[j]
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.namespace: "bluetooth-menu"

    focusable: true
    Shortcut { sequence: "Esc"; onActivated: Qt.quit() }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: (mouse) => {
            const inside = mouse.x >= card.x && mouse.x <= (card.x + card.width) &&
                           mouse.y >= card.y && mouse.y <= (card.y + card.height)
            if (!inside) Qt.quit()
        }
    }

    // -------- Theme (mirrors WifiMenu.qml's local palette) --------
    readonly property string themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"
    property bool isDarkMode: true

    FileView {
        path: root.themeModePath
        watchChanges: true
        preload: true
        onLoaded: root.isDarkMode = (text().trim() !== "light")
        onTextChanged: root.isDarkMode = (text().trim() !== "light")
        onFileChanged: reload()
        onLoadFailed: root.isDarkMode = true
    }
    // Same cascade ThemeEngine.qml/WifiMenu.qml use: every role derives from
    // customBg/customAccent's own hue+saturation, so wallpaper-derived
    // accents (and the Monochrome preset, zero-saturation customBg/Accent)
    // reach this menu too instead of a fixed palette.
    readonly property bool  useCustom: Lib.Configuration.useCustomColors
    readonly property color _bg:  Lib.Configuration.customBg
    readonly property color _acc: Lib.Configuration.customAccent
    readonly property bool  _bgIsDark: _bg.hslLightness < 0.5
    function _clampL(v) { return Math.max(0, Math.min(1, v)) }

    readonly property color cCard:   useCustom ? Qt.hsla(_bg.hslHue, _bg.hslSaturation, _clampL(_bg.hslLightness + (_bgIsDark ? 0.04 : -0.05)), 1.0) : (isDarkMode ? "#282c2d" : "#c1c3ae")
    readonly property color cItem:   useCustom ? Qt.hsla(_bg.hslHue, _bg.hslSaturation * 0.9, _clampL(_bg.hslLightness + (_bgIsDark ? 0.11 : -0.10)), 1.0) : (isDarkMode ? "#323738" : "#b3b59e")
    readonly property color cItemHv: useCustom ? Qt.hsla(_bg.hslHue, _bg.hslSaturation * 0.85, _clampL(_bg.hslLightness + (_bgIsDark ? 0.16 : -0.15)), 1.0) : (isDarkMode ? "#3c4243" : "#a5a891")
    readonly property color cFg:     useCustom ? Qt.hsla(_acc.hslHue, Math.min(0.18, _acc.hslSaturation * 0.35), _bgIsDark ? 0.88 : 0.18, 1.0) : (isDarkMode ? "#D3C6AA" : "#1e2326")
    readonly property color cMuted:  useCustom ? Qt.hsla(_acc.hslHue, Math.min(0.12, _acc.hslSaturation * 0.25), _bgIsDark ? 0.68 : 0.32, 1.0) : (isDarkMode ? "#859289" : "#4d6049")
    readonly property color cBorder: useCustom ? Qt.rgba(_acc.r, _acc.g, _acc.b, 0.5) : (isDarkMode ? "#d4708154" : "#d4586a3c")
    readonly property color cGreen:  useCustom ? _acc : (isDarkMode ? "#A7C080" : "#576830")
    readonly property color cRed:    isDarkMode ? "#E67E80" : "#b13c3a"
    readonly property int   cRadius: 14
    readonly property string fontText: "Inter"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"

    // -------- State --------
    property bool powered: false
    property bool scanning: false
    property string busyMac: ""
    property var devices: []   // [{mac, name, paired, connected}]

    function iconFor(name) {
        var n = (name || "").toLowerCase()
        if (n.includes("buds") || n.includes("headphone") || n.includes("headset") || n.includes("airpod")) return "󰋋"
        if (n.includes("mouse")) return "󰍽"
        if (n.includes("keyboard")) return "󰌌"
        if (n.includes("speaker")) return "󰓃"
        if (n.includes("watch")) return "󰥔"
        if (n.includes("phone")) return ""
        return "󰂯"
    }

    function parseDeviceLines(text) {
        var out = {}
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/)
            if (m) out[m[1]] = m[2].trim()
        }
        return out
    }

    Process {
        id: statusPoll
        command: ["bash", "-c", `
            bluetoothctl show | grep -q "Powered: yes" && echo "POWERED:1" || echo "POWERED:0"
            echo "===ALL==="
            bluetoothctl devices
            echo "===PAIRED==="
            bluetoothctl devices Paired
            echo "===CONNECTED==="
            bluetoothctl devices Connected
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var chunks = text.split("===")
                // chunks[0] = "POWERED:x\n", then alternating "ALL===\n<data>", "PAIRED===\n<data>"...
                var head = chunks[0] || ""
                root.powered = head.includes("POWERED:1")

                var all = {}, paired = {}, connected = {}
                for (var i = 1; i < chunks.length; i += 2) {
                    var label = chunks[i]
                    var body = chunks[i + 1] || ""
                    if (label === "ALL") all = root.parseDeviceLines(body)
                    else if (label === "PAIRED") paired = root.parseDeviceLines(body)
                    else if (label === "CONNECTED") connected = root.parseDeviceLines(body)
                }

                var list = []
                for (var mac in all) {
                    list.push({
                        mac: mac,
                        name: all[mac],
                        paired: !!paired[mac],
                        connected: !!connected[mac]
                    })
                }
                list.sort(function(a, b) {
                    if (a.connected !== b.connected) return a.connected ? -1 : 1
                    if (a.paired !== b.paired) return a.paired ? -1 : 1
                    return a.name.localeCompare(b.name)
                })
                root.devices = list
            }
        }
    }

    Timer {
        interval: 3000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: if (!statusPoll.running) statusPoll.running = true
    }

    function togglePower() {
        root.powered = !root.powered
        Quickshell.execDetached(["bash", "-c", "bluetoothctl power " + (root.powered ? "on" : "off")])
    }

    function toggleConnect(dev) {
        root.busyMac = dev.mac
        var cmd = dev.connected
            ? "bluetoothctl disconnect " + dev.mac
            : (dev.paired
                ? "bluetoothctl connect " + dev.mac
                : "bluetoothctl pair " + dev.mac + " && bluetoothctl trust " + dev.mac + " && bluetoothctl connect " + dev.mac)
        Quickshell.execDetached(["bash", "-c", cmd + "; sleep 1"])
        busyResetTimer.restart()
    }
    Timer { id: busyResetTimer; interval: 4000; onTriggered: root.busyMac = "" }

    function forget(dev) {
        Quickshell.execDetached(["bash", "-c", "bluetoothctl remove " + dev.mac])
    }

    function toggleScan() {
        root.scanning = !root.scanning
        if (root.scanning) {
            Quickshell.execDetached(["bash", "-c", "timeout 10 bluetoothctl scan on"])
            scanStopTimer.restart()
        } else {
            Quickshell.execDetached(["bash", "-c", "bluetoothctl scan off"])
        }
    }
    Timer { id: scanStopTimer; interval: 10000; onTriggered: root.scanning = false }

    Rectangle {
        id: card
        width: 340
        height: Math.ceil(mainLayout.implicitHeight + 24)
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 14
        anchors.topMargin: 52
        color: cCard
        radius: cRadius
        border.width: 1
        border.color: cBorder
        clip: true

        Component.onCompleted: forceActiveFocus()

        ColumnLayout {
            id: mainLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Bluetooth"
                    color: root.cFg
                    font.family: root.fontText; font.pixelSize: 14; font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 40; height: 22; radius: 11
                    color: root.powered ? root.cGreen : root.cItem
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle {
                        x: root.powered ? parent.width - width - 3 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16; radius: 8; color: "white"
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePower() }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.cBorder; opacity: 0.5 }

            RowLayout {
                Layout.fillWidth: true
                visible: root.powered
                Text {
                    text: root.scanning ? "Scanning…" : "Devices"
                    color: root.cMuted
                    font.family: root.fontText; font.pixelSize: 11
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: scanLabel.implicitWidth + 16; height: 24; radius: 8
                    color: scanHov.hovered ? root.cItemHv : root.cItem
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: scanLabel
                        anchors.centerIn: parent
                        text: root.scanning ? "Stop" : "Scan"
                        color: root.cFg
                        font.family: root.fontText; font.pixelSize: 11
                    }
                    MouseArea { id: scanHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleScan() }
                }
            }

            Text {
                visible: !root.powered
                text: "Bluetooth is off"
                color: root.cMuted
                font.family: root.fontText; font.pixelSize: 12
                Layout.topMargin: 4; Layout.bottomMargin: 4
            }

            Text {
                visible: root.powered && root.devices.length === 0
                text: "No devices found -- try Scan"
                color: root.cMuted
                font.family: root.fontText; font.pixelSize: 12
                opacity: 0.8
                Layout.topMargin: 4; Layout.bottomMargin: 4
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.powered
                spacing: 4

                Repeater {
                    model: root.devices
                    delegate: Rectangle {
                        id: devRow
                        required property var modelData
                        readonly property bool isBusy: root.busyMac === modelData.mac

                        Layout.fillWidth: true
                        height: 44
                        radius: 10
                        color: rowHov.hovered ? root.cItemHv : root.cItem

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 8

                            Text {
                                text: root.iconFor(devRow.modelData.name)
                                font.family: root.fontIcon; font.pixelSize: 16
                                color: devRow.modelData.connected ? root.cGreen : root.cMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: devRow.modelData.name
                                    color: root.cFg
                                    font.family: root.fontText; font.pixelSize: 12; font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: devRow.isBusy ? "Working…"
                                        : devRow.modelData.connected ? "Connected"
                                        : devRow.modelData.paired ? "Paired" : "Available"
                                    color: devRow.modelData.connected ? root.cGreen : root.cMuted
                                    font.family: root.fontText; font.pixelSize: 10
                                }
                            }

                            Rectangle {
                                width: btnLabel.implicitWidth + 14; height: 24; radius: 8
                                color: devRow.modelData.connected ? Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.18) : root.cGreen
                                opacity: devRow.isBusy ? 0.5 : 1.0
                                Text {
                                    id: btnLabel
                                    anchors.centerIn: parent
                                    text: devRow.modelData.connected ? "Disconnect" : devRow.modelData.paired ? "Connect" : "Pair"
                                    color: devRow.modelData.connected ? root.cRed : "#232a2e"
                                    font.family: root.fontText; font.pixelSize: 10; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !devRow.isBusy
                                    onClicked: root.toggleConnect(devRow.modelData)
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onPressed: (m) => { if (m.button === Qt.RightButton) root.forget(devRow.modelData) }
                                }
                            }
                        }

                        MouseArea { id: rowHov; anchors.fill: parent; hoverEnabled: true; z: -1 }
                    }
                }
            }

            Text {
                visible: root.powered && root.devices.length > 0
                text: "Right-click a device to forget it"
                color: root.cMuted
                font.family: root.fontText; font.pixelSize: 10
                opacity: 0.6
                Layout.topMargin: 2
            }
        }
    }
}
