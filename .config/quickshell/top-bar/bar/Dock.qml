import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../lib" as Lib
import "../lib/iconmap.js" as IconMap

PanelWindow {
    id: win

    WlrLayershell.namespace: "dock"
    WlrLayershell.layer: WlrLayer.Top
    // Anchored to the bottom edge ONLY (no left/right) so the surface is
    // exactly as wide as its content and centers itself -- anchoring full
    // width with a narrower visual "pill" inside left an invisible-but-
    // reserved strip spanning the whole screen either side of it.
    anchors { bottom: true }
    implicitWidth: pill.width
    implicitHeight: dockHeight
    color: "transparent"

    readonly property int dockHeight: 62
    WlrLayershell.exclusiveZone: dockHeight

    property bool isDarkMode: true
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"
    FileView {
        path: win._themeModePath
        watchChanges: true
        preload: true
        onLoaded: win.isDarkMode = (String(text() || "").trim().toLowerCase() !== "light")
        onTextChanged: win.isDarkMode = (String(text() || "").trim().toLowerCase() !== "light")
    }

    // Real ThemeEngine (not a standalone -p launch, so no risk pulling this
    // in) so the dock follows the same wallpaper/custom-accent cascade as
    // the rest of the rice instead of a fixed warm palette.
    Lib.ThemeEngine {
        id: dockTheme
        isDarkMode: win.isDarkMode
    }

    // Edit this list to change what's pinned. cls must match (a substring
    // of) the window's Hyprland class; exec is what launches it when it
    // isn't already running.
    readonly property var pinnedApps: [
        { name: "Terminal", cls: "kitty",   exec: "kitty" },
        { name: "Firefox",  cls: "firefox", exec: "firefox" },
        { name: "Files",    cls: "dolphin", exec: "dolphin" }
    ]

    function det(cmd) { Quickshell.execDetached(["bash", "-c", cmd]) }

    // --- Live running-window tracking (same pattern as Bar.qml's hyCache) ---
    QtObject {
        id: runCache
        property var classes: []   // deduped, lowercase, in first-seen order

        function rebuild() {
            const list = Hyprland.toplevels?.values ?? []
            const seen = []
            for (const tl of list) {
                const c = (tl?.lastIpcObject?.class || "").toLowerCase()
                if (c && !seen.includes(c)) seen.push(c)
            }
            classes = seen
        }
    }

    Timer { interval: 500; running: true; repeat: false; onTriggered: runCache.rebuild() }
    Timer { interval: 2000; running: true; repeat: false; onTriggered: runCache.rebuild() }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || !ev.name) return
            if (ev.name === "openwindow" || ev.name === "closewindow" || ev.name === "movewindowv2") {
                Hyprland.refreshToplevels()
                runCache.rebuild()
            }
        }
    }

    function isRunning(cls) {
        return runCache.classes.some(c => c.includes(cls))
    }

    // Running apps that aren't already pinned
    readonly property var extraApps: {
        var pinnedClasses = win.pinnedApps.map(a => a.cls)
        return runCache.classes.filter(c => !pinnedClasses.some(p => c.includes(p)))
    }

    function focusClass(cls) {
        det("hyprctl dispatch focuswindow class:^" + cls + "$")
    }
    function activate(app) {
        if (isRunning(app.cls)) focusClass(app.cls)
        else det(app.exec)
    }

    Rectangle {
        id: pill
        anchors { bottom: parent.bottom; bottomMargin: 8; horizontalCenter: parent.horizontalCenter }
        height: 46
        width: row.implicitWidth + 16
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        radius: 14
        color: Qt.rgba(dockTheme.bgCard.r, dockTheme.bgCard.g, dockTheme.bgCard.b, 0.82)
        border.width: 1
        border.color: dockTheme.outline

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: win.pinnedApps
                delegate: DockIcon {
                    required property var modelData
                    appName: modelData.name
                    icon: IconMap.getIcon(modelData.cls)
                    running: win.isRunning(modelData.cls)
                    onClicked: win.activate(modelData)
                }
            }

            Rectangle {
                visible: win.extraApps.length > 0
                Layout.preferredWidth: 1
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                color: dockTheme.outline
            }

            Repeater {
                model: win.extraApps
                delegate: DockIcon {
                    required property string modelData
                    appName: modelData
                    icon: IconMap.getIcon(modelData)
                    running: true
                    onClicked: win.focusClass(modelData)
                }
            }
        }
    }

    component DockIcon: Item {
        id: dockIcon
        property string appName: ""
        property string icon: ""
        property bool running: false
        signal clicked()

        implicitWidth: 34; implicitHeight: 34
        Layout.alignment: Qt.AlignVCenter

        scale: ma.containsPress ? 0.90 : (ma.containsMouse ? 1.18 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
        transformOrigin: Item.Bottom

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: ma.containsMouse ? dockTheme.subtleFillHover : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            id: iconText
            anchors.centerIn: parent
            text: dockIcon.icon !== "" ? dockIcon.icon : "?"
            font.pixelSize: 20
            font.family: "Symbols Nerd Font"
            color: dockTheme.textPrimary
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dockIcon.clicked()
        }

        ToolTip.visible: ma.containsMouse
        ToolTip.text: dockIcon.appName
        ToolTip.delay: 400
    }
}
