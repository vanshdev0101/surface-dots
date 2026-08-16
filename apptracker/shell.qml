import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme.js" as Theme

ShellRoot {
    id: shell

    // Hidden when the session autostarts it, visible when run by hand --
    // a widget that covers your desktop at login is one you resent.
    property bool open: Quickshell.env("APPTRACKER_START_HIDDEN") !== "1"

    Store { id: store }

    // Bind a Hyprland key to:  qs -p ~/apptracker ipc call tracker toggle
    IpcHandler {
        target: "tracker"
        function toggle(): void { shell.open = !shell.open }
        function show(): void { shell.open = true }
        function hide(): void { shell.open = false }
        function state(): string {
            const w = loader.item;
            return (shell.open ? "open" : "closed")
                 + (w ? " size=" + w.width + "x" + w.height : " (no window)");
        }
    }

    LazyLoader {
        id: loader
        active: shell.open

        component: PanelWindow {
        id: panel
        color: "transparent"

        anchors { top: true; right: true }
        margins { top: 16; right: 16 }

        implicitWidth: 420
        implicitHeight: (panel.screen ? panel.screen.height : 1080) - 120

        mask: Region { item: card }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Top
        // Without this the text fields in the editor silently swallow every
        // keystroke: a layer-shell surface gets no keyboard by default.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: shell.open = false

        Rectangle {
            id: card
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.min(body.implicitHeight + 2 * (Theme.padCard + 4), parent.height)
            color: Theme.bgPanel
            radius: Theme.radiusOuter
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.07)

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: Theme.padCard + 4
                spacing: Theme.gapCard

                // ---- header ------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Applications"
                            font.family: Theme.textFont
                            font.pixelSize: 17
                            font.bold: true
                            color: Theme.fgMain
                        }
                        Text {
                            text: {
                                if (store.error) return store.error;
                                const n = store.apps.length;
                                if (n === 0) return "nothing tracked yet";
                                const d = store.nextDue;
                                return d
                                    ? d.company + " " + store.relative(d.due)
                                    : n + (n === 1 ? " application" : " applications");
                            }
                            font.family: Theme.monoFont
                            font.pixelSize: 10
                            color: store.error ? Theme.accentRed
                                 : (store.nextDue && store.overdue(store.nextDue.due) ? Theme.accentRed : Theme.fgMuted)
                            elide: Text.ElideRight
                            Layout.maximumWidth: 260
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: 30
                        radius: Theme.radiusChip
                        color: addMouse.containsMouse ? Theme.bgItemHover : Theme.bgItem
                        Text {
                            anchors.centerIn: parent
                            text: list.adding ? "×" : "+"
                            font.family: Theme.textFont
                            font.pixelSize: 17
                            color: Theme.fgMain
                        }
                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                list.editingId = "";
                                list.adding = !list.adding;
                                if (list.adding) list.draft = store.blank();
                            }
                        }
                    }

                    Rectangle {
                        implicitHeight: 30
                        implicitWidth: 30
                        radius: Theme.radiusChip
                        color: closeMouse.containsMouse ? Qt.alpha(Theme.accentRed, 0.22) : Theme.bgItem
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            font.family: Theme.textFont
                            font.pixelSize: 17
                            color: closeMouse.containsMouse ? Theme.accentRed : Theme.fgMuted
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shell.open = false
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

                // ---- list --------------------------------------------------
                ScrollView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: inner.implicitHeight
                    clip: true
                    contentWidth: availableWidth

                    property string editingId: ""
                    property bool adding: false
                    property var draft: null

                    ColumnLayout {
                        id: inner
                        width: list.availableWidth
                        spacing: 6

                        Editor {
                            visible: list.adding
                            Layout.fillWidth: true
                            entry: list.draft
                            isNew: true
                            onAccepted: function (e) { store.upsert(e); list.adding = false; }
                            onCancelled: list.adding = false
                        }

                        Repeater {
                            model: store.sorted

                            delegate: Item {
                                required property var modelData
                                readonly property bool editing: list.editingId === modelData.id

                                Layout.fillWidth: true
                                implicitHeight: editing ? editor.implicitHeight : row.implicitHeight

                                Editor {
                                    id: editor
                                    visible: parent.editing
                                    width: parent.width
                                    entry: modelData
                                    onAccepted: function (e) { store.upsert(e); list.editingId = ""; }
                                    onCancelled: list.editingId = ""
                                    onDeleteRequested: function (id) { store.remove(id); list.editingId = ""; }
                                }

                                Rectangle {
                                    id: row
                                    visible: !parent.editing
                                    width: parent.width
                                    implicitHeight: rowCol.implicitHeight + 18
                                    radius: Theme.radiusInner
                                    color: rowMouse.containsMouse ? Theme.bgItemHover : Theme.bgCard

                                    // Status as a left edge: colour where the eye
                                    // lands first, no legend needed.
                                    Rectangle {
                                        width: 3
                                        height: parent.height - 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 1
                                        radius: 2
                                        color: Theme.statusColor(modelData.status)
                                    }

                                    ColumnLayout {
                                        id: rowCol
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        anchors.leftMargin: 14
                                        spacing: 3

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                text: modelData.role
                                                font.family: Theme.textFont
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: Theme.fgMain
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                radius: Theme.radiusChip
                                                implicitHeight: 17
                                                implicitWidth: st.implicitWidth + 14
                                                color: Qt.alpha(Theme.statusColor(modelData.status), 0.18)
                                                Text {
                                                    id: st
                                                    anchors.centerIn: parent
                                                    text: modelData.status
                                                    font.family: Theme.monoFont
                                                    font.pixelSize: 9
                                                    color: Theme.statusColor(modelData.status)
                                                }
                                            }
                                        }

                                        Text {
                                            text: {
                                                let s = modelData.company;
                                                if (modelData.location) s += "  ·  " + modelData.location;
                                                return s;
                                            }
                                            font.family: Theme.textFont
                                            font.pixelSize: 11
                                            color: Theme.fgMuted
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            visible: modelData.due || modelData.resume

                                            Text {
                                                visible: !!modelData.due
                                                text: store.formatDate(modelData.due)
                                                     + "   " + store.relative(modelData.due)
                                                font.family: Theme.monoFont
                                                font.pixelSize: 10
                                                color: store.overdue(modelData.due) ? Theme.accentRed : Theme.accentGold
                                            }
                                            Text {
                                                visible: !!modelData.resume
                                                text: modelData.resume
                                                font.family: Theme.monoFont
                                                font.pixelSize: 10
                                                color: Theme.fgMuted
                                                elide: Text.ElideLeft
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignRight
                                            }
                                        }

                                        Text {
                                            visible: !!modelData.notes
                                            text: modelData.notes
                                            font.family: Theme.textFont
                                            font.pixelSize: 11
                                            color: Theme.fgMuted
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                            Layout.topMargin: 2
                                        }
                                    }

                                    MouseArea {
                                        id: rowMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            list.adding = false;
                                            list.editingId = list.editingId === modelData.id ? "" : modelData.id;
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: store.ready && store.apps.length === 0 && !list.adding
                            Layout.fillWidth: true
                            Layout.topMargin: 24
                            horizontalAlignment: Text.AlignHCenter
                            text: "No applications yet.\nPress + to add the first."
                            font.family: Theme.textFont
                            font.pixelSize: 12
                            color: Theme.fgMuted
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "esc or × to hide  ·  " + store.path.replace(Quickshell.env("HOME"), "~")
                    font.family: Theme.monoFont
                    font.pixelSize: 9
                    color: Qt.alpha(Theme.fgMuted, 0.6)
                    elide: Text.ElideMiddle
                }
            }
        }
        }
    }
    }
}
