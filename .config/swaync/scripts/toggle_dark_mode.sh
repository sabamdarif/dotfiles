#!/bin/bash

MODE_FILE="$HOME/.config/matugen/current_mode"

if command -v matugen &>/dev/null; then
    MATUGEN="matugen"
elif [ -x "$HOME/.local/bin/matugen" ]; then
    MATUGEN="$HOME/.local/bin/matugen"
else
    echo "Error: matugen not found (neither in PATH nor at ~/.local/bin/matugen)"
    exit 1
fi

# Find the current background file (any extension)
WALLPAPER_PATH=$(find "$HOME/.config" -maxdepth 1 -name "background.*" ! -name "blurred-background*" | head -n1)
if [ -z "$WALLPAPER_PATH" ]; then
    echo "Error: No background file found in ~/.config (expected background.<ext>)"
    exit 1
fi

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
    CURRENT_MODE=$(cat "$MODE_FILE" | tr -d '[:space:]')
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
script -qec "$MATUGEN image --mode $NEW_MODE --source-color-index 0 $(printf '%q' "$WALLPAPER_PATH")" /dev/null
~/.local/bin/reload_all &
disown
