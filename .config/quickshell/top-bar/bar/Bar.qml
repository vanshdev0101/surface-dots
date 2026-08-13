import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Hyprland

import "../lib" as Lib
import "../lib/iconmap.js" as IconMap

PanelWindow {
    id: win
    signal requestHubToggle()

    anchors { top: true; left: true; right: true }
    implicitHeight: Lib.Configuration.barExclusiveZone
    color: "transparent"

    // 1. GLOBAL STATE 
    // Theme mode: default is always dark, false will activate light mode
    property bool isDarkMode: true
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"
    FileView {
        id: themeModeFile
        path: win._themeModePath
        watchChanges: true
        preload: true
        // Update local property when file loads or changes
        onLoaded: {
            var m = String(text() || "").trim().toLowerCase()
            win.isDarkMode = (m !== "light")
        }
        onTextChanged: {
             var m = String(text() || "").trim().toLowerCase()
             win.isDarkMode = (m !== "light")
        }
        onFileChanged: reload()
    }
//--------------------------------------------------------------------------------
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: Lib.Configuration.barExclusiveZone
    WlrLayershell.namespace: "shell-bar"
//--------------------------------------------------------------------------------
    function sh(cmd) { return ["bash", "-c", cmd] }
    function det(cmd) { Quickshell.execDetached(sh(cmd)) }

    // get active workspace ID 
    property int activeWsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1

    // 2. THEME
    QtObject {
        id: barPalette
        property color bg: win.isDarkMode ? Qt.rgba(0.23, 0.25, 0.22, 0.25) : '#edc5c6b0'
        property color textPrimary: win.isDarkMode ? "#d5c9b2" : "#1e2326"
        property color textSecondary: win.isDarkMode ? "#6a6f75" : "#5c6a72"
        property color accent: Lib.Configuration.useCustomColors ? Lib.Configuration.customAccent : (win.isDarkMode ? "#a7c080" : "#273018")
        property color activePill: Lib.Configuration.useCustomColors ? Lib.Configuration.customAccent : (win.isDarkMode ? "#a7c080" : "#87C080")
        property color hoverSpotlight: win.isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.10)
        property color border: win.isDarkMode ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.1)

        property color hoverPillG0: win.isDarkMode ? Qt.rgba(167/255, 192/255, 128/255, 0.15) : Qt.rgba(39/255, 48/255, 24/255, 0.14)
        property color hoverPillG1: win.isDarkMode ? Qt.rgba(230/255, 255/255, 200/255, 0.25) : Qt.rgba(39/255, 48/255, 24/255, 0.22)
        property color hoverPillG2: win.isDarkMode ? Qt.rgba(167/255, 192/255, 128/255, 0.15) : Qt.rgba(39/255, 48/255, 24/255, 0.14)
    }

    // 2b. THEME ENGINE (font & sizing constants for the bar)
    Lib.ThemeEngine {
        id: barTheme
        isDarkMode: win.isDarkMode
    }

    // 3. HYPRLAND CACHE
    QtObject {
        id: hyCache
        property var wsMap: ({}) // wsId
        property bool pending: false

        function rebuild() {
            const m = {}
            const list = Hyprland.toplevels?.values ?? []
            for (const tl of list) {
                const id = tl?.workspace?.id
                if (!id) continue
                if (!m[id]) m[id] = []
                m[id].push(tl)
            }
            wsMap = m
        }

        // Collapses burst events into 1 rebuild per frame
        function scheduleRebuild() {
            if (pending) return
            pending = true
            Qt.callLater(() => {
                pending = false
                rebuild()
            })
        }

        Component.onCompleted: rebuild()
    }

    // 4. HYPR POLLERS
    Timer {
        interval: 500
        running: true; repeat: false
        onTriggered: hyCache.rebuild()
    }

    // Safety Check at 2s
    Timer {
        interval: 2000
        running: true; repeat: false
        onTriggered: hyCache.rebuild()
    }

    // 5. Event Listener + scheduleRebuild)
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || !ev.name) return

            // Check for events
            if (ev.name === "openwindow" || ev.name === "closewindow" ||
                ev.name === "movewindowv2" || ev.name === "urgent") {

                // Re-fetch the window list from Hyprland immediately
                Hyprland.refreshToplevels()
                hyCache.scheduleRebuild()
            }
        }
    }

    // POLLERS
    // 6.2 BATTERY %, STATUS POLLER
    Lib.CommandPoll {
        id: powerPoll
        interval: {
            const s = String(batStatus.value ?? "").trim()
            const cap = Number(batCap.value ?? 0)
            if (s === "Discharging" && cap <= 20) return 2000
            return 6000
        }
        command: ["bash","-lc", `
            cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
            status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)
            ac=$(cat /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online 2>/dev/null | head -n1)
            echo "$cap|$status|$ac"
        `]
        parse: function(o) {
            var s = String(o ?? "").trim()
            var p = s.split("|")
            return { cap: Number(p[0]) || 0, status: (p[1] || "").trim(), ac: (p[2] || "").trim() }
        }
    }

    // 6.2.1 Battery Notifications
    QtObject {
        id: batLogic
        property bool f20: false
        property bool f10: false

        function check(cap, status) {
            if (status !== "Discharging") {
                f20 = false; f10 = false; return
            }
            if (cap === 0) return
            // Critical 10%
            if (cap <= 10 && !f10) {
                win.det("notify-send -u critical 'Battery Critically Low' 'Please Plug in your Charger'")
                f10 = true; f20 = true
            // Warning 20%
            } else if (cap <= 20 && cap > 10 && !f20) {
                win.det("notify-send 'Battery Low' 'Please Plug in your Charger'")
                f20 = true
            }
        }
    }
    QtObject {
        id: batCap
        property var value: (powerPoll.value ? powerPoll.value.cap : 0)
        onValueChanged: batLogic.check(value, batStatus.value)
    }
    QtObject {
        id: batStatus
        property var value: (powerPoll.value ? powerPoll.value.status : "")
        onValueChanged: batLogic.check(batCap.value, value)
    }
    QtObject { id: acOnline; property var value: (powerPoll.value ? powerPoll.value.ac : "") }

    // --- WIFI ---
    Lib.CommandPoll {
        id: wifiOn
        interval: 2500
        command: win.sh("nmcli -t -f WIFI g 2>/dev/null | head -n1 || true")
        parse: function(o) { return String(o).trim() === "enabled" }
    }
    Lib.CommandPoll {
        id: wifiSSID
        interval: 2500
        command: win.sh("nmcli -t -f NAME,TYPE c show --active 2>/dev/null | awk -F: '$2 ~ /wireless/ {print $1; exit}' || true")
        parse: function(o) { return String(o).trim() }
    }

    // --- RAM ---
    Lib.CommandPoll {
        id: ramPoll
        interval: 5000
        command: win.sh("awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.0f\", (t-a)/t*100}' /proc/meminfo")
        parse: function(o) {
            var n = parseInt(String(o).trim())
            return isFinite(n) ? n : 0
        }
    }

    // --- ICON MAP (shared with Dock.qml) ---
    function getIcon(cls) { return IconMap.getIcon(cls) }
