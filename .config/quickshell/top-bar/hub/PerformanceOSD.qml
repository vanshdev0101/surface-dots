import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
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
        readonly property int radiusOuter: 24
        readonly property color bgMain: isDarkMode
            ? (Lib.Configuration.useCustomColors ? Lib.Configuration.customBg : "#141719")
            : (Lib.Configuration.useCustomColors ? Lib.Configuration.customBg : "#a6b0a0")
        readonly property color bgItem: isDarkMode ? "#2d353b" : Qt.rgba(0, 0, 0, 0.05)
        readonly property color textPrimary: isDarkMode ? "#d3c6aa" : "#3c4841"
        readonly property color textSecondary: isDarkMode ? "#9da9a0" : "#232a23"
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

    Rectangle {
        id: box
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 54 }
        width: 460
        height: card.implicitHeight + 24
        radius: theme.radiusOuter
        color: theme.bgMain
        border.width: 1
        border.color: theme.border

        MouseArea { anchors.fill: parent; onClicked: (m) => m.accepted = true }

        Keys.onEscapePressed: win.close()
        Component.onCompleted: forceActiveFocus()

        PerformanceDashboardCard {
            id: card
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            anchors.margins: 12
            theme: theme
            active: true
        }
    }
}
