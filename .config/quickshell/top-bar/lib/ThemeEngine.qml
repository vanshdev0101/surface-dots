import QtQuick

QtObject {
    id: root
    property bool isDarkMode: true
    function _clampL(v) { return Math.max(0, Math.min(1, v)) }

    // Sizing & Fonts 
    readonly property int    radiusOuter: 24
    readonly property int    radiusInner: 16
    readonly property int    padCard:     12
    readonly property int    gapCard:     10
    readonly property int    btnH:        54
    readonly property int    sliderH:     24
    readonly property string textFont:    "Manrope"
    readonly property string iconFont:    "Symbols Nerd Font"

    // 1) Surfaces 
    readonly property color bgPanel:     isDarkMode ? Qt.rgba(20/255, 23/255, 25/255, 0.88)
                                                    : Qt.rgba(237/255, 197/255, 198/255, 0.69)
    readonly property color bgMain:      Configuration.useCustomColors ? Configuration.customBg : (isDarkMode ? "#141719"  : "#a6b0a0")
    // Whether bgMain is actually dark -- used instead of isDarkMode to decide
    // which way elevation steps go, since a wallpaper-derived customBg doesn't
    // itself flip when the mode toggle does (it's just whatever hue/lightness
    // was captured at pick time).
    readonly property bool  _bgIsDark:   bgMain.hslLightness < 0.5
    // Card/item/hover are tonal steps up (dark bg) or down (light bg) from
    // bgMain's own hue -- same hue family as the wallpaper-derived background,
    // just progressively lighter/darker "elevation" swatches.
    readonly property color bgCard:      Configuration.useCustomColors
        ? Qt.hsla(bgMain.hslHue, bgMain.hslSaturation, _clampL(bgMain.hslLightness + (_bgIsDark ? 0.04 : -0.05)), 1.0)
        : (isDarkMode ? "#1e2326" : "#edc5c6b0")
    readonly property color bgItem:      Configuration.useCustomColors
        ? Qt.hsla(bgMain.hslHue, bgMain.hslSaturation * 0.9, _clampL(bgMain.hslLightness + (_bgIsDark ? 0.11 : -0.10)), 1.0)
        : (isDarkMode ? "#2d353b" : Qt.rgba(0, 0, 0, 0.05))
    readonly property color bgItemHover: Configuration.useCustomColors
        ? Qt.hsla(bgMain.hslHue, bgMain.hslSaturation * 0.85, _clampL(bgMain.hslLightness + (_bgIsDark ? 0.16 : -0.15)), 1.0)
        : (isDarkMode ? "#374145" : Qt.rgba(0, 0, 0, 0.08))
    readonly property color bgWidget:    bgItem
    readonly property color bgOSD:       isDarkMode ? '#f9515451': '#f9c5c6b0'

    // 2) Text
    // Kept near-neutral (low saturation) so text stays readable regardless of
    // wallpaper hue -- just enough tint to feel like part of the same theme.
    // Target lightness follows bgMain's actual darkness, same reasoning as above.
    readonly property color textPrimary:   Configuration.useCustomColors
        ? Qt.hsla(accent.hslHue, Math.min(0.18, accent.hslSaturation * 0.35), _bgIsDark ? 0.88 : 0.18, 1.0)
        : (isDarkMode ? "#d3c6aa" : "#3c4841")
    readonly property color textSecondary: Configuration.useCustomColors
        ? Qt.hsla(accent.hslHue, Math.min(0.12, accent.hslSaturation * 0.25), _bgIsDark ? 0.68 : 0.32, 1.0)
        : (isDarkMode ? "#9da9a0" : "#232a23")
    readonly property color textOnAccent:  Configuration.useCustomColors
        ? (accent.hslLightness > 0.55
            ? Qt.hsla(accent.hslHue, Math.min(0.25, accent.hslSaturation), 0.12, 1.0)
            : Qt.hsla(accent.hslHue, Math.min(0.15, accent.hslSaturation), 0.92, 1.0))
        : (isDarkMode ? "#232a2e" : "#f0f2d4")
    readonly property color textOSD:       isDarkMode ? '#a7b3aa' : '#5f7b5f'

    // 3) Accents
    readonly property color accent:        Configuration.useCustomColors ? Configuration.customAccent : (isDarkMode ? "#a7c080" : "#3c4841")
    readonly property color accentSlider:  Configuration.useCustomColors
        ? Qt.hsla((accent.hslHue - 0.06 + 1.0) % 1.0, accent.hslSaturation, _clampL(accent.hslLightness + (_bgIsDark ? 0.05 : -0.10)), 1.0)
        : (isDarkMode ? "#83C092" : "#273018")
    readonly property color accentBlue:    "#7AA1A6"
    readonly property color accentRed:     isDarkMode ? "#e67e80" : "#7a2a2a"
    // Second OSD gradient stop: hue-shifted off the accent so the gradient stays two-tone.
    readonly property color accentSlider2: Configuration.useCustomColors
        ? Qt.hsla((accent.hslHue + 0.08) % 1.0,
                  accent.hslSaturation,
                  Math.min(0.78, accent.hslLightness + 0.10), 1.0)
        : (isDarkMode ? "#f1af97" : "#d39984")

    // 4) Lines, hovers, misc
    readonly property color border:          Configuration.useCustomColors
                                                ? Qt.rgba(accent.r, accent.g, accent.b, 0.44)
                                                : (isDarkMode ? "#70a7c080" : "#b9566a35")
    readonly property color outline:         isDarkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color subtleFill:      isDarkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05)
    readonly property color subtleFillHover: isDarkMode ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color hoverSpotlight:  isDarkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10)

    // 5) Weather
    readonly property color weatherColor: isDarkMode ? "#9da9a0" : "#3c4841"
}
