#!/bin/bash

MODE=$(cat "$HOME/.config/matugen/current_mode")
WALLPAPER_PATH="$HOME/.config/background"

if [ "$MODE" == "dark" ]; then
    echo "light" >"$HOME/.config/matugen/current_mode"
    MODE=$(cat "$HOME/.config/matugen/current_mode")
    ~/.cargo/bin/matugen image --mode "$MODE" "$WALLPAPER_PATH"
    ~/.local/bin/reload_all &
    disown
elif [ "$MODE" == "light" ]; then
    echo "dark" >"$HOME/.config/matugen/current_mode"
    MODE=$(cat "$HOME/.config/matugen/current_mode")
    ~/.cargo/bin/matugen image --mode "$MODE" "$WALLPAPER_PATH"
    ~/.local/bin/reload_all &
    disown
fi
