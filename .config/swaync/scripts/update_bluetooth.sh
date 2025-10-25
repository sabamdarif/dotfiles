#!/usr/bin/env bash
set +e # disable immediate exit on error

# Check if Bluetooth is actually powered on
if bluetoothctl show 2>/dev/null | grep -qF "Powered: yes"; then
    echo "true" # Button should show as active (colored)
else
    echo "false" # Button should show as inactive
fi

exit 0