// ------------------ THE BAR ---------------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: win.isDarkMode ? Qt.rgba(20/255, 23/255, 25/255, 0.92) : barPalette.bg

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 14
// LEFT----------------------------------------------------------------------------------------------------------

            // 7. LAUNCHER
            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                scale: launchPress.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                HoverHandler { id: hoverLaunch }
                
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(launchIcon.color.r, launchIcon.color.g, launchIcon.color.b, 1)
                    opacity: launchPress.pressed ? 0.10 : (hoverLaunch.hovered ? 0.08 : 0.0)
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Item {
                    id: launchIcon
                    anchors.centerIn: parent
                    width: 22; height: 22
                    property color color: {
                        if (hoverLaunch.hovered) return win.isDarkMode ? "#89b4fa" : "#1e66f5"
                        return win.isDarkMode ? "#89b4fa" : "#1e66f5"
                    }

                    Image { 
                        id: lImg
                        source: "../lib/arch.svg"
                        visible: false
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        // Rasterize at 2x (44px) relative to container (22px)
                        sourceSize: Qt.size(44, 44)
                        smooth: false
                    }
                    ColorOverlay {
                        anchors.fill: parent
                        source: lImg
                        color: parent.color
                        cached: true
                        antialiasing: true
                    }
                    rotation: hoverLaunch.hovered ? -14 : 0
                    scale: hoverLaunch.hovered ? 1.20 : 1.0
                    y: hoverLaunch.hovered ? -2 : 0
                    Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                MouseArea {
                    id: launchPress
                    anchors.fill: parent
                    hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) win.det("pkill -x rofi || " + (win.isDarkMode ? "~/.config/rofi/launcher.sh" : "~/.config/rofi/launcher_2.sh"))
                        else if (mouse.button === Qt.RightButton) {
                            win.isDarkMode = !win.isDarkMode
                            win.det("bash /home/vanshc/.config/quickshell/top-bar/bar/theme-mode.sh " + (win.isDarkMode ? "dark" : "light"))
                        }
                    }
                }
            }

            // 8. WORKSPACES
            Rectangle {
                id: wsContainer
                Layout.preferredHeight: 34
                Layout.preferredWidth: wsRow.width + 22
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                color: barPalette.bg
                clip: true
                property int hoveredId: 0
                property var hoveredItem: (hoveredId > 0) ? wsRepeater.itemAt(hoveredId - 1) : null
                property int pressedId: 0
                property var pressedItem: (pressedId > 0) ? wsRepeater.itemAt(pressedId - 1) : null

                // ACTIVE PILL
                Rectangle {
                    id: activePill
                    property int currentId: win.activeWsId
                    property var targetItem: wsRepeater.itemAt(currentId - 1)
                    x: targetItem ? (wsRow.x + targetItem.x) : 0
                    width: targetItem ? targetItem.width : 0
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 13
                    color: barPalette.activePill
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                }

                // HOVER PILL
                Item {
                    id: hoverPillLayer
                    anchors.fill: parent
                    visible: wsContainer.hoveredId > 0 && wsContainer.hoveredId !== win.activeWsId
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Rectangle {
                        property var t: wsContainer.hoveredItem
                        x: t ? (wsRow.x + t.x) : 0; width: t ? t.width : 0; height: 25
                        anchors.verticalCenter: parent.verticalCenter; radius: 13
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: barPalette.hoverPillG0 }
                            GradientStop { position: 0.45; color: barPalette.hoverPillG1 }
                            GradientStop { position: 1.0; color: barPalette.hoverPillG2 }
                        }
                        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.10 } }
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    }
                }

                Item {
                    id: pressPillLayer
                    anchors.fill: parent
                    visible: wsContainer.pressedId > 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                    Rectangle {
                        property var t: wsContainer.pressedItem
                        x: t ? (wsRow.x + t.x) : 0
                        width: t ? t.width : 0
                        height: 25
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 13
                        color: Qt.rgba(barPalette.textPrimary.r, barPalette.textPrimary.g, barPalette.textPrimary.b, 1)
                        opacity: 0.10
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        id: wsRepeater
                        model: 10
                        Item {
                            id: wsDelegate
                            property int wsId: index + 1
                            property bool isActive: win.activeWsId === wsId

                            // --- READ FROM CACHE ---
                            property var wsWindows: hyCache.wsMap[wsId] ?? []
                            property int winCount: wsWindows.length
                            property bool hasWindows: winCount > 0
                            property bool isUrgent: wsWindows.some(tl => tl.urgent)

                            width: hasWindows ? (winCount * 22 + 12) : 26
                            height: 34

                            HoverHandler {
                                id: wsHover
                                onHoveredChanged: {
                                    if (hovered) wsContainer.hoveredId = wsId
                                    else if (wsContainer.hoveredId === wsId) wsContainer.hoveredId = 0
                                }
                            }

                            y: wsPress.pressed ? 1 : ((!isActive && wsHover.hovered) ? -2 : 0)
                            scale: (wsPress.pressed ? 0.96 : 1.0) * ((!isActive && wsHover.hovered) ? 1.10 : 1.0)
                            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                            Text {
                                anchors.centerIn: parent
                                visible: !wsDelegate.hasWindows
                                text: "•"
                                font.family: barTheme.iconFont; font.pixelSize: 14; lineHeight: 0.8
                                verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 140 } }
                                color: isActive ? "#2d353b" : (wsHover.hovered ? (win.isDarkMode ? "#f2f2f2" : barPalette.accent) : (win.isDarkMode ? "#d5c9b2" : "#5c6a72"))
                            }

                            Row {
                                anchors.centerIn: parent; spacing: 0
                                visible: wsDelegate.hasWindows
                                Repeater {
                                    model: wsDelegate.wsWindows
                                    Item {
                                        width: 22; height: 22

                                        // --- ipc ---
                                        property string safeClass: {
                                            const o = modelData?.lastIpcObject;
                                            var c = o?.class ?? "";
                                            if (!c) c = o?.initialClass ?? "";
                                            if (!c) c = o?.initialTitle ?? "";
                                            if (!c) c = modelData?.title ?? "";
                                            return String(c);
                                        }

                                        QtObject {
                                            id: flashColor
                                            property color val: win.isDarkMode ? "#d5c9b2" : "#1e2326"
                                            SequentialAnimation on val {
                                                running: modelData.urgent
                                                loops: Animation.Infinite
                                                ColorAnimation { to: "#e67e80"; duration: 200 }
                                                ColorAnimation { to: "#dbbc7f"; duration: 200 }
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: win.getIcon(parent.safeClass)
                                            font.family: barTheme.iconFont; font.pixelSize: 18; lineHeight: 0.8
                                            verticalAlignment: Text.AlignVCenter
                                            font.hintingPreference: Font.PreferNoHinting
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.mipmap: true
                                            Behavior on color { enabled: !modelData.urgent; ColorAnimation { duration: 140 } }
                                            scale: (wsDelegate.isActive && wsHover.hovered) ? 1.25 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                                            color: wsDelegate.isActive ? "#2d353b" :
                                                   (modelData.urgent ? flashColor.val :
                                                   (wsHover.hovered ? (win.isDarkMode ? "#f2f2f2" : barPalette.accent) :
                                                   (win.isDarkMode ? "#d5c9b2" : "#1e2326")))
                                        }

                                    }
                                }
                            }
                            MouseArea {
                                id: wsPress
                                anchors.fill: parent
                                hoverEnabled: true
                                onPressed: wsContainer.pressedId = wsId
                                onReleased: if (wsContainer.pressedId === wsId) wsContainer.pressedId = 0
                                onCanceled: if (wsContainer.pressedId === wsId) wsContainer.pressedId = 0
                                onClicked: det("hyprctl dispatch 'hl.dsp.focus({ workspace = " + wsId + " })'")
                            }
                        }
                    }
                }
            }
