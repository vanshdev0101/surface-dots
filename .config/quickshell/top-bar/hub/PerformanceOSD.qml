import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../lib" as Lib

// Standalone popup for the bar's "Performance" button. Same pattern as
// PowerMenu.qml / keybinds-cheatsheet: launched on demand via `quickshell -p`,
// toggled closed by killing the process (see Bar.qml's click handler).
//
// Deliberately does NOT instantiate Lib.ThemeEngine as a type -- Quickshell's
// qmlscanner treats "../lib" as outside the config folder for a standalone
// -p launch and refuses to resolve a non-singleton type from it (fatal
// error), while singleton access (Lib.Configuration.xxx) still resolves
// fine. PowerMenu.qml sidesteps this the same way: a local QtObject theme.
//
// Now a 4-tab widget (Dashboard/Media/Performance/Workspaces), not just the
// Performance ring gauges -- everything below the tab bar is still fully
// self-contained for the same reason.

PanelWindow {
    id: win
    WlrLayershell.namespace: "performance-osd"
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    focusable: true
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    property bool isDarkMode: true
    property string currentTab: "performance"

    Process {
        command: ["cat", "/home/vanshc/.cache/quickshell/theme_mode"]
        running: true
        stdout: StdioCollector {
            onTextChanged: { win.isDarkMode = (text.trim() !== "light") }
        }
    }

    QtObject {
        id: theme
        readonly property bool isDarkMode: win.isDarkMode
        readonly property string textFont: "Manrope"
        readonly property string iconFont: "JetBrainsMono Nerd Font"
        readonly property int radiusOuter: 26
        readonly property color bgMain: isDarkMode
            ? (Lib.Configuration.useCustomColors ? Lib.Configuration.customBg : "#141719")
            : (Lib.Configuration.useCustomColors ? Lib.Configuration.customBg : "#a6b0a0")
        readonly property color bgItem: isDarkMode ? "#2d353b" : Qt.rgba(0, 0, 0, 0.05)
        readonly property color textPrimary: isDarkMode ? "#d3c6aa" : "#3c4841"
        readonly property color textSecondary: isDarkMode ? "#9da9a0" : "#232a23"
        readonly property color textOnAccent: isDarkMode ? "#232a2e" : "#f0f2d4"
        readonly property color accent: Lib.Configuration.useCustomColors
            ? Lib.Configuration.customAccent
            : (isDarkMode ? "#a7c080" : "#3c4841")
        readonly property color border: isDarkMode ? "#70a7c080" : "#b9566a35"
    }

    function close() { Qt.quit() }

    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    readonly property var tabs: [
        { id: "dashboard",   icon: "󰕮", label: "Dashboard" },
        { id: "media",       icon: "",  label: "Media" },
        { id: "performance", icon: "󰓅", label: "Performance" },
        { id: "workspaces",  icon: "󰕰", label: "Workspaces" }
    ]

    Rectangle {
        id: box
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 54 }
        width: 620
        height: card.implicitHeight + 40
        radius: theme.radiusOuter
        // Semi-transparent, not a flat opaque fill -- gives real depth
        // alongside the shadow layer below, per the "soft shadow,
        // semi-transparent background" spec.
        color: Qt.rgba(theme.bgMain.r, theme.bgMain.g, theme.bgMain.b, 0.92)
        border.width: 1
        border.color: theme.border

        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: 12
            radius: parent.radius
            color: "black"
            opacity: theme.isDarkMode ? 0.35 : 0.20
        }

        MouseArea { anchors.fill: parent; onClicked: (m) => m.accepted = true }

        Keys.onEscapePressed: win.close()
        Component.onCompleted: forceActiveFocus()

        ColumnLayout {
            id: card
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            anchors.margins: 20
            spacing: 16

            // ---------------- Tab bar ----------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: win.tabs
                        delegate: Item {
                            id: tabDelegate
                            required property var modelData
                            readonly property bool isActive: win.currentTab === modelData.id

                            Layout.fillWidth: true
                            implicitHeight: tabInner.implicitHeight + 12

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: theme.accent
                                opacity: tabDelegate.isActive ? (theme.isDarkMode ? 0.16 : 0.12) : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            ColumnLayout {
                                id: tabInner
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    text: tabDelegate.modelData.icon
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: theme.iconFont
                                    font.pixelSize: 15
                                    color: tabDelegate.isActive ? theme.accent : theme.textSecondary
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                Text {
                                    text: tabDelegate.modelData.label
                                    Layout.alignment: Qt.AlignHCenter
                                    font.family: theme.textFont
                                    font.pixelSize: 12
                                    font.weight: tabDelegate.isActive ? Font.DemiBold : Font.Normal
                                    color: tabDelegate.isActive ? theme.textPrimary : theme.textSecondary
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                            }

                            Rectangle {
                                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                width: tabInner.implicitWidth * 0.7
                                height: 2
                                radius: 1
                                color: theme.accent
                                opacity: tabDelegate.isActive ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.currentTab = tabDelegate.modelData.id
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.border
                    opacity: 0.5
                }
            }

            // ---------------- Tab content ----------------
            Item {
                Layout.fillWidth: true
                implicitHeight: {
                    if (win.currentTab === "dashboard") return dashboardTab.implicitHeight
                    if (win.currentTab === "media") return mediaTab.implicitHeight
                    if (win.currentTab === "performance") return perfCard.implicitHeight
                    return workspacesTab.implicitHeight
                }

                DashboardTab {
                    id: dashboardTab
                    anchors { left: parent.left; right: parent.right }
                    theme: theme
                    active: win.currentTab === "dashboard"
                    visible: active
                }

                MediaTab {
                    id: mediaTab
                    anchors { left: parent.left; right: parent.right }
                    theme: theme
                    visible: win.currentTab === "media"
                }

                PerformanceDashboardCard {
                    id: perfCard
                    anchors { left: parent.left; right: parent.right }
                    theme: theme
                    active: win.currentTab === "performance"
                    visible: active
                }

                WorkspacesTab {
                    id: workspacesTab
                    anchors { left: parent.left; right: parent.right }
                    theme: theme
                    active: win.currentTab === "workspaces"
                    visible: active
                }
            }
        }
    }

    // ==================== Dashboard tab ====================
    component DashboardTab: Item {
        id: dash
        property QtObject theme: null
        property bool active: false
        implicitHeight: dashCol.implicitHeight

        Process {
            id: sysInfoProc
            running: dash.active
            command: ["bash", "-lc", "hostname; uptime -p | sed 's/up //'; uname -sr"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var lines = String(text || "").trim().split("\n")
                    dash.hostname = lines[0] || "—"
                    dash.uptime = lines[1] || "—"
                    dash.kernel = lines[2] || "—"
                }
            }
        }
        property string hostname: "—"
        property string uptime: "—"
        property string kernel: "—"

        ColumnLayout {
            id: dashCol
            width: parent.width
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 28

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Host"; color: dash.theme.textSecondary; font.family: dash.theme.textFont; font.pixelSize: 11; opacity: 0.8 }
                    Text { text: dash.hostname; color: dash.theme.textPrimary; font.family: dash.theme.textFont; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Uptime"; color: dash.theme.textSecondary; font.family: dash.theme.textFont; font.pixelSize: 11; opacity: 0.8 }
                    Text { text: dash.uptime; color: dash.theme.textPrimary; font.family: dash.theme.textFont; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Kernel"; color: dash.theme.textSecondary; font.family: dash.theme.textFont; font.pixelSize: 11; opacity: 0.8 }
                    Text { text: dash.kernel; color: dash.theme.textPrimary; font.family: dash.theme.textFont; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
            }
        }
    }

    // ==================== Media tab ====================
    component MediaTab: Item {
        id: media
        property QtObject theme: null
        implicitHeight: mediaCol.implicitHeight

        property var player: {
            var ps = Mpris.players.values || []
            for (var i = 0; i < ps.length; i++) if (ps[i] && ps[i].isPlaying) return ps[i]
            return ps.length > 0 ? ps[0] : null
        }
        readonly property bool hasPlayer: media.player !== null
        readonly property bool isPlaying: media.hasPlayer && media.player.isPlaying

        ColumnLayout {
            id: mediaCol
            width: parent.width
            spacing: 10

            Text {
                visible: !media.hasPlayer
                text: "Nothing playing"
                color: media.theme.textSecondary
                font.family: media.theme.textFont
                font.pixelSize: 14
                opacity: 0.7
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                Layout.alignment: Qt.AlignHCenter
            }

            ColumnLayout {
                visible: media.hasPlayer
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: media.hasPlayer ? (media.player.trackTitle || "Unknown title") : ""
                    color: media.theme.textPrimary
                    font.family: media.theme.textFont
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: media.hasPlayer ? (media.player.trackArtist || "Unknown artist") : ""
                    color: media.theme.textSecondary
                    font.family: media.theme.textFont
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: media.isPlaying ? "Playing" : "Paused"
                    color: media.isPlaying ? media.theme.accent : media.theme.textSecondary
                    font.family: media.theme.textFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    Layout.topMargin: 4
                }
            }
        }
    }

    // ==================== Workspaces tab ====================
    component WorkspacesTab: Item {
        id: wsTab
        property QtObject theme: null
        property bool active: false
        implicitHeight: wsCol.implicitHeight

        readonly property int activeWsId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
        property var wsMap: ({})

        function rebuild() {
            const m = {}
            const list = Hyprland.toplevels?.values ?? []
            for (const tl of list) {
                const id = tl?.workspace?.id
                if (!id) continue
                if (!m[id]) m[id] = 0
                m[id]++
            }
            wsMap = m
        }

        readonly property var sortedWorkspaces: {
            var list = Hyprland.workspaces?.values ?? []
            var arr = []
            for (var i = 0; i < list.length; i++) arr.push(list[i])
            arr.sort(function(a, b) { return (a?.id ?? 0) - (b?.id ?? 0) })
            return arr
        }

        onActiveChanged: if (active) rebuild()

        function switchTo(wsId) {
            Quickshell.execDetached(["bash", "-c", "hyprctl dispatch \"hl.dsp.focus({ workspace = " + wsId + " })\""])
            win.close()
        }

        ColumnLayout {
            id: wsCol
            width: parent.width
            spacing: 8

            Text {
                visible: wsTab.sortedWorkspaces.length === 0
                text: "No workspaces"
                color: wsTab.theme.textSecondary
                font.family: wsTab.theme.textFont
                font.pixelSize: 13
                opacity: 0.7
            }

            Repeater {
                model: wsTab.sortedWorkspaces
                delegate: Rectangle {
                    id: wsRow
                    required property var modelData
                    readonly property int wsId: modelData?.id ?? 0
                    readonly property bool isActive: wsId === wsTab.activeWsId
                    readonly property int winCount: wsTab.wsMap[wsId] ?? 0

                    Layout.fillWidth: true
                    height: 36
                    radius: 9
                    color: isActive ? wsTab.theme.accent : (wsHover.hovered ? wsTab.theme.bgItem : "transparent")
                    border.width: isActive ? 0 : 1
                    border.color: wsTab.theme.border
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }

                        Text {
                            text: String(wsRow.modelData?.name || wsRow.wsId)
                            font.family: wsTab.theme.textFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: wsRow.isActive ? wsTab.theme.textOnAccent : wsTab.theme.textPrimary
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: wsRow.winCount + (wsRow.winCount === 1 ? " window" : " windows")
                            font.family: wsTab.theme.textFont
                            font.pixelSize: 11
                            opacity: 0.8
                            color: wsRow.isActive ? wsTab.theme.textOnAccent : wsTab.theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: wsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wsTab.switchTo(wsRow.wsId)
                    }
                }
            }
        }
    }
}
