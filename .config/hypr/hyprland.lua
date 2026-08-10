-- =========================================================================
-- @snes19xx · Hyprland 0.55 CONFIG
-- =========================================================================

local mod     = "SUPER"
local alt     = "ALT"
local home    = os.getenv("HOME") or "/home/vanshc"
local scripts = home .. "/.config/hypr/scripts"

-- Import Shader Manager and Inject Core
local shader = require("shader")

-- =========================================================================
-- Monitors
-- =========================================================================
hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1440@60",
    position = "0x0",
    scale    = 1.6,
    bitdepth = 10
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@144",
    position = "1600x0",
    scale    = 1
})


-- =========================================================================
-- Environment Variables
-- =========================================================================
-- Cursor:
local function theme_mode()
    local f = io.open(home .. "/.cache/quickshell/theme_mode", "r")
    if not f then return "dark" end
    local m = f:read("l") or ""
    f:close()
    return m:gsub("%s+", "") == "light" and "light" or "dark"
end

local cursor_theme = "Adwaita"

hl.env("HYPRCURSOR_THEME", cursor_theme)
hl.env("HYPRCURSOR_SIZE",  "24")
hl.env("XCURSOR_THEME",    cursor_theme)
hl.env("XCURSOR_SIZE",     "24")
hl.env("GDK_BACKEND",     "wayland,x11,*")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("TERMINAL",        "kitty")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE",    "kvantum")
hl.env("PAPEL_DIR", home .. "/Pictures/wallpapers")
hl.env("QT_QPA_PLATFORM",      "wayland;xcb")

-- =========================================================================
-- Autostart
-- =========================================================================
hl.on("hyprland.start", function()
    -- Essential/reliable commands first, so a later failure can never block these
    hl.exec_cmd("qs -c top-bar")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dunst")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    shader.toggle("Main")
    -- hyprpolkitagent is started separately via its own systemd --user service
    -- vdirsyncer/mpv/wallpaper images removed: unconfigured/not installed/missing files
end)

-- =========================================================================
-- Workspace Rules
-- =========================================================================
for i = 1, 5  do hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1" }) end
for i = 6, 10 do hl.workspace_rule({ workspace = tostring(i), monitor = "HDMI-A-1" }) end

-- =========================================================================
-- Core Config
-- =========================================================================
hl.config({
    general = {
        gaps_in               = 1,
        gaps_out              = 3,
        border_size           = 1,
        ["col.active_border"]   = "rgba(87b158aa)",
        ["col.inactive_border"] = "rgba(595959aa)",
        resize_on_border      = false,
        allow_tearing         = false,
        layout                = "dwindle"
    },
    decoration = {
        rounding         = 7,
        active_opacity   = 1.0,
        inactive_opacity = 0.9,
        dim_inactive     = false,
        dim_strength     = 0.19,
        dim_around       = 0.6,
        shadow = {
            enabled      = true,
            range        = 3,
            render_power = 17,
            color        = "rgba(44220044)"
        },
        blur = {
            enabled           = true,
            size              = 5,
            passes            = 2,
            new_optimizations = true,
        }
    },
    animations = {
        enabled = true
    },
    dwindle = {
        preserve_split = true,
        smart_resizing = true
    },
    master = {
        new_status = "master"
    },
    group = {
        ["col.border_active"]   = "rgba(00000000)",
        ["col.border_inactive"] = "rgba(00000000)",
        groupbar = {
            enabled              = true,
            height               = 16,
            gradients            = true,
            ["col.active"]       = "rgb(87b158)",
            ["col.inactive"]     = "rgba(2D353Bff)",
            keep_upper_gap       = false,
            indicator_height     = 0,
            indicator_gap        = 0,
            gaps_in              = 0,
            gaps_out             = 9,
            gradient_rounding    = 8,
            font_family          = "Inter",
            font_size            = 11,
            font_weight_active   = "medium",
            font_weight_inactive = "medium",
            text_color           = "rgb(293136)",
            text_color_inactive  = "rgba(e5e6c5ff)",
            text_offset          = 1
        }
    },
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0.35,
        repeat_rate  = 50,
        repeat_delay = 300,
        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true
        }
    },
    xwayland = {
        force_zero_scaling = true
    },
    misc = {
        vrr                      = 1,
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        animate_manual_resizes   = true,
        enable_swallow           = true,
        swallow_regex            = "^(kitty)$"
    },
})

