import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Io

// Self-contained (no "../lib" import) -- this is only ever loaded from
// PerformanceOSD.qml via `quickshell -p`, and Quickshell's qmlscanner
// refuses to resolve non-singleton types (Lib.Card, Lib.CommandPoll) from
// outside the inferred config-folder root in that context. Inlines the
// same Process+Timer pattern Lib.CommandPoll wraps.

Item {
    id: root
    property QtObject theme: null
    property bool active: false

    readonly property bool themed: root.theme !== null
    readonly property color textPrimary:   themed ? root.theme.textPrimary   : "#d3c6aa"
    readonly property color textSecondary: themed ? root.theme.textSecondary : "#9da9a0"
    readonly property color accent:        themed ? root.theme.accent        : "#a7c080"

    implicitWidth: contentLayout.implicitWidth
    implicitHeight: contentLayout.implicitHeight

    // Severity colors mirror ThemeEngine's own accentRed/accentSlider2 --
    // those two roles are already fixed constants (not wallpaper-derived)
    // in the real ThemeEngine, so reusing the same values here isn't a new
    // hardcoded color, just the same theme constant mirrored into this
    // standalone popup's local theme object the same way accent/bgMain are.
    readonly property string warnColor: themed && root.theme.isDarkMode ? "#f1af97" : "#d39984"
    readonly property string critColor: themed && root.theme.isDarkMode ? "#e67e80" : "#7a2a2a"
    function levelColor(v) {
        if (v >= 90) return critColor
        if (v >= 75) return warnColor
        return accent
    }

    component Poller: QtObject {
        id: pollerRoot
        property int interval: 3000
        property var command: []
        property var parse: function(out) { return out }
        property bool running: true
        property var value: null
        function poll() {
            if (!running || proc.running || !command || command.length === 0) return
            proc.exec(command)
        }
        property Process proc: Process {
            stdout: StdioCollector {
                onStreamFinished: pollerRoot.value = pollerRoot.parse(text ?? "")
            }
        }
        property Timer timer: Timer {
            interval: pollerRoot.interval
            repeat: true
            running: pollerRoot.running
            triggeredOnStart: true
            onTriggered: pollerRoot.poll()
        }
    }

    Poller {
        id: gpuPoll
        running: root.active
        interval: 3000
        command: ["bash", "-lc",
            "nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null || true"]
        parse: function(o) {
            var p = String(o || "").trim().split(",").map(function(s) { return s.trim() })
            var t = parseFloat(p[0]), u = parseFloat(p[1])
            return { temp: isFinite(t) ? Math.round(t) : -1, usage: isFinite(u) ? Math.round(u) : 0 }
        }
    }

    Poller {
        id: cpuPoll
        running: root.active
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

    Poller {
        id: ramPoll
        running: root.active
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

    RowLayout {
        id: contentLayout
        spacing: 28

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

    component Gauge: ColumnLayout {
        id: gaugeRoot
        property real value: 0
        property color ringColor: root.accent
        property string centerText: ""
        property string centerLabel: ""
        property string sideValue: ""
        property string sideLabel: ""
        spacing: 6

        // Unfilled arc: a pale tint of the SAME hue as the filled arc, not a
        // flat theme-neutral gray -- the muted portion of each ring reads as
        // a lighter version of its own color, not a generic track color.
        readonly property color trackColor: Qt.hsla(
            ringColor.hslHue, ringColor.hslSaturation,
            Math.min(0.92, ringColor.hslLightness + (root.themed && root.theme.isDarkMode ? 0.30 : 0.35)),
            1.0)

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 104; implicitHeight: 104

            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    strokeWidth: 9
                    strokeColor: gaugeRoot.trackColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    Behavior on strokeColor { ColorAnimation { duration: 300 } }
                    PathAngleArc {
                        centerX: 52; centerY: 52
                        radiusX: 47; radiusY: 47
                        startAngle: -90
                        sweepAngle: 359.9
                    }
                }
                ShapePath {
                    strokeWidth: 9
                    strokeColor: gaugeRoot.ringColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    Behavior on strokeColor { ColorAnimation { duration: 300 } }
                    PathAngleArc {
                        centerX: 52; centerY: 52
                        radiusX: 47; radiusY: 47
                        startAngle: -90
                        sweepAngle: 360 * Math.max(0.02, Math.min(1, gaugeRoot.value))
                        Behavior on sweepAngle { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: gaugeRoot.centerText
                horizontalAlignment: Text.AlignHCenter
                color: root.textPrimary
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 21
                font.weight: Font.Bold
                font.letterSpacing: -0.3
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Text {
                text: gaugeRoot.centerLabel
                Layout.alignment: Qt.AlignHCenter
                color: root.textSecondary
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 11
                font.weight: Font.Medium
                opacity: 0.85
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                visible: gaugeRoot.sideValue !== ""
                Text {
                    text: gaugeRoot.sideValue
                    color: gaugeRoot.ringColor
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                Text {
                    text: gaugeRoot.sideLabel
                    color: root.textSecondary
                    font.family: root.theme ? root.theme.textFont : "Manrope"
                    font.pixelSize: 10
                    opacity: 0.7
                }
            }
        }
    }
}
