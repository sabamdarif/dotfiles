#!/bin/bash

STATE_FILE="$HOME/.config/swaync/coffice_state"
STATE_FILE_DATA=$(cat "$STATE_FILE")

# Check if systemd-inhibit process is running
if pgrep -f "systemd-inhibit.*coffice" >/dev/null; then
    # Kill the inhibit process
    pkill -f "systemd-inhibit.*coffice"
    echo "off" >"$STATE_FILE"
else
    # Start inhibiting idle/sleep
    systemd-inhibit --what=idle:sleep --who="coffice" --why="Keep screen awake" sleep infinity &
    echo "on" >"$STATE_FILE"
fi
