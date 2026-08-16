import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "theme.js" as Theme

// Add / edit form. Edits a copy and only commits on Save, so an abandoned
// edit never reaches the file.
Rectangle {
    id: root

    property var entry: null          // the record being edited
    property bool isNew: false
    signal accepted(var entry)
    signal cancelled()
    signal deleteRequested(string id)

    color: Theme.bgItem
    radius: Theme.radiusInner
    implicitHeight: col.implicitHeight + 2 * Theme.padCard + 8

    // Working copy
    property string vCompany: ""
    property string vRole: ""
    property string vStatus: "drafting"
    property string vDue: ""
    property string vResume: ""
    property string vLocation: ""
    property string vNotes: ""

    onEntryChanged: load()
    Component.onCompleted: load()

    function load() {
        if (!entry) return;
        vCompany = entry.company || "";
        vRole = entry.role || "";
        vStatus = entry.status || "drafting";
        vDue = entry.due || "";
        vResume = entry.resume || "";
        vLocation = entry.location || "";
        vNotes = entry.notes || "";
    }

    readonly property bool valid: vCompany.trim().length > 0 && vRole.trim().length > 0

    component Field: ColumnLayout {
        property alias label: cap.text
        property alias text: input.text
        property alias placeholder: input.placeholderText
        spacing: 3
        Layout.fillWidth: true

        Text {
            id: cap
            font.family: Theme.monoFont
            font.pixelSize: 9
            font.letterSpacing: 1.1
            color: Theme.fgMuted
            text: ""
        }
        TextField {
            id: input
            Layout.fillWidth: true
            font.family: Theme.textFont
            font.pixelSize: 12
            color: Theme.fgMain
            placeholderTextColor: Qt.rgba(1, 1, 1, 0.22)
            selectByMouse: true
            padding: 7
            background: Rectangle {
                color: Theme.bgInput
                radius: 8
                border.width: 1
                border.color: input.activeFocus ? Theme.accent : Qt.rgba(1, 1, 1, 0.07)
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.padCard
        spacing: 8

        RowLayout {
            spacing: 8
            Field {
                label: "COMPANY"
                placeholder: "Keysight"
                text: root.vCompany
                onTextChanged: root.vCompany = text
            }
            Field {
                label: "LOCATION"
                placeholder: "Gurugram"
                text: root.vLocation
                onTextChanged: root.vLocation = text
            }
        }

        Field {
            label: "ROLE"
            placeholder: "Multiphysics Modeling & Engineering Automation Intern"
            text: root.vRole
            onTextChanged: root.vRole = text
        }

        RowLayout {
            spacing: 8
            Field {
                label: "RESUME SENT"
                placeholder: "Vansh-Keysight-Multiphysics.pdf"
                text: root.vResume
                onTextChanged: root.vResume = text
            }
            Field {
                label: "DUE  (YYYY-MM-DD HH:MM)"
                placeholder: "2026-08-17 09:30"
                text: root.vDue
                onTextChanged: root.vDue = text
            }
        }

        Field {
            label: "NOTES"
            placeholder: "why this role, known gaps, next step"
            text: root.vNotes
            onTextChanged: root.vNotes = text
        }

        // Status as chips: seven fixed values, so a dropdown would hide them
        // behind a click for no gain.
        Flow {
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: Theme.statuses
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool active: root.vStatus === modelData
                    radius: Theme.radiusChip
                    height: 22
                    width: label.implicitWidth + 18
                    color: active ? Qt.alpha(Theme.statusColor(modelData), 0.22) : Theme.bgInput
                    border.width: 1
                    border.color: active ? Theme.statusColor(modelData) : Qt.rgba(1, 1, 1, 0.06)

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                        color: active ? Theme.statusColor(modelData) : Theme.fgMuted
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.vStatus = modelData
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                visible: !root.isNew
                radius: 10
                implicitHeight: 30
                implicitWidth: 66
                color: delMouse.containsMouse ? Qt.alpha(Theme.accentRed, 0.18) : "transparent"
                border.width: 1
                border.color: Qt.alpha(Theme.accentRed, 0.5)
                Text {
                    anchors.centerIn: parent
                    text: "Delete"
                    font.family: Theme.textFont
                    font.pixelSize: 12
                    color: Theme.accentRed
                }
                MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.deleteRequested(root.entry.id)
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                radius: 10
                implicitHeight: 30
                implicitWidth: 70
                color: cancelMouse.containsMouse ? Theme.bgItemHover : "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.1)
                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.family: Theme.textFont
                    font.pixelSize: 12
                    color: Theme.fgMuted
                }
                MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelled()
                }
            }

            Rectangle {
                radius: 10
                implicitHeight: 30
                implicitWidth: 70
                opacity: root.valid ? 1 : 0.4
                color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: root.isNew ? "Add" : "Save"
                    font.family: Theme.textFont
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.fgOnAccent
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.valid
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.accepted({
                        id: root.entry ? root.entry.id : "",
                        company: root.vCompany.trim(),
                        role: root.vRole.trim(),
                        status: root.vStatus,
                        // Stored ISO-ish so Date.parse and sorting agree.
                        due: root.vDue.trim().replace(" ", "T"),
                        resume: root.vResume.trim(),
                        location: root.vLocation.trim(),
                        notes: root.vNotes.trim()
                    })
                }
            }
        }
    }
}
