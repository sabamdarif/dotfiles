#!/bin/bash
# Check if night light is enabled and return status for swaync

STATE_FILE="$HOME/.local/state/wlsunset-enabled"

if [[ -f "$STATE_FILE" ]]; then
    echo "true"
else
    echo "false"
fi
