import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "lib" as Lib
import "bar" as Bar
import "hub" as Hub

ShellRoot {
    id: root
    // Prefer any connected external monitor over the laptop panel (eDP-1)
    // for the Hub/Settings popup, so it only ever shows on one screen.
    function pickHubScreen() {
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name !== "eDP-1") return Quickshell.screens[i]
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    property var hubScreen: pickHubScreen()

    // ----Theme engine shared by the Hub-------------------------------------
    property bool _isDarkMode: true
    readonly property string _themeModePath: Quickshell.env("HOME") + "/.cache/quickshell/theme_mode"

    FileView {
        id: themeModeFile
        path:         root._themeModePath
        watchChanges: true
        preload:      true
        onLoaded:      root._isDarkMode = (String(text() || "").trim().toLowerCase() !== "light")
        onTextChanged: root._isDarkMode = (String(text() || "").trim().toLowerCase() !== "light")
        onFileChanged: reload()
        onLoadFailed:  root._isDarkMode = true
    }
    // ------------------------------------------------------------------------

    Hub.HubWindow {
        id: hub
        screen: hubScreen
        visible: false
    }

    function toggleHub() {
        hub.visible = !hub.visible
    }

    function toggleSettingsPanel() {
        if (!hub.visible) {
            hub.visible = true
            hub.settingsPanelOpen = true
        } else if (hub.settingsPanelOpen) {
            hub.closeAll()
        } else {
            hub.wallpaperMode = false
            hub.settingsPanelOpen = true
        }
    }

    GlobalShortcut {
        name: "hubToggle"
        description: "Toggle hub"
        onPressed: toggleHub()
    }

    GlobalShortcut {
        name: "settingsToggle"
        description: "Jump straight to settings"
        onPressed: toggleSettingsPanel()
    }

    GlobalShortcut {
        name: "nextWallpaper"
        description: "Switch to the next wallpaper"
        onPressed: hub.nextWallpaper()
    }

    GlobalShortcut {
        name: "prevWallpaper"
        description: "Switch to the previous wallpaper"
        onPressed: hub.prevWallpaper()
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: v
            property var modelData

            Lib.ThemeEngine {
                id: screenTheme
                isDarkMode: root._isDarkMode
            }

            Bar.Bar {
                id: bar
                screen: v.modelData
            }

            Bar.Dock {
                id: dock
                screen: v.modelData
            }

            Lib.BrightnessOSD {
                id: brightnessOsd
                theme: screenTheme
                screen: v.modelData
            }

            Lib.VolumeOSD {
                theme: screenTheme
                screen: v.modelData
            }

            Lib.ThemeOSD {
                theme: screenTheme
                screen: v.modelData
            }

            Connections {
                target: bar
                function onRequestHubToggle() {
                    root.toggleHub()
                }
            }
        }
    }
}
