#!/bin/bash

MODE=$(cat "$HOME/.config/matugen/current_mode")

if [ "$MODE" == "dark" ]; then
    echo "true"
else
    echo "false"
fi
