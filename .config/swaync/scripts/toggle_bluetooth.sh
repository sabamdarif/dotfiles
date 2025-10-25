#!/usr/bin/env bash
set +e # disable immediate exit on error

# Get current Bluetooth state
bt_status=$(bluetoothctl show | grep "Powered: yes")

if [[ $SWAYNC_TOGGLE_STATE == true ]]; then
    # Button is now checked/active - turn ON Bluetooth
    {
        rfkill unblock bluetooth
        bluetoothctl power on
        # Launch blueman-applet if not already running
        if ! pgrep -f blueman-applet >/dev/null; then
            blueman-applet &
        fi
    } >/dev/null 2>&1 || :
else
    # Button is now unchecked/inactive - turn OFF Bluetooth
    {
        bluetoothctl power off
        rfkill block bluetooth
        # Kill blueman-applet if running
        pkill -f blueman-applet
    } >/dev/null 2>&1 || :
fi

exit 0
