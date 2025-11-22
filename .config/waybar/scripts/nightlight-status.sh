#!/bin/bash
# Nightlight status script for Waybar

if pgrep -x wlsunset >/dev/null; then
    # Night light is ON
    echo '{"text": "󰛨", "tooltip": "Night Light: ON\nClick to turn off", "class": "active"}'
else
    # Night light is OFF
    echo '{"text": "󰛨", "tooltip": "Night Light: OFF\nClick to turn on", "class": "inactive"}'
fi
