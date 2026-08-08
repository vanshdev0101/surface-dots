import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../lib" as Lib
import "../config.js" as Config

PanelWindow {
    id: win
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    // Hides window borders when the hub is open
    function setBordersHidden(hidden) {
        Quickshell.execDetached(["hyprctl", "keyword", "general:border_size", hidden ? "0" : "1"])
    }

    function closeAll() {
    if (header) header.expanded = false
    win.settingsPanelOpen = false
    win.wallpaperMode = false
    win.visible = false
}
    onVisibleChanged: {
    setBordersHidden(visible)
    if (!visible) {
        win.batteryCardActive = false
        win.settingsPanelOpen = false
        win.wallpaperMode = false
        if (header) header.expanded = false
    } else {
        root.forceActiveFocus()
    }
}


    property int barStrip: 2
    property bool isDarkMode: true
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

    function _applyThemeMode(raw) {
        var m = String(raw || "").trim().toLowerCase()
        win.isDarkMode = (m !== "light")
    }

    // Theme toggle watcher
    FileView {
        id: themeModeFile
        path: win._themeModePath
        watchChanges: true
        preload: true
        onLoaded: win._applyThemeMode(text())
        onFileChanged: reload()
        onTextChanged: win._applyThemeMode(text())
        onLoadFailed: {
            win.isDarkMode = true
            setText("dark")
        }
    }

    Lib.ThemeEngine {
        id: theme
        isDarkMode: win.isDarkMode
    }

    margins { top: barStrip }
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: visible
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "snes-hub"

    property string profileName: Config.PROFILE_NAME
    property string profileImage: Lib.Configuration.profileImageOverride !== "" ? Lib.Configuration.profileImageOverride : Config.PROFILE_IMG
    property bool batteryCardActive: false
    property bool settingsPanelOpen: false
    property bool wallpaperMode: false
    property int topGap: 8
    property int rightGap: 10
    property int panelW: win.settingsPanelOpen ? 480 : 320

    function executeAction(action) {
        var cmd = ""
        switch(action) {
            case "shutdown":  cmd = "systemctl poweroff"; break;
            case "reboot":    cmd = "systemctl reboot"; break;
            case "hibernate": cmd = "systemctl hibernate"; break;
            case "suspend":   cmd = "mpc -q pause; amixer set Master mute; systemctl suspend"; break;
            case "logout":    cmd = "hyprctl dispatch exit"; break;
            case "lock":
                cmd = "if command -v hyprlock >/dev/null; then hyprlock; " +
                      "elif command -v betterlockscreen >/dev/null; then betterlockscreen -l; " +
                      "elif command -v i3lock >/dev/null; then i3lock; fi";
                break;
        }

        if (cmd !== "") Quickshell.execDetached(["bash", "-lc", cmd])
        closeAll()
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: closeAll()
        Keys.onPressed: (event) => {
            // Press 'P' to toggle the power menu
            if (event.key === Qt.Key_P) {
                if (header) {
                    header.expanded = !header.expanded
                    event.accepted = true
                }
            }
        }

        // click outside closes
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            onPressed: closeAll()
        }

        Rectangle {
            id: panel
            width: win.wallpaperMode ? Math.min(980, win.width - 2 * win.rightGap) : win.panelW
            height: win.wallpaperMode ? Math.min(860, win.height - 2 * win.topGap) : Math.ceil(layout.implicitHeight + 24)
            Behavior on width { NumberAnimation { id: panelWidthAnim; duration: 380; easing.type: Easing.OutExpo } }
            Behavior on height { NumberAnimation { id: panelHeightAnim; duration: 380; easing.type: Easing.OutExpo } }
            radius: theme.radiusOuter
            color: theme.bgMain
            border.width: 1
            border.color: theme.border
            clip: true

            anchors {
                right: parent.right
                top: parent.top
                rightMargin: win.rightGap
                topMargin: win.topGap
            }

            // block clicks inside panel from closing
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                preventStealing: true
                onPressed: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                id: layout
                anchors.fill: parent
                anchors.margins: 12
                spacing: theme.gapCard

                Header {
                    id: header
                    theme: theme
                    Layout.fillWidth: true
                    profileName: win.profileName
                    profileImage: win.profileImage
                    active: win.visible
                    onCloseRequested: closeAll()

                    onPowerAction: function(act, lbl) {
                        // collapse the expanded header immediately
                        header.expanded = false
                        executeAction(act)
                    }
                }

                ColumnLayout {
                    id: cardsColumn
                    Layout.fillWidth: true
                    spacing: theme.gapCard
                    opacity: (!win.settingsPanelOpen && !win.wallpaperMode) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    visible: opacity > 0.01

                    ButtonsSlidersCard {
                        id: buttons
                        Layout.fillWidth: true
                        active: win.visible
                        theme: theme
                        onCloseRequested: closeAll()
                        onBatteryToggleRequested: win.batteryCardActive = !win.batteryCardActive
                    }

                    BatteryHealthCard {
                        id: battery
                        Layout.fillWidth: true
                        active: win.batteryCardActive
                        theme: theme
                    }

                    MediaCard {
                        id: media
                        Layout.fillWidth: true
                        onCloseRequested: closeAll()
                    }

                    CalendarWeatherCard {
                        Layout.fillWidth: true
                        active: win.visible
                        theme: theme
                        onCloseRequested: closeAll()
                    }

                    NotificationsCard {
                        id: notifs
                        Layout.fillWidth: true
                        active: win.visible
                        compactMode: media.visible || battery.visible || header.expanded
                        dndActive: buttons.dnd
                        theme: theme
                    }
                }

                SettingsCard {
                    id: settingsCard
                    Layout.fillWidth: true
                    active: win.settingsPanelOpen && !win.wallpaperMode
                    parentTheme: theme
                    onWallpaperRequested: win.wallpaperMode = true
                    onBackRequested: win.settingsPanelOpen = false
                    onToastRequested: (msg) => panel.triggerToast(msg)
                }
            }

            WallpaperPanel {
                id: wallpaperPanel
                anchors.fill: panel
                theme: theme
                visible: win.wallpaperMode
                live: !(panelWidthAnim.running || panelHeightAnim.running)
                onCloseRequested: win.wallpaperMode = false
            }

            // Panel-level toast (used by Settings for previews that don't
            // actually apply, e.g. screen-border sliders)
            property bool   _showToast: false
            property string _toastText: ""
            function triggerToast(msg) { _toastText = msg; _showToast = true; panelToastTimer.restart() }
            Timer { id: panelToastTimer; interval: 3500; onTriggered: panel._showToast = false }

            Rectangle {
                z: 99
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 10
                height: 26; radius: 7
                width: panelToastLabel.implicitWidth + 22
                color: Qt.rgba(theme.bgCard.r, theme.bgCard.g, theme.bgCard.b, 0.94)
                border.width: 1; border.color: theme.accent
                opacity: panel._showToast ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Text {
                    id: panelToastLabel
                    anchors.centerIn: parent
                    text: panel._toastText
                    color: theme.accent
                    font.pixelSize: 11
                }
            }
        }
    }
}
