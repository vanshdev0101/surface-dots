#!/usr/bin/env sh
# Now-playing text for hyprlock. Prints nothing when no player is active.

case "$1" in
    --title)  playerctl metadata title  2>/dev/null ;;
    --artist) playerctl metadata artist 2>/dev/null ;;
esac
