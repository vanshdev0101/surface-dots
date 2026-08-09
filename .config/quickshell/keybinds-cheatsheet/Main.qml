import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Standalone popup, shared by both desktop layouts. Launched on demand via
// `quickshell -p`, same pattern as PowerMenu.qml / WifiMenu.qml.

PanelWindow {
    id: win
    WlrLayershell.namespace: "keybinds-cheat"
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    focusable: true
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool isDarkMode: true
    property var sections: []
    property string filter: ""

    QtObject {
        id: theme
        property color bg: win.isDarkMode ? "#1e2326" : "#edc5c6"
        property color card: win.isDarkMode ? "#232a2e" : "#f2f0e5"
        property color item: win.isDarkMode ? "#2d353b" : "#e2dfd3"
        property color outline: win.isDarkMode ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.1)
        property color text: win.isDarkMode ? "#d3c6aa" : "#3c4841"
        property color textMuted: win.isDarkMode ? "#9da9a0" : "#6b7a70"
        property color accent: win.isDarkMode ? "#a7c080" : "#3c4841"
        property color key: win.isDarkMode ? "#374145" : "#dcd8c8"
    }

    Process {
        id: themeCheck
        command: ["cat", "/home/vanshc/.cache/quickshell/theme_mode"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                win.isDarkMode = (text.trim() !== "light")
                themeCheck.running = false
            }
        }
    }

    Process {
        id: kbLoader
        command: ["python3", Qt.resolvedUrl("parse_keybinds.py").toString().replace("file://", ""),
                  "/home/vanshc/.config/hypr/hyprland.lua"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.sections = JSON.parse(text) } catch (e) { win.sections = [] }
            }
        }
    }

    readonly property var filteredSections: {
        const q = filter.trim().toLowerCase()
        if (q === "") return sections
        const out = []
        for (const s of sections) {
            const binds = s.binds.filter(b =>
                b.keys.toLowerCase().includes(q) || b.desc.toLowerCase().includes(q))
            if (binds.length > 0) out.push({ section: s.section, binds: binds })
        }
        return out
    }

    function close() { Qt.quit() }

    Rectangle {
        anchors.fill: parent
        color: win.isDarkMode ? "#66000000" : "#44ffffff"
        MouseArea { anchors.fill: parent; onClicked: win.close() }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 640
        height: Math.min(parent.height - 80, 720)
        radius: 20
        color: theme.card
        border.width: 1
        border.color: theme.outline
        clip: true

        MouseArea { anchors.fill: parent; onClicked: (m) => m.accepted = true }

        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) { win.close(); e.accepted = true }
        }
        Component.onCompleted: forceActiveFocus()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Keybinds"
                    color: theme.text
                    font.pixelSize: 20
                    font.weight: 700
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: {
                        let n = 0
                        for (const s of win.filteredSections) n += s.binds.length
                        return n + " shown"
                    }
                    color: theme.textMuted
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: 9
                color: theme.item
                border.width: 1
                border.color: searchInput.activeFocus ? theme.accent : theme.outline
                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextInput {
                    id: searchInput
                    anchors { fill: parent; margins: 10 }
                    verticalAlignment: Text.AlignVCenter
                    color: theme.text
                    font.pixelSize: 14
                    clip: true
                    focus: true
                    onTextChanged: win.filter = text
                    Keys.onEscapePressed: win.close()
                }
                Text {
                    anchors { fill: parent; margins: 10 }
                    verticalAlignment: Text.AlignVCenter
                    text: "Search keybinds..."
                    color: theme.textMuted
                    font.pixelSize: 14
                    visible: searchInput.text === ""
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: listCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: listCol
                    width: parent.width
                    spacing: 16

                    Repeater {
                        model: win.filteredSections
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.section
                                color: theme.accent
                                font.pixelSize: 13
                                font.weight: 700
                                opacity: 0.85
                            }

                            Repeater {
                                model: modelData.binds
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Text {
                                        text: modelData.desc
                                        color: theme.text
                                        font.pixelSize: 14
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Rectangle {
                                        radius: 6
                                        color: theme.key
                                        implicitWidth: keyText.implicitWidth + 16
                                        implicitHeight: 24
                                        Text {
                                            id: keyText
                                            anchors.centerIn: parent
                                            text: modelData.keys
                                            color: theme.textMuted
                                            font.pixelSize: 12
                                            font.family: "monospace"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 20
                        horizontalAlignment: Text.AlignHCenter
                        text: "No matches"
                        color: theme.textMuted
                        font.pixelSize: 13
                        visible: win.filteredSections.length === 0
                    }
                }
            }
        }
    }
}
