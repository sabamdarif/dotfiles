#!/bin/bash

WALLPAPER_PATH="$HOME/.config/background"
MODE_FILE="$HOME/.config/matugen/current_mode"

# If argument provided, use it; otherwise toggle
if [ -n "$1" ]; then
    if [ "$1" == "dark" ] || [ "$1" == "light" ]; then
        NEW_MODE="$1"
    else
        echo "Invalid argument. Use 'dark' or 'light'"
        exit 1
    fi
else
    # Toggle mode
    CURRENT_MODE=$(cat "$MODE_FILE")
    if [ "$CURRENT_MODE" == "dark" ]; then
        NEW_MODE="light"
    elif [ "$CURRENT_MODE" == "light" ]; then
        NEW_MODE="dark"
    else
        echo "Unknown mode in $MODE_FILE"
        exit 1
    fi
fi

# Apply the mode
echo "$NEW_MODE" >"$MODE_FILE"
~/.local/bin/matugen image --mode "$NEW_MODE" "$WALLPAPER_PATH"
~/.local/bin/reload_all &
disown
