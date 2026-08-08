import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../lib" as Lib

Lib.Card {
    id: root
    Layout.fillWidth: true
    theme: parentTheme

    property QtObject parentTheme: null
    property bool active: false
    signal wallpaperRequested()
    signal backRequested()

    readonly property bool themed: parentTheme !== null
    readonly property color textPrimary:   themed ? parentTheme.textPrimary   : "#d3c6aa"
    readonly property color textSecondary: themed ? parentTheme.textSecondary : "#9da9a0"
    readonly property color accent:        themed ? parentTheme.accent        : "#a7c080"
    readonly property color bgItem:        themed ? parentTheme.bgItem        : "#2d353b"
    readonly property color outline:       themed ? parentTheme.outline       : Qt.rgba(1,1,1,0.1)

    property real contentHeight: contentLayout.implicitHeight + (root.pad * 2)
    implicitHeight: root.active ? contentHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
    visible: implicitHeight > 1
    clip: true

    function validHex(s) { return /^#[0-9a-fA-F]{6}$/.test(String(s)) }
    function hex6(c) { var s = String(c); return s.length === 9 ? "#" + s.slice(3) : s }

    ColumnLayout {
        id: contentLayout
        Layout.fillWidth: true
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Rectangle {
                width: 26; height: 26; radius: 6
                color: root.bgItem; border.width: 1; border.color: root.outline
                Text { anchors.centerIn: parent; text: "←"; color: root.textPrimary; font.pixelSize: 14 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }
            Text { text: "Settings"; color: root.textPrimary; font.pixelSize: 14; font.bold: true }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Theme"; color: root.textSecondary; Layout.fillWidth: true }
            Rectangle {
                width: 70; height: 26; radius: 6
                color: root.bgItem; border.width: 1; border.color: root.outline
                Text {
                    anchors.centerIn: parent
                    text: root.themed && root.parentTheme.isDarkMode ? "Dark" : "Light"
                    color: root.accent; font.pixelSize: 12
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["bash", "-c",
                        "bash ~/.config/quickshell/top-bar/bar/theme-mode.sh " +
                        (root.themed && root.parentTheme.isDarkMode ? "light" : "dark")])
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: "Accent"; color: root.textSecondary }
            Rectangle { width: 20; height: 20; radius: 5; color: root.accent; border.width: 1; border.color: root.outline }
            TextField {
                id: accentField
                Layout.fillWidth: true
                text: Lib.Configuration.useCustomColors ? root.hex6(Lib.Configuration.customAccent) : root.hex6(root.accent)
                font.pixelSize: 12
                color: root.textPrimary
                background: Rectangle { color: root.bgItem; radius: 6; border.width: 1; border.color: root.outline }
                onEditingFinished: {
                    if (root.validHex(text)) {
                        Lib.Configuration.customAccent = text
                        Lib.Configuration.useCustomColors = true
                        Lib.Configuration.save()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: "Background"; color: root.textSecondary }
            Rectangle { width: 20; height: 20; radius: 5; color: root.themed ? root.parentTheme.bgMain : "#141719"; border.width: 1; border.color: root.outline }
            TextField {
                id: bgField
                Layout.fillWidth: true
                text: Lib.Configuration.useCustomColors ? root.hex6(Lib.Configuration.customBg) : root.hex6(root.themed ? root.parentTheme.bgMain : "#141719")
                font.pixelSize: 12
                color: root.textPrimary
                background: Rectangle { color: root.bgItem; radius: 6; border.width: 1; border.color: root.outline }
                onEditingFinished: {
                    if (root.validHex(text)) {
                        Lib.Configuration.customBg = text
                        Lib.Configuration.useCustomColors = true
                        Lib.Configuration.save()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: "Power menu bg"; color: root.textSecondary }
            TextField {
                id: powerMenuBgField
                Layout.fillWidth: true
                text: Lib.Configuration.powerMenuBgImage
                placeholderText: "leave empty for default artwork"
                font.pixelSize: 12
                color: root.textPrimary
                background: Rectangle { color: root.bgItem; radius: 6; border.width: 1; border.color: root.outline }
                onEditingFinished: {
                    Lib.Configuration.powerMenuBgImage = text
                    Lib.Configuration.save()
                }
            }
        }

        Text { text: "Profile picture"; color: root.textSecondary; font.pixelSize: 12 }
        TextField {
            id: profileImageField
            Layout.fillWidth: true
            text: Lib.Configuration.profileImageOverride
            placeholderText: "path to an image, leave empty for default"
            font.pixelSize: 12
            color: root.textPrimary
            background: Rectangle { color: root.bgItem; radius: 6; border.width: 1; border.color: root.outline }
            onEditingFinished: {
                Lib.Configuration.profileImageOverride = text
                Lib.Configuration.save()
            }
        }

        Text { text: "Weather (OpenWeatherMap)"; color: root.textSecondary; font.pixelSize: 12 }
        TextField {
            id: weatherApiField
            Layout.fillWidth: true
            text: Lib.Configuration.weatherApiKey
            placeholderText: "API key"
            echoMode: TextInput.Password
            font.pixelSize: 12
            color: root.textPrimary
            background: Rectangle { color: root.bgItem; radius: 6; border.width: 1; border.color: root.outline }
            onEditingFinished: {
                Lib.Configuration.weatherApiKey = text
                Lib.Configuration.save()
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            TextField {
                id: weatherLatField
                Layout.fillWidth: true
                text: Lib.Configuration.weatherLat
                placeholderText: "Latitude"
                font.pixelSize: 12
                color: root.textPrimary
                background: Rectangle { color: root.bgItem; radius: 6; border.width: 1; border.color: root.outline }
                onEditingFinished: {
                    Lib.Configuration.weatherLat = text
                    Lib.Configuration.save()
                }
            }
            TextField {
                id: weatherLonField
                Layout.fillWidth: true
                text: Lib.Configuration.weatherLon
                placeholderText: "Longitude"
                font.pixelSize: 12
                color: root.textPrimary
                background: Rectangle { color: root.bgItem; radius: 6; border.width: 1; border.color: root.outline }
                onEditingFinished: {
                    Lib.Configuration.weatherLon = text
                    Lib.Configuration.save()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Rectangle {
                width: 90; height: 28; radius: 6
                color: root.bgItem; border.width: 1; border.color: root.outline
                Text { anchors.centerIn: parent; text: "Reset colors"; color: root.textSecondary; font.pixelSize: 11 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Lib.Configuration.useCustomColors = false
                        Lib.Configuration.save()
                    }
                }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 90; height: 28; radius: 6
                color: root.accent
                Text { anchors.centerIn: parent; text: "Wallpaper"; color: "#141719"; font.pixelSize: 11; font.bold: true }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.wallpaperRequested()
                }
            }
        }
    }
}
