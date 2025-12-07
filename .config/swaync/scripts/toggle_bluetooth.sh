#!/usr/bin/env bash

# Bluetooth Menu Script with Reliable Connection Detection
# Log file location
LOG_FILE="/tmp/bluetooth_menu.log"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG_FILE"
}

# Start new session
echo "========== NEW SESSION ==========" >>"$LOG_FILE"
log "Script started"

# Check if Bluetooth is powered on
if bluetoothctl show 2>/dev/null | grep -qF "Powered: yes"; then
    log "Bluetooth is powered ON"
    toggle="󰂲  Disable Bluetooth"

    # Scan for devices
    notify-send "Scanning for Bluetooth devices..."
    bluetoothctl scan on >/dev/null 2>&1 &
    scan_pid=$!
    sleep 3
    bluetoothctl scan off >/dev/null 2>&1
    kill $scan_pid 2>/dev/null
    wait $scan_pid 2>/dev/null
    sleep 0.5

    # Get all devices
    bt_list=$(bluetoothctl devices | awk '{$1=$2=""; print substr($0,3)}' | sort -u)
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
    log "Bluetooth is powered OFF"
    toggle="󰂯  Enable Bluetooth"
    bt_list=$(bluetoothctl devices Paired | awk '{$1=$2=""; print substr($0,3)}')
    device_list=""
    while IFS= read -r device; do
        device_list+="  $device\n"
    done <<<"$bt_list"
fi

# Show menu
chosen_device=$(echo -e "$toggle\n$device_list" | rofi -dmenu -i -selected-row 1 -p "󰂯  Bluetooth Device: " -theme ~/.config/rofi/wifi-menu.rasi)

log "User selected: '$chosen_device'"

if [ "$chosen_device" = "" ]; then
    log "No device selected, exiting"
    exit
elif [ "$chosen_device" = "󰂯  Enable Bluetooth" ]; then
    log "Enabling Bluetooth..."
    rfkill unblock bluetooth
    sleep 0.5
    bluetoothctl power on
    sleep 1.5
    log "Bluetooth enabled"
    notify-send "Bluetooth Enabled" "Bluetooth has been turned on."
    exec "$0"
elif [ "$chosen_device" = "󰂲  Disable Bluetooth" ]; then
    log "Disabling Bluetooth..."
    bluetoothctl scan off >/dev/null 2>&1
    sleep 0.5
    bluetoothctl power off
    rfkill block bluetooth
    log "Bluetooth disabled"
    notify-send "Bluetooth Disabled" "Bluetooth has been turned off."
else
    # Extract device name (remove icon prefix)
    device_name=$(echo "$chosen_device" | sed 's/^[[:space:]]*[^ ]*[[:space:]]*//')
    log "Processing device: '$device_name'"

    # Get MAC address
    mac_address=$(bluetoothctl devices | grep -F "$device_name" | awk '{print $2}')
    log "MAC address: '$mac_address'"

    if [ -z "$mac_address" ]; then
        log "ERROR: Could not find MAC address"
        notify-send "Error" "Could not find device MAC address."
        exit 1
    fi

    # Turn on Bluetooth if it's off
    if ! bluetoothctl show 2>/dev/null | grep -qF "Powered: yes"; then
        log "Bluetooth was off, powering on..."
        notify-send "Enabling Bluetooth..." "Powering on Bluetooth to connect..."
        rfkill unblock bluetooth
        sleep 0.5
        bluetoothctl power on
        sleep 2.5
        log "Bluetooth powered on"
    fi

    # Stop any scans
    log "Stopping scans..."
    bluetoothctl scan off >/dev/null 2>&1
    sleep 1

    # Simple, reliable approach: Always try to connect first
    # This forces bluetoothctl to refresh its cache and handles all cases
    log "Attempting connection (this also tests current status)..."
    connect_output=$(timeout 3 bluetoothctl connect "$mac_address" 2>&1)
    connect_result=$?

    log "Connect output: $connect_output"
    log "Connect result: $connect_result"

    # Check the output to determine what happened
    if echo "$connect_output" | grep -qi "already connected\|AlreadyConnected"; then
        # Device was already connected, so user wants to disconnect (toggle off)
        log "Device is already connected - disconnecting"
        notify-send "Disconnecting..." "Disconnecting from \"$device_name\"..."
        bluetoothctl disconnect "$mac_address" >/dev/null 2>&1
        sleep 0.5
        notify-send "Bluetooth Disconnected" "Disconnected from \"$device_name\"."

    elif [ $connect_result -eq 0 ] && echo "$connect_output" | grep -qi "Connection successful"; then
        # Successfully connected (device was disconnected before)
        log "Connection successful"
        notify-send "Bluetooth Connected" "Successfully connected to \"$device_name\"."

    else
        # Connection failed - might need pairing
        log "Connection failed, checking if device is paired..."
        is_paired=$(bluetoothctl devices Paired | grep "$mac_address")

        if [[ -z "$is_paired" ]]; then
            # Device not paired, pair it first
            log "Device not paired, pairing now..."
            notify-send "Pairing..." "Attempting to pair with \"$device_name\"..."
            bluetoothctl pair "$mac_address" >/dev/null 2>&1
            sleep 2
            bluetoothctl trust "$mac_address" >/dev/null 2>&1
            log "Device paired and trusted"
        fi

        # Retry connection
        log "Retrying connection..."
        notify-send "Connecting..." "Connecting to \"$device_name\"..."
        if bluetoothctl connect "$mac_address" >/dev/null 2>&1; then
            log "Connection successful on retry"
            notify-send "Bluetooth Connected" "Successfully connected to \"$device_name\"."
        else
            log "Connection failed - device may be unavailable"
            notify-send "Connection Failed" "Could not connect to \"$device_name\". Make sure the device is powered on and in range."
        fi
    fi
fi

log "Script completed"
log "================================"