-- =========================================================================
-- Layer Rules
-- =========================================================================
hl.layer_rule({ name = "rofi-anim",       match = { namespace = "^rofi$" },            animation = "slide" })
hl.layer_rule({ name = "volume-osd-anim", match = { namespace = "^volume-osd$" },      animation = "slide" })
hl.layer_rule({ name = "bright-osd-anim", match = { namespace = "^brightness-osd$" },  animation = "slide" })
hl.layer_rule({ name = "theme-osd-anim",  match = { namespace = "^theme-osd$" },       animation = "slide" })
hl.layer_rule({ name = "power-menu-anim", match = { namespace = "^power-menu$" },      animation = "popin", dim_around = true })
hl.layer_rule({ name = "hub-anim",        match = { namespace = "^snes-hub$" },        animation = "slide top" })
hl.layer_rule({ name = "keybinds-anim",   match = { namespace = "^keybinds-cheat$" },  animation = "popin", dim_around = true })
hl.layer_rule({ name = "shell-bar-anim",  match = { namespace = "^shell-bar$" },       animation = "slide top" })
hl.layer_rule({ name = "task-bar-anim",   match = { namespace = "^task-bar-shell$" },  animation = "slide bottom" })

-- =========================================================================
-- Animations
-- =========================================================================
hl.curve("md3_standard", { type = "bezier", points = { {0.2, 0.0}, {0, 1.0} } })
hl.curve("md3_decel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1.0} } })
hl.curve("md3_accel", { type = "bezier", points = { {0.3, 0.0}, {0.8, 0.15} } })

hl.curve("winIn", { type = "spring", mass = 1, stiffness = 350, dampening = 35 })
hl.curve("winOut", { type = "spring", mass = 1, stiffness = 320, dampening = 32 })
hl.curve("winMove", { type = "spring", mass = 1, stiffness = 170, dampening = 22 })

hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, spring = "winIn", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, spring = "winOut", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.2, spring = "winMove", style = "slide" })

hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "md3_standard" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 2, bezier = "md3_standard" })

hl.animation({ leaf = "workspacesIn", enabled = true, speed = 2.4, bezier = "md3_decel", style = "slidefade 15%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.4, bezier = "md3_accel", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "md3_decel", style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 3, bezier = "md3_accel", style = "slide top" })

hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "md3_decel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 2, bezier = "md3_accel" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2.2, bezier = "md3_decel" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2.2, bezier = "md3_accel" })




-- =========================================================================
-- Gestures
-- =========================================================================
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "vertical",   action = "fullscreen" })

-- =========================================================================
-- Keybindings
-- =========================================================================

-- Hub & Modes
hl.bind(mod .. " + A", hl.dsp.global("quickshell:hubToggle")) -- QuickShell Hub
hl.bind(mod .. " + SHIFT + A", hl.dsp.exec_cmd("bash " .. home .. "/.config/rofi/audio-output.sh")) -- Switch audio output
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("bash -c 'pkill -x rofi || ([ \"$(cat ~/.cache/quickshell/theme_mode 2>/dev/null)\" = light ] && ~/.config/rofi/launcher_2.sh || ~/.config/rofi/launcher.sh)'"))  -- Rofi app launcher (top-bar mode)
hl.bind(mod .. " + C", hl.dsp.exec_cmd("bash -c 'pkill -x rofi || { [ \"$(cat ~/.cache/quickshell/theme_mode 2>/dev/null)\" = light ] && s=shaders_menu_light.sh t=style-light || s=shaders_menu.sh t=style-dark; rofi -show shaders -modi \"shaders:$HOME/.config/rofi/$s\" -theme \"$HOME/.config/rofi/$t.rasi\"; }'"))  -- Shader picker (all 16)
hl.bind(mod .. " + SLASH", hl.dsp.exec_cmd("bash -c 'hyprctl layers | grep -q keybinds-cheat && pkill -f \"quickshell -p.*keybinds-cheatsheet\" || quickshell -p " .. home .. "/.config/quickshell/keybinds-cheatsheet/Main.qml'"))  -- Keybinds cheat sheet
hl.bind(mod .. " + SHIFT + W", hl.dsp.global("quickshell:nextWallpaper")) -- Next wallpaper
hl.bind(mod .. " + SHIFT + Q", hl.dsp.global("quickshell:prevWallpaper")) -- Previous wallpaper

