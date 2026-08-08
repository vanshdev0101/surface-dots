#!/usr/bin/env bash
pkill -x rofi && exit 0

mode=$(cat "$HOME/.cache/quickshell/theme_mode" 2>/dev/null | tr -d '[:space:]')
theme=$([ "$mode" = "light" ] && echo style-light || echo style-dark)

mapfile -t sinks < <(pactl list sinks | awk -F': ' '/Name:/{name=$2} /Description:/{print name"\t"$2}')

sel=$(printf '%s\n' "${sinks[@]}" | cut -f2 | rofi -dmenu -theme "$HOME/.config/rofi/${theme}.rasi" -p "Audio Output")
[ -z "$sel" ] && exit 0

name=$(printf '%s\n' "${sinks[@]}" | awk -F'\t' -v s="$sel" '$2==s{print $1; exit}')
pactl set-default-sink "$name"
pactl list short sink-inputs | cut -f1 | xargs -r -I{} pactl move-sink-input {} "$name"
