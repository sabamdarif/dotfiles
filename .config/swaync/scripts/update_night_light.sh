#!/bin/bash
# Check if wlsunset is running and return status for swaync

if pgrep -x wlsunset >/dev/null; then
    echo "true"
else
    echo "false"
fi
