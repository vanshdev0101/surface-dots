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

    // Power menu skin: "life" (default) or "cassini". Accents are per-skin,
    // per-theme-mode -- empty string means "use the skin's built-in default".
    property string powerMenuStyle:          "life"
    property string powerMenuLifeAccentDark:  ""
    property string powerMenuLifeAccentLight: ""
    property string powerMenuCassiniAccentDark:  ""
    property string powerMenuCassiniAccentLight: ""

    function resetPowerMenuAccents() {
        powerMenuLifeAccentDark     = ""
        powerMenuLifeAccentLight    = ""
        powerMenuCassiniAccentDark  = ""
        powerMenuCassiniAccentLight = ""
        save()
    }

    property string weatherApiKey: ""
    property string weatherLat:    ""
    property string weatherLon:    ""

    // Empty = fall back to config.js's hardcoded default
    property string profileImageOverride: ""

    // Empty = GitHub stats card stays hidden
    property string githubUsername: ""

    // Bar layer: also drives the bar's own visible height
    property int barExclusiveZone: 46

    // Screen borders. Same story as task-bar: thickness/color are previewed
    // here but actually applying them means editing gaps_out by hand, so the
    // toggles/slider surface a toast telling the user that.
    property int    borderThickness:     7
    property color  borderFrameColor:    "#141719"
    property bool   bordersEnabled:      true
    property bool   bordersForceVisible: false
    property bool   borderUseCustomColor: false

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
            powerMenuStyle:              root.powerMenuStyle,
            powerMenuLifeAccentDark:     root.powerMenuLifeAccentDark,
            powerMenuLifeAccentLight:    root.powerMenuLifeAccentLight,
            powerMenuCassiniAccentDark:  root.powerMenuCassiniAccentDark,
            powerMenuCassiniAccentLight: root.powerMenuCassiniAccentLight,
            weatherApiKey:        root.weatherApiKey,
            weatherLat:           root.weatherLat,
            weatherLon:           root.weatherLon,
            profileImageOverride: root.profileImageOverride,
            githubUsername:       root.githubUsername,
            barExclusiveZone:     root.barExclusiveZone,
            borderThickness:      root.borderThickness,
            borderFrameColor:     String(root.borderFrameColor),
            bordersEnabled:       root.bordersEnabled,
            bordersForceVisible:  root.bordersForceVisible,
            borderUseCustomColor: root.borderUseCustomColor
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
            if (d.powerMenuStyle              !== undefined) root.powerMenuStyle              = d.powerMenuStyle
            if (d.powerMenuLifeAccentDark     !== undefined) root.powerMenuLifeAccentDark     = d.powerMenuLifeAccentDark
            if (d.powerMenuLifeAccentLight    !== undefined) root.powerMenuLifeAccentLight    = d.powerMenuLifeAccentLight
            if (d.powerMenuCassiniAccentDark  !== undefined) root.powerMenuCassiniAccentDark  = d.powerMenuCassiniAccentDark
            if (d.powerMenuCassiniAccentLight !== undefined) root.powerMenuCassiniAccentLight = d.powerMenuCassiniAccentLight
            if (d.weatherApiKey        !== undefined) root.weatherApiKey        = d.weatherApiKey
            if (d.weatherLat           !== undefined) root.weatherLat           = d.weatherLat
            if (d.weatherLon           !== undefined) root.weatherLon           = d.weatherLon
            if (d.profileImageOverride !== undefined) root.profileImageOverride = d.profileImageOverride
            if (d.githubUsername       !== undefined) root.githubUsername       = d.githubUsername
            if (d.barExclusiveZone     !== undefined) root.barExclusiveZone     = d.barExclusiveZone
            if (d.borderThickness      !== undefined) root.borderThickness      = d.borderThickness
            if (d.borderFrameColor     !== undefined) root.borderFrameColor     = d.borderFrameColor
            if (d.bordersEnabled       !== undefined) root.bordersEnabled       = d.bordersEnabled
            if (d.bordersForceVisible  !== undefined) root.bordersForceVisible  = d.bordersForceVisible
            if (d.borderUseCustomColor !== undefined) root.borderUseCustomColor = d.borderUseCustomColor
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
