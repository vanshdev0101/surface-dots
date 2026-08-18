#!/usr/bin/env bash
# Fired on both switch:on and switch:off for the Lid Switch. Reads the
# authoritative kernel ACPI lid state instead of trusting Hyprland's
# switch:on/switch:off naming (that mapping isn't consistent across
# hardware, and got this backwards once already).
state=$(cat /proc/acpi/button/lid/*/state 2>/dev/null | awk '{print $2}')

if [ "$state" = "closed" ]; then
    if hyprctl monitors all | grep -q "Monitor HDMI-A-1"; then
        hyprctl eval "hl.monitor({output = 'eDP-1', disabled = true})"
    else
        hyprctl dispatch dpms off
    fi
else
    hyprctl eval "hl.monitor({output = 'eDP-1', mode = '2560x1440@165', position = '0x0', scale = 1.6, bitdepth = 10, disabled = false})"
    sleep 0.5
    hyprctl dispatch dpms on
fi
