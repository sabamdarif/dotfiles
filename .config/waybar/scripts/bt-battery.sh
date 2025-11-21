#!/bin/bash

# Get connected Bluetooth device MAC address
device=$(bluetoothctl devices Connected | head -n1 | awk '{print $2}')

if [ -z "$device" ]; then
    echo ""
    exit 0
fi

# Get battery percentage using BlueZ
battery=$(bluetoothctl info "$device" | grep "Battery Percentage" | awk '{print $4}' | tr -d '()')

if [ -n "$battery" ]; then
    echo " ${battery}%"
else
    # Try alternative method using upower
    battery=$(upower -d | grep -A 20 "$device" | grep percentage | awk '{print $2}')
    if [ -n "$battery" ]; then
        echo " ${battery}"
    else
        echo ""
    fi
fi