-- Apps
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty -e btop"))
hl.bind(mod .. " + Z", hl.dsp.global("quickshell:settingsToggle"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd(home .. "/.config/rofi/clipboard.sh"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("dolphin"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + T", hl.dsp.exec_cmd("tauon"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("hyprpicker -a"))

-- Window Actions
hl.bind(mod .. " + X", hl.dsp.window.close())
hl.bind(mod .. " + F", function() hl.dispatch(hl.dsp.window.fullscreen()) end)
hl.bind(mod .. " + " .. alt .. " + F", hl.dsp.window.pseudo())
hl.bind(mod .. " + DOWN", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + UP",   hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + G",    hl.dsp.group.toggle())

hl.bind(mod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(alt .. " + Tab", hl.dsp.focus({ last = true }))

hl.bind(mod .. " + CTRL + left",  hl.dsp.focus({ workspace = "-1" }))
hl.bind(mod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))

hl.bind(mod .. " + " .. alt .. " + F4", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(alt .. " + F4", hl.dsp.exec_cmd("hyprctl layers | grep -q power-menu || quickshell -p ~/.config/quickshell/top-bar/bar/PowerMenu.qml"))

hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

hl.bind(mod .. " + H",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
-- Pull the focused window back out of the scratchpad. activeWorkspace stays on the
-- real workspace even while special:magic is open, so this is the right target.
hl.bind(mod .. " + S", hl.dsp.exec_cmd("bash -c 'ws=$(hyprctl monitors -j | jq -r \".[] | select(.focused) | .activeWorkspace.id\"); hyprctl dispatch \"hl.dsp.window.move({ workspace = $ws })\"'"))

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/brightnesscontrol.sh d"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(scripts .. "/brightnesscontrol.sh i"))
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh i"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh d"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(scripts .. "/audiocontrol.sh m"))
hl.bind("XF86AudioPlay",         hl.dsp.exec_cmd(scripts .. "/mediacontrol.sh"))

hl.bind("Print",                    hl.dsp.exec_cmd(scripts .. "/screenshot.sh s"))
hl.bind(mod .. " + Print",         hl.dsp.exec_cmd(scripts .. "/screenshot.sh p"))
hl.bind(mod .. " + SHIFT + Print", hl.dsp.exec_cmd(scripts .. "/screenshot.sh sf"))
hl.bind(mod .. " + O",             hl.dsp.exec_cmd(scripts .. "/screenshot.sh m"))

-- =========================================================================
-- Workspace Binds
-- =========================================================================
for i = 1, 9 do
    hl.bind(mod .. " + " .. tostring(i),         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. tostring(i), hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + 0",         hl.dsp.focus({ workspace = 10 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- =========================================================================
-- Mouse Binds
-- =========================================================================
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- =========================================================================
-- Lid Switch
-- =========================================================================
-- switch:off = lid OPEN, switch:on = lid CLOSED
hl.bind("switch:off:Lid Switch", function()
    hl.timer(function()
        hl.exec_cmd("hyprctl dispatch dpms on")
    end, { timeout = 500, type = "oneshot" })
end, { locked = true })

hl.bind("switch:on:Lid Switch", function()
    hl.exec_cmd("hyprctl dispatch dpms off")
end, { locked = true })

-- =========================================================================
-- Window Rules
-- =========================================================================
hl.window_rule({ match = { class = "^kitty$" }, rounding = 8, opacity = "0.9 0.9" })
hl.window_rule({ match = { class = "^org.pwmt.zathura$" }, float = true, size = "750 1000" })
hl.window_rule({ match = { class = "^blueman-manager$" }, float = true, size = "500 300", move = "1165 777", rounding = 10, opacity = "0.90 0.90", border_size = 1, border_color = "rgb(87b158) rgb(2D353B)", animation = "popin", dim_around = true })
hl.window_rule({ match = { class = "^nm-connection-editor$" }, float = true, size = "500 600", center = true, rounding = 10, opacity = "0.95 0.95", border_color = "rgb(87b158)" })
hl.window_rule({ match = { class = "^com.snes.evercal$" }, float = true, size = "1000 650", center = true, border_size = 1, rounding = 8 })
hl.window_rule({ match = { class = "^org.gnome.Lollypop$" }, float = true, size = "900 600" })
hl.window_rule({ match = { class = "^org.kde.plasma-systemmonitor$" }, float = true, size = "1000 700", rounding = 14 })
--hl.window_rule({ match = { class = "^thunar$" }, float = true, size = "900 600", center = true })
hl.window_rule({ match = { class = "^xdm-app$" }, float = true, size = "700 400", rounding = 10, opacity = "0.8 0.8", center = true })
hl.window_rule({ match = { class = "^org.gnome.FileRoller$" }, float = true, size = "500 350", center = true, rounding = 10, border_color = "rgb(87b158)" })
hl.window_rule({ match = { class = "^com.snes.nowplaying$" }, float = true, pin = true, border_size = 1, border_color = "rgb(1e2327)", animation = "slide", move = "1425 16", opacity = "0.9 0.9" })
hl.window_rule({ match = { class = "^xdg-desktop-portal-gtk$" }, float = true, center = true, size = "700 400" })

local portals = { "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland|org.freedesktop.impl.portal.desktop.gtk|org.freedesktop.impl.portal.desktop.kde)$", "^(org.kde.polkit-kde-authentication-agent-1|polkit-gnome-authentication-agent-1|lxqt-policykit-agent|mate-polkit)$", "^(pinentry|pinentry-gtk-2|pinentry-gnome3|gcr-prompter)$", "^(ssh-askpass|sshaskpass)$" }
for _, p in ipairs(portals) do hl.window_rule({ match = { class = p }, tag = "portal-ui" }) end
hl.window_rule({ match = { tag = "portal-ui" }, float = true, center = true, rounding = 10, size = "1100 750", dim_around = true, opacity = "0.95 0.95" })

local dialog_titles = { "^(Open File)(.*)$", "^(Select a File)(.*)$", "^(Choose wallpaper)(.*)$", "^(Open Folder)(.*)$", "^(Save As)(.*)$", "^(Library)(.*)$", "^(File Upload)(.*)$", "^(Extract archive)$", "^(Extract)(.*)$", "^(Extract to)$", "^(Confirm to replace files)$", "^(Rename)(.*)$", "^(Create New Folder)$", "^(Properties)$", "^(File Operation Progress)(.*)$" }
for _, t in ipairs(dialog_titles) do hl.window_rule({ match = { title = t }, float = true, center = true }) end

local dim_dialogs = { "^(Open File)(.*)$", "^(Save As)(.*)$", "^(Confirm to replace files)$" }
for _, t in ipairs(dim_dialogs) do hl.window_rule({ match = { title = t }, dim_around = true }) end

hl.window_rule({ match = { title = "^(Open File)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(Save As)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(File Upload)(.*)$" }, size = "900 600" })
hl.window_rule({ match = { title = "^(Confirm to replace files)$" }, size = "500 300" })
hl.window_rule({ match = { title = "^(File Operation Progress)(.*)$" }, size = "500 300" })
hl.window_rule({ match = { title = "^(Rename)(.*)$" }, size = "450 200" })
hl.window_rule({ match = { title = "^(Create New Folder)$" }, size = "450 200" })
hl.window_rule({ match = { title = "^(Properties)$" }, size = "500 600" })
hl.window_rule({ match = { modal = true }, float = true, center = true, rounding = 10 })