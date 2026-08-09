import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Lib.Card {
    id: root
    Layout.fillWidth: true

    property bool active: false

    readonly property bool themed: root.theme !== null
    readonly property color textPrimary:   themed ? root.theme.textPrimary   : "#d3c6aa"
    readonly property color textSecondary: themed ? root.theme.textSecondary : "#9da9a0"
    readonly property color accent:        themed ? root.theme.accent        : "#a7c080"
    readonly property color accentAlt:     themed ? root.theme.accentSlider  : "#7AA1A6"

    property real contentHeight: contentLayout.implicitHeight + (root.pad * 2)
    implicitHeight: root.active ? contentHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
    visible: implicitHeight > 1
    clip: true

    Lib.CommandPoll {
        id: gpuPoll
        running: root.active && root.visible
        interval: 3000
        command: ["bash", "-lc",
            "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,fan.speed --format=csv,noheader,nounits 2>/dev/null || true"]
        parse: function(out) {
            var parts = String(out || "").trim().split(",").map(function(p) { return p.trim() })
            function num(s) { var n = parseFloat(s); return isFinite(n) ? n : -1 }
            return {
                util:      num(parts[0]),
                vramUsed:  num(parts[1]),
                vramTotal: num(parts[2]),
                temp:      num(parts[3]),
                fan:       num(parts[4])
            }
        }
    }

    readonly property var info: gpuPoll.value || ({ util: -1, vramUsed: -1, vramTotal: -1, temp: -1, fan: -1 })
    readonly property bool available: info.util >= 0
    readonly property real vramPercent: (info.vramTotal > 0) ? (100 * info.vramUsed / info.vramTotal) : 0

    ColumnLayout {
        id: contentLayout
        spacing: 8
        Layout.fillWidth: true
        z: 1

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                text: "GPU  "
                color: root.textPrimary
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.available ? (Math.round(root.info.temp) + "°C") : "—"
                color: root.textSecondary
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 10
            }
        }

        Text {
            visible: !root.available
            text: "nvidia-smi not available"
            color: root.textSecondary
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 11
            opacity: 0.7
        }

        ColumnLayout {
            visible: root.available
            spacing: 4
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: Math.round(root.info.util) + "% utilization"
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(root.info.vramUsed) + " / " + Math.round(root.info.vramTotal) + " MB"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 10
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 7
                radius: 4
                color: root.themed ? root.theme.bgItem : "#2d353b"
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(4, parent.width * (root.vramPercent / 100))
                    color: root.accentAlt
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
            }
        }

        RowLayout {
            visible: root.available
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Fan"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: root.info.fan >= 0 ? (Math.round(root.info.fan) + "%") : "—"
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "VRAM used"
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Text {
                    text: Math.round(root.vramPercent) + "%"
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }
    }
}
