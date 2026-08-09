import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../lib" as Lib

Lib.Card {
    id: root
    Layout.fillWidth: true

    property bool active: false

    readonly property bool themed: root.theme !== null
    readonly property color textPrimary:   themed ? root.theme.textPrimary   : "#d3c6aa"
    readonly property color textSecondary: themed ? root.theme.textSecondary : "#9da9a0"
    readonly property color accent:        themed ? root.theme.accent        : "#a7c080"
    readonly property color trackColor:    themed ? root.theme.bgItem        : "#2d353b"

    property real contentHeight: contentLayout.implicitHeight + (root.pad * 2)
    implicitHeight: root.active ? contentHeight : 0
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    opacity: root.active ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
    visible: implicitHeight > 1
    clip: true

    readonly property string warnColor: themed && root.theme.isDarkMode ? "#e69875" : "#a55524"
    readonly property string critColor: themed && root.theme.isDarkMode ? "#ff0004" : "#ff001e"
    function levelColor(v) {
        if (v >= 90) return critColor
        if (v >= 75) return warnColor
        return accent
    }

    Lib.CommandPoll {
        id: gpuPoll
        running: root.active && root.visible
        interval: 3000
        command: ["bash", "-lc",
            "nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null || true"]
        parse: function(o) {
            var p = String(o || "").trim().split(",").map(function(s) { return s.trim() })
            var t = parseFloat(p[0]), u = parseFloat(p[1])
            return { temp: isFinite(t) ? Math.round(t) : -1, usage: isFinite(u) ? Math.round(u) : 0 }
        }
    }

    Lib.CommandPoll {
        id: cpuPoll
        running: root.active && root.visible
        interval: 3000
        command: ["bash", "-lc", `
            temp=$(sensors -A 2>/dev/null | grep Tctl | grep -oP '\\+\\K[0-9.]+' | head -n1)
            usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print 100-$8}')
            echo "\${temp:-0}|\${usage:-0}"
        `]
        parse: function(o) {
            var p = String(o || "").trim().split("|")
            return { temp: Math.round(parseFloat(p[0])) || 0, usage: Math.round(parseFloat(p[1])) || 0 }
        }
    }

    Lib.CommandPoll {
        id: ramPoll
        running: root.active && root.visible
        interval: 5000
        command: ["bash", "-lc",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{u=t-a; printf \"%.1f|%.0f\", u/1024/1024, (t-a)/t*100}' /proc/meminfo"]
        parse: function(o) {
            var p = String(o || "").trim().split("|")
            var used = parseFloat(p[0]), pct = parseInt(p[1])
            return { used: isFinite(used) ? used : 0, pct: isFinite(pct) ? pct : 0 }
        }
    }

    readonly property bool gpuAvailable: gpuPoll.value && gpuPoll.value.temp >= 0

    ColumnLayout {
        id: contentLayout
        spacing: 8
        Layout.fillWidth: true
        z: 1

        Text {
            text: "Performance"
            color: root.textPrimary
            font.family: root.theme ? root.theme.textFont : "Manrope"
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            Gauge {
                Layout.fillWidth: true
                visible: root.gpuAvailable
                value: (gpuPoll.value ? gpuPoll.value.temp : 0) / 100
                ringColor: root.levelColor(gpuPoll.value ? gpuPoll.value.temp : 0)
                centerText: (gpuPoll.value ? gpuPoll.value.temp : 0) + "°"
                centerLabel: "GPU temp"
                sideValue: (gpuPoll.value ? gpuPoll.value.usage : 0) + "%"
                sideLabel: "Usage"
            }

            Gauge {
                Layout.fillWidth: true
                value: (cpuPoll.value ? cpuPoll.value.temp : 0) / 100
                ringColor: root.levelColor(cpuPoll.value ? cpuPoll.value.temp : 0)
                centerText: (cpuPoll.value ? cpuPoll.value.temp : 0) + "°"
                centerLabel: "CPU temp"
                sideValue: (cpuPoll.value ? cpuPoll.value.usage : 0) + "%"
                sideLabel: "Usage"
            }

            Gauge {
                Layout.fillWidth: true
                value: (ramPoll.value ? ramPoll.value.pct : 0) / 100
                ringColor: root.levelColor(ramPoll.value ? ramPoll.value.pct : 0)
                centerText: (ramPoll.value ? ramPoll.value.used.toFixed(1) : "0.0") + "GiB"
                centerLabel: "Memory"
                sideValue: (ramPoll.value ? ramPoll.value.pct : 0) + "%"
                sideLabel: "Usage"
            }
        }
    }

    component Gauge: ColumnLayout {
        id: gaugeRoot
        property real value: 0
        property color ringColor: root.accent
        property string centerText: ""
        property string centerLabel: ""
        property string sideValue: ""
        property string sideLabel: ""
        spacing: 4

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 92; implicitHeight: 92

            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeWidth: 8
                    strokeColor: root.trackColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 46; centerY: 46
                        radiusX: 42; radiusY: 42
                        startAngle: -90
                        sweepAngle: 359.9
                    }
                }
                ShapePath {
                    strokeWidth: 8
                    strokeColor: gaugeRoot.ringColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    Behavior on strokeColor { ColorAnimation { duration: 300 } }
                    PathAngleArc {
                        centerX: 46; centerY: 46
                        radiusX: 42; radiusY: 42
                        startAngle: -90
                        sweepAngle: 360 * Math.max(0.02, Math.min(1, gaugeRoot.value))
                        Behavior on sweepAngle { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                Text {
                    text: gaugeRoot.centerText
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0
            Text {
                text: gaugeRoot.centerLabel
                Layout.alignment: Qt.AlignHCenter
                color: root.textSecondary
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 10
                opacity: 0.85
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 3
                visible: gaugeRoot.sideValue !== ""
                Text {
                    text: gaugeRoot.sideValue
                    color: root.textPrimary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                }
                Text {
                    text: gaugeRoot.sideLabel
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 9
                    opacity: 0.7
                }
            }
        }
    }
}