//------------------------------------------------- CENTER -----------------------------------------------------

            // 9. (spacer -- keeps LEFT/RIGHT pushed apart)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
            }

//----------------------------------------------------------------------------------------RIGHT----------

            // 11. TRAY
            Rectangle {
                visible: SystemTray.items.length > 0
                height: 30
                width: (SystemTray.items.length * 28) + 12
                radius: 15
                color: barPalette.bg
                border.width: 1
                border.color: barPalette.border
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Repeater {
                        model: SystemTray.items
                        Item {
                            width: 20; height: 20
                            scale: trayPress.pressed ? 0.94 : (trayPress.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: barPalette.hoverSpotlight
                                opacity: trayPress.pressed ? 1.0 : (trayPress.containsMouse ? 0.8 : 0.0)
                                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            }

                            Image { anchors.centerIn: parent; width: 16; height: 16; source: modelData.icon }
                            MouseArea {
                                id: trayPress
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => modelData.activate(mouse.button)
                                onPressed: (mouse) => { if (mouse.button === Qt.RightButton) modelData.menu.open(this) }
                            }
                        }
                    }
                }
            }

            // 11b. WIFI  (left-click toggles radio, right-click opens the network menu)
            BarItem {
                property bool on: Boolean(wifiOn.value)
                property string ssid: String(wifiSSID.value || "")

                icon: on ? "󰖩" : "󰖪"
                text: on ? (ssid !== "" ? ssid : "WiFi") : "Off"
                bgColor: barPalette.bg
                iconColor: on ? barPalette.textPrimary : barPalette.textSecondary
                textColor: iconColor
                borderWidth: 0; borderColor: "transparent"; hoverColor: barPalette.hoverSpotlight

                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton)
                        win.det("WIFIMENU_SCREEN=" + (win.screen ? win.screen.name : "")
                                + " quickshell -p ~/.config/quickshell/top-bar/lib/WifiMenu.qml")
                    else
                        win.det("nmcli radio wifi " + (on ? "off" : "on"))
                }
            }

            // 11c. RAM
            BarItem {
                property int usedPct: Number(ramPoll.value) || 0
                property string ramColor: usedPct >= 90 ? (win.isDarkMode ? "#ff0004" : "#ff001e")
                    : usedPct >= 75 ? (win.isDarkMode ? "#e69875" : "#a55524")
                    : barPalette.textPrimary

                icon: "󰍛"; text: usedPct + "%"
                bgColor: barPalette.bg; iconColor: ramColor; textColor: ramColor
                borderWidth: 0; borderColor: "transparent"; hoverColor: barPalette.hoverSpotlight
            }

            // 12. BATTERY
            BarItem {
                id: battItem
                Layout.preferredWidth: 74
                property string status: String(batStatus.value).trim()
                property int rawCap: Number(batCap.value) || 0
                property int cap: (rawCap === 0 && status !== "Discharging") ? 50 : rawCap
                property bool plugged: (String(acOnline.value).trim() === "1")
                property bool isCharging: plugged || status === "Charging" || status === "Full"

                property string battColor: {
                    const dark = win.isDarkMode;
                    if (isCharging) return barPalette.accent;
                    const crit = dark ? '#ff0004' : '#ff001e';
                    const low  = dark ? "#e69875" : '#a55524';
                    const mid  = dark ? "#dbbc7f" : "#7a5b00";
                    if (cap <= 10) return crit;
                    if (cap <= 20) return low;
                    if (cap <= 30) return mid;
                    return barPalette.textPrimary;
                }
                property string dynamicIcon: {
                    if (isCharging) return "󰂄"
                    if (cap >= 98) return "󰁹"
                    if (cap >= 90) return "󰂂"; if (cap >= 80) return "󰂁"
                    if (cap >= 70) return "󰂀"; if (cap >= 60) return "󰁿"
                    if (cap >= 50) return "󰁾"; if (cap >= 40) return "󰁽"
                    if (cap >= 30) return "󰁼"; if (cap >= 20) return "󰁻"
                    return "󰁺"
                }

                icon: dynamicIcon; text: cap + "%"
                bgColor: barPalette.bg; iconColor: battColor; textColor: battColor
                borderWidth: 0; borderColor: "transparent"; hoverColor: barPalette.hoverSpotlight

                SequentialAnimation {
                    running: battItem.cap <= 10 && !battItem.isCharging
                    loops: Animation.Infinite
                    NumberAnimation { target: battItem; property: "opacity"; to: 0.3; duration: 500 }
                    NumberAnimation { target: battItem; property: "opacity"; to: 1.0; duration: 500 }
                }

                Rectangle {
                    id: powerSurge
                    anchors.centerIn: parent; width: parent.width; height: parent.height
                    radius: parent.height / 2; color: "transparent"
                    border.width: 0; border.color: "transparent"
                    opacity: 0; scale: 1.0
                }
                onPluggedChanged: if (plugged) surgeAnim.restart()
                ParallelAnimation {
                    id: surgeAnim
                    NumberAnimation { target: powerSurge; property: "scale"; from: 1.0; to: 1.45; duration: 520; easing.type: Easing.OutCubic }
                    NumberAnimation { target: powerSurge; property: "opacity"; from: 1.0; to: 0.0; duration: 520; easing.type: Easing.OutCubic }
                }
            }

            // 13. CLOCK/DATE
            Item {
                id: clockContainer
                Layout.preferredHeight: 34
                Layout.preferredWidth: clockRow.implicitWidth + 30
                
                scale: clockArea.pressed ? 0.98 : (clockArea.containsMouse ? 1.02 : 1.0)
                y: clockArea.pressed ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                // MASKED BACKGROUND LAYER 
                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: clockMask }

                    Rectangle {
                        anchors.fill: parent
                        color: barPalette.bg
                    }

                    // Shimmer 
                    Rectangle {
                        id: clockShimmer
                        width: 44; height: parent.height * 2; rotation: 20
                        x: -100; y: -parent.height/2
                        color: "transparent"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: win.isDarkMode ? Qt.rgba(1,1,1,0.20) : Qt.rgba(0,0,0,0.1) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: win.isDarkMode ? "#ffffff" : "#000000"
                        opacity: clockArea.pressed ? 0.18 : (clockArea.containsMouse ? 0.12 : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                // Mask Source (Hidden)
                Rectangle {
                    id: clockMask
                    anchors.fill: parent
                    radius: 17
                    visible: false
                    antialiasing: true
                }

                // CONTENT (Unmasked)
                RowLayout {
                    id: clockRow
                    anchors.centerIn: parent; spacing: 8
                    Text { id: dateText; text: Qt.formatDateTime(new Date(), "ddd, MMM d"); font.family: barTheme.textFont; font.pixelSize: 12; font.weight: 600; color: barPalette.accent }
                    Text { text: "•"; font.pixelSize: 10; color: barPalette.textSecondary }
                    Text { id: timeText; text: Qt.formatDateTime(new Date(), "h:mm AP"); font.family: barTheme.textFont; font.pixelSize: 13; font.weight: 800; color: barPalette.textPrimary }
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: { var now = new Date(); dateText.text = Qt.formatDateTime(now, "ddd, MMM d"); timeText.text = Qt.formatDateTime(now, "h:mm AP") }
                    }
                }

                NumberAnimation { id: clockShimmerAnim; target: clockShimmer; property: "x"; from: -60; to: clockContainer.width + 60; duration: 800; easing.type: Easing.InOutQuad }
                
                MouseArea {
                    id: clockArea
                    anchors.fill: parent; hoverEnabled: true
                    onPressed: (mouse) => { win.requestHubToggle(); mouse.accepted = true }
                    onEntered: clockShimmerAnim.restart()
                }
            }
        }
    }
}