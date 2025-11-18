#!/bin/bash

STATE_FILE=$(cat "$HOME/.config/swaync/coffice_state")

# Check if systemd-inhibit process is running
if [ "$STATE_FILE" == "on" ]; then
    echo "true"
elif [ "$STATE_FILE" == "off" ]; then
    echo "false"
fi
