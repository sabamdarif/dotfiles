#!/usr/bin/env bash

# Check if Bluetooth is powered on
if bluetoothctl show 2>/dev/null | grep -qF "Powered: yes"; then
    toggle="󰂲  Disable Bluetooth"

    # Start scanning for devices
    notify-send "Scanning for Bluetooth devices..."
    bluetoothctl scan on >/dev/null 2>&1 &
    scan_pid=$!
    sleep 3 # Wait longer for scan to find devices

    # Get list of all devices (paired and discovered)
    bt_list=$(bluetoothctl devices | awk '{$1=$2=""; print substr($0,3)}' | sort -u)

    # Stop scanning
    kill $scan_pid 2>/dev/null
    bluetoothctl scan off >/dev/null 2>&1

    # Get paired devices
    paired_devices=$(bluetoothctl devices Paired | awk '{$1=$2=""; print substr($0,3)}')

    # Build device list with icons
    device_list=""
    while IFS= read -r device; do
        if echo "$paired_devices" | grep -qF "$device"; then
            device_list+="  $device\n"
        else
            device_list+="  $device\n"
        fi
    done <<<"$bt_list"
else
    toggle="󰂯  Enable Bluetooth"
    # Only show paired/known devices when Bluetooth is off
    bt_list=$(bluetoothctl devices Paired | awk '{$1=$2=""; print substr($0,3)}')
    device_list=""
    while IFS= read -r device; do
        device_list+="  $device\n"
    done <<<"$bt_list"
fi

# Use rofi to select Bluetooth device
chosen_device=$(echo -e "$toggle\n$device_list" | rofi -dmenu -i -selected-row 1 -p "󰂯  Bluetooth Device: " -theme ~/.config/rofi/wifi-menu.rasi)

if [ "$chosen_device" = "" ]; then
    exit
elif [ "$chosen_device" = "󰂯  Enable Bluetooth" ]; then
    rfkill unblock bluetooth
    sleep 0.5
    bluetoothctl power on
    sleep 1.5 # Wait for Bluetooth to fully initialize
    notify-send "Bluetooth Enabled" "Bluetooth has been turned on."
    # Reopen the menu by re-executing the script
    exec "$0"
elif [ "$chosen_device" = "󰂲  Disable Bluetooth" ]; then
    # Stop any ongoing scans first
    bluetoothctl scan off >/dev/null 2>&1
    sleep 0.5
    bluetoothctl power off
    rfkill block bluetooth
    notify-send "Bluetooth Disabled" "Bluetooth has been turned off."
else
    # Remove icon prefix to get device name
    device_name="${chosen_device:3}"

    # Get MAC address of the device
    mac_address=$(bluetoothctl devices | grep -F "$device_name" | awk '{print $2}')

    if [ -z "$mac_address" ]; then
        notify-send "Error" "Could not find device MAC address."
        exit 1
    fi

    # Check if Bluetooth is powered on, if not, power it on first
    if ! bluetoothctl show 2>/dev/null | grep -qF "Powered: yes"; then
        notify-send "Enabling Bluetooth..." "Powering on Bluetooth to connect..."
        rfkill unblock bluetooth
        sleep 0.5
        bluetoothctl power on
        sleep 2 # Wait for Bluetooth to power on
    fi

    # Check if device is already connected
    is_connected=$(bluetoothctl info "$mac_address" | grep "Connected: yes")

    if [[ -n "$is_connected" ]]; then
        # Disconnect the device
        bluetoothctl disconnect "$mac_address" >/dev/null 2>&1
        notify-send "Bluetooth Disconnected" "Disconnected from \"$device_name\"."
    else
        # Check if device is paired
        is_paired=$(bluetoothctl devices Paired | grep "$mac_address")

        if [[ -z "$is_paired" ]]; then
            # Pair the device first
            notify-send "Pairing..." "Attempting to pair with \"$device_name\"..."
            bluetoothctl pair "$mac_address" >/dev/null 2>&1
            sleep 2
            bluetoothctl trust "$mac_address" >/dev/null 2>&1
        fi

        # Connect to the device
        if bluetoothctl connect "$mac_address" >/dev/null 2>&1; then
            notify-send "Bluetooth Connected" "Successfully connected to \"$device_name\"."
        else
            notify-send "Connection Failed" "Could not connect to \"$device_name\"."
        fi
    fi
fi
