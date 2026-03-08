#!/bin/bash
# Toggle wlsunset night light

TEMP_FILE="$HOME/.config/swaync/wlsunset_temp_value"
STATE_FILE="$HOME/.local/state/wlsunset-enabled"
DEFAULT_TEMP=4500

mkdir -p "$(dirname "$STATE_FILE")"

# Read temperature from file, fall back to default
if [[ -f "$TEMP_FILE" ]]; then
    TEMP=$(cat "$TEMP_FILE")
else
    TEMP=$DEFAULT_TEMP
    mkdir -p "$(dirname "$TEMP_FILE")"
    echo "$TEMP" >"$TEMP_FILE"
fi

start_wlsunset() {
    local temp="$1"
    touch "$STATE_FILE"
    # Keep restarting while the state file exists (handles gamma control crashes)
    while [[ -f "$STATE_FILE" ]]; do
        wlsunset -T $((temp + 1)) -t "$temp" 2>/dev/null
        # If it exited but state file still exists, wait briefly then retry
        [[ -f "$STATE_FILE" ]] && sleep 2
    done
}

stop_wlsunset() {
    rm -f "$STATE_FILE"
    pkill -x wlsunset 2>/dev/null
}

if [[ -f "$STATE_FILE" ]]; then
    stop_wlsunset
else
    # Run wlsunset loop in background
    start_wlsunset "$TEMP" &
    disown
fi
