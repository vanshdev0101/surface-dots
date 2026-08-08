pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string configPath:
        Qt.resolvedUrl("usersettings.json").toString().replace("file://", "")

    property bool  useCustomColors: false
    property color customAccent:    "#a7c080"
    property color customBg:        "#141719"
    // Empty = use the bundled default artwork
    property string powerMenuBgImage: ""

    property string weatherApiKey: ""
    property string weatherLat:    ""
    property string weatherLon:    ""

    // Empty = fall back to config.js's hardcoded default
    property string profileImageOverride: ""

    function save() { writeTimer.restart() }

    Timer {
        id: writeTimer
        interval: 60
        onTriggered: root._flush()
    }

    function _flush() {
        configFile.setText(JSON.stringify({
            useCustomColors:      root.useCustomColors,
            customAccent:         String(root.customAccent),
            customBg:             String(root.customBg),
            powerMenuBgImage:     root.powerMenuBgImage,
            weatherApiKey:        root.weatherApiKey,
            weatherLat:           root.weatherLat,
            weatherLon:           root.weatherLon,
            profileImageOverride: root.profileImageOverride
        }))
        _writeKittyAccent()
        _writeWeatherOverride()
    }

    // Push weather creds into the file weather.sh sources, so the shell
    // script picks up whatever's set in the Settings panel without needing
    // its own hardcoded values edited directly.
    function _writeWeatherOverride() {
        var contents = ""
        if (root.weatherApiKey !== "") contents += "API_KEY=\"" + root.weatherApiKey + "\"\n"
        if (root.weatherLat    !== "") contents += "LAT=\""     + root.weatherLat    + "\"\n"
        if (root.weatherLon    !== "") contents += "LON=\""     + root.weatherLon    + "\"\n"
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p ~/.local/state/theme; cat > ~/.local/state/theme/weather_override.conf << 'EOF'\n" + contents + "EOF\n"])
    }

    // Push the accent into kitty via its own included override file, then
    // signal kitty to hot-reload. kitty.conf includes this file after the
    // light/dark theme, so it overrides just the cursor color without
    // touching the base theme's ANSI palette.
    function _writeKittyAccent() {
        var hex = root.useCustomColors ? String(root.customAccent) : ""
        var contents = hex !== "" ? ("cursor " + hex + "\nactive_border_color " + hex + "\n") : ""
        Quickshell.execDetached(["bash", "-c",
            "cat > ~/.local/state/theme/kitty_accent.conf << 'EOF'\n" + contents + "EOF\n" +
            "kill -SIGUSR1 $(pidof kitty) 2>/dev/null || true"])
    }

    function load() {
        try {
            var raw = configFile.text()
            if (!raw || raw.length === 0) return
            var d = JSON.parse(raw)
            if (d.useCustomColors  !== undefined) root.useCustomColors  = d.useCustomColors
            if (d.customAccent     !== undefined) root.customAccent     = d.customAccent
            if (d.customBg         !== undefined) root.customBg         = d.customBg
            if (d.powerMenuBgImage     !== undefined) root.powerMenuBgImage     = d.powerMenuBgImage
            if (d.weatherApiKey        !== undefined) root.weatherApiKey        = d.weatherApiKey
            if (d.weatherLat           !== undefined) root.weatherLat           = d.weatherLat
            if (d.weatherLon           !== undefined) root.weatherLon           = d.weatherLon
            if (d.profileImageOverride !== undefined) root.profileImageOverride = d.profileImageOverride
        } catch(e) {
            console.warn("[Configuration] load failed:", e)
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        preload: true
        onLoaded: { root.load(); root._writeKittyAccent(); root._writeWeatherOverride() }
    }
}
