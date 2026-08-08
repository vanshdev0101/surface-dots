#!/usr/bin/env bash

dir="$HOME/.config/rofi"
mode=$(cat "$HOME/.cache/quickshell/theme_mode" 2>/dev/null | tr -d '[:space:]')
if [ "$mode" = "light" ]; then
    theme='style-light'
else
    theme='style-dark'
fi

hyprctl keyword general:border_size 0 > /dev/null

selected=$(cliphist list | rofi -dmenu -theme "${dir}/${theme}.rasi" -p "Clipboard" 2>/dev/null)

hyprctl keyword general:border_size 1 > /dev/null

if [ -z "$selected" ]; then
    exit 0
fi

echo "$selected" | cliphist decode | wl-copy
