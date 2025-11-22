#!/usr/bin/env bash

# WiFi Manager with Rofi - Bash Version
# Full-featured WiFi management script

ROFI_THEME="$HOME/dotfiles/.config/rofi/wifi-menu.rasi"

# Check if WiFi is enabled
is_wifi_enabled() {
    [[ $(nmcli radio wifi) == "enabled" ]]
}

# Toggle WiFi on/off
toggle_wifi() {
    if is_wifi_enabled; then
        nmcli radio wifi off
        notify-send -a "WiFi Manager" -i "network-wireless-disabled" "WiFi Disabled" "WiFi has been turned off"
        echo "false"
    else
        nmcli radio wifi on
        sleep 2
        notify-send -a "WiFi Manager" -i "network-wireless" "WiFi Enabled" "WiFi has been turned on"
        echo "true"
    fi
}

# Get saved connections
get_saved_connections() {
    nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | cut -d: -f1
}

# Get current connection
get_current_connection() {
    nmcli -t -f NAME,TYPE,DEVICE connection show --active | grep '802-11-wireless' | grep 'wlan' | cut -d: -f1
}

# Send notification
send_notification() {
    notify-send -a "WiFi Manager" -i "network-wireless" "$1" "$2"
}

# Show rofi menu
show_rofi() {
    local prompt="$1"
    shift
    if [[ -f "$ROFI_THEME" ]]; then
        rofi -dmenu -i -p "$prompt" -format "i:s" -markup-rows -theme "$ROFI_THEME"
    else
        rofi -dmenu -i -p "$prompt" -format "i:s" -markup-rows
    fi
}

# Prompt for password
prompt_password() {
    local ssid="$1"
    if [[ -f "$ROFI_THEME" ]]; then
        rofi -dmenu -password -p "Password for $ssid" -theme "$ROFI_THEME"
    else
        rofi -dmenu -password -p "Password for $ssid"
    fi
}

# Scan networks
scan_networks() {
    local rescan="$1"

    # Trigger background scan if requested
    if [[ "$rescan" == "true" ]]; then
        nmcli device wifi rescan >/dev/null 2>&1 &
    fi

    # Get network list from cache
    nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list
}

# Parse and format networks
format_networks() {
    local saved_connections
    saved_connections=$(get_saved_connections)

    declare -A network_map
    local index=0
    local seen_ssids=""

    while IFS=: read -r ssid signal security in_use; do
        [[ -z "$ssid" ]] && continue

        # Skip duplicates
        if [[ "$seen_ssids" == *"|$ssid|"* ]]; then
            continue
        fi
        seen_ssids="${seen_ssids}|${ssid}|"

        # Signal strength icon
        if [[ $signal -ge 75 ]]; then
            signal_icon="▂▄▆█"
        elif [[ $signal -ge 50 ]]; then
            signal_icon="▂▄▆_"
        elif [[ $signal -ge 25 ]]; then
            signal_icon="▂▄__"
        else
            signal_icon="▂___"
        fi

        # Security icon
        if [[ -z "$security" ]] || [[ "$security" == "--" ]]; then
            security_icon=""
            security="Open"
        else
            security_icon=""
        fi

        # Connection status
        local status=""
        [[ "$in_use" == "*" ]] && status="✓ "

        # Check if saved
        local saved_icon=""
        if echo "$saved_connections" | grep -qx "$ssid"; then
            saved_icon="★ "
        fi

        # Store network info
        local display="${status}${saved_icon}${ssid} ${signal_icon} ${security_icon}"
        echo "${index}:${ssid}:${signal}:${security}:${in_use}:${display}"

        ((index++))
    done
}

# Connect to network
connect_to_network() {
    local ssid="$1"
    local password="$2"
    local is_saved="$3"

    if [[ "$is_saved" == "true" ]]; then
        # Try to connect to saved network
        if nmcli connection up "$ssid" >/dev/null 2>&1; then
            send_notification "WiFi Connected" "Successfully connected to $ssid"
            return 0
        else
            # If saved connection fails, prompt for password
            if [[ -z "$password" ]]; then
                password=$(prompt_password "$ssid")
                [[ -z "$password" ]] && return 1
            fi
        fi
    fi

    # Connect with password or without
    local output
    if [[ -n "$password" ]]; then
        output=$(nmcli device wifi connect "$ssid" password "$password" 2>&1)
    else
        output=$(nmcli device wifi connect "$ssid" 2>&1)
    fi

    if [[ $? -eq 0 ]]; then
        send_notification "WiFi Connected" "Successfully connected to $ssid"
        return 0
    else
        send_notification "Connection Failed" "Failed to connect to $ssid"
        return 1
    fi
}

# Disconnect from current network
disconnect_current() {
    if nmcli device disconnect wlan0 >/dev/null 2>&1 ||
        nmcli device disconnect wlp0s20f3 >/dev/null 2>&1; then
        send_notification "WiFi Disconnected" "Disconnected from network"
        return 0
    fi
    return 1
}

# Forget network
forget_network() {
    local ssid="$1"
    if nmcli connection delete "$ssid" >/dev/null 2>&1; then
        send_notification "Network Forgotten" "Removed $ssid from saved networks"
        return 0
    fi
    return 1
}

# Network options menu
network_options_menu() {
    local ssid="$1"
    local connected="$2"

    local options=""
    if [[ "$connected" == "true" ]]; then
        options=" Disconnect
  Forget Network
󰌑 Back to Menu
 Exit"
    else
        options=" Connect
  Forget Network
󰌑 Back to Menu
 Exit"
    fi

    local selection
    selection=$(echo "$options" | show_rofi "$ssid")

    # Exit if nothing selected (Esc pressed)
    [[ -z "$selection" ]] && return

    case "$selection" in
    *"Disconnect"*)
        disconnect_current
        ;;
    *"Connect"*)
        connect_to_network "$ssid" "" "true"
        ;;
    *"Forget"*)
        forget_network "$ssid"
        ;;
    *"Back"*)
        main_menu "false"
        ;;
    esac
}

# Manage saved networks
manage_saved_networks() {
    local saved_connections
    saved_connections=$(get_saved_connections)

    if [[ -z "$saved_connections" ]]; then
        send_notification "No Saved Networks" "You have no saved WiFi networks"
        return
    fi

    local options="󰌑 Back to Menu
 Exit
───────────────────"

    while IFS= read -r conn; do
        options="${options}
  ${conn}"
    done <<<"$saved_connections"

    local selection
    selection=$(echo "$options" | show_rofi "Saved Networks")

    # Exit if nothing selected (Esc pressed)
    [[ -z "$selection" ]] && return

    case "$selection" in
    *"Back"*)
        main_menu "false"
        ;;
    *"Exit"*)
        exit 0
        ;;
    "  "*)
        local ssid="${selection#  }"
        local confirm_options="✓ Yes, forget this network
✗ No, cancel"
        local confirm
        confirm=$(echo "$confirm_options" | show_rofi "Forget $ssid?")
        if [[ "$confirm" == *"Yes"* ]]; then
            forget_network "$ssid"
            manage_saved_networks
        fi
        ;;
    esac
}

# Main menu
main_menu() {
    local rescan="${1:-true}"

    if ! is_wifi_enabled; then
        local options=" Enable WiFi
 Exit"

        local selection
        selection=$(echo "$options" | show_rofi "WiFi (Disabled)")

        # Exit if nothing selected (Esc pressed)
        [[ -z "$selection" ]] && return

        if [[ "$selection" == *"Enable WiFi"* ]]; then
            toggle_wifi >/dev/null
            main_menu "false"
        fi
        return
    fi

    # Start background scan
    if [[ "$rescan" == "true" ]]; then
        nmcli device wifi rescan >/dev/null 2>&1 &
    fi

    # Get current connection
    local current
    current=$(get_current_connection)

    # Build menu options
    local options=" Refresh / Rescan
 Disable WiFi"

    if [[ -n "$current" ]]; then
        options=" Refresh / Rescan
 Disconnect from $current
 Disable WiFi
  Manage Saved Networks"
    else
        options="${options}
  Manage Saved Networks"
    fi

    options="${options}
 Exit
───────────────────"

    # Get and format networks
    local network_data
    network_data=$(scan_networks "false" | format_networks)

    local saved_connections
    saved_connections=$(get_saved_connections)

    # Count networks and build display
    local network_count=0
    local network_list=""

    while IFS=: read -r idx ssid signal security in_use display; do
        options="${options}
${display}"

        # Check if saved
        local is_saved="false"
        if echo "$saved_connections" | grep -qx "$ssid"; then
            is_saved="true"
        fi

        # Store network info with delimiter
        network_list="${network_list}${display}|${ssid}|${security}|${in_use}|${is_saved}
"

        ((network_count++))
    done <<<"$network_data"

    # Show menu
    local selection
    selection=$(echo "$options" | show_rofi "WiFi Manager - $network_count networks")

    # Exit if nothing selected (Esc pressed)
    [[ -z "$selection" ]] && return

    case "$selection" in
    *"Refresh"* | *"Rescan"*)
        main_menu "true"
        ;;
    *"Disable WiFi"*)
        toggle_wifi >/dev/null
        ;;
    *"Disconnect from"*)
        disconnect_current
        ;;
    *"Manage Saved"*)
        manage_saved_networks
        ;;
    *"Exit"*)
        exit 0
        ;;
    *)
        # Network selected - find matching network in list
        local found=false
        while IFS='|' read -r net_display net_ssid net_security net_in_use net_is_saved; do
            if [[ "$net_display" == "$selection" ]]; then
                found=true

                if [[ "$net_in_use" == "*" ]]; then
                    # Already connected
                    network_options_menu "$net_ssid" "true"
                elif [[ "$net_is_saved" == "true" ]]; then
                    # Saved network
                    connect_to_network "$net_ssid" "" "true"
                elif [[ "$net_security" == "Open" ]]; then
                    # Open network
                    connect_to_network "$net_ssid" "" "false"
                else
                    # Secured network - prompt for password
                    local password
                    password=$(prompt_password "$net_ssid")
                    if [[ -n "$password" ]]; then
                        connect_to_network "$net_ssid" "$password" "false"
                    fi
                fi
                break
            fi
        done <<<"$network_list"
        ;;
    esac
}

# Handle command line arguments
case "${1:-}" in
--toggle)
    toggle_wifi
    ;;
--status)
    is_wifi_enabled && echo "true" || echo "false"
    ;;
--enable)
    nmcli radio wifi on
    send_notification "WiFi Enabled" "WiFi has been enabled"
    ;;
--disable)
    nmcli radio wifi off
    send_notification "WiFi Disabled" "WiFi has been disabled"
    ;;
--help | -h)
    echo "Usage: $0 [--toggle|--status|--enable|--disable]"
    echo "  --toggle   Toggle WiFi on/off"
    echo "  --status   Check WiFi status"
    echo "  --enable   Enable WiFi"
    echo "  --disable  Disable WiFi"
    echo "  (no args)  Show interactive menu"
    ;;
*)
    main_menu "true"
    ;;
esac
