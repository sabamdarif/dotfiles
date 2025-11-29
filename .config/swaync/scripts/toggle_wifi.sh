#!/usr/bin/env bash

# WiFi Manager with Rofi - Bash Version
# Full-featured WiFi management script

ROFI_THEME="$HOME/dotfiles/.config/rofi/wifi-menu.rasi"
LOG_FILE="$HOME/.cache/wifi-manager.log"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >>"$LOG_FILE"
}

# Initialize log file
mkdir -p "$(dirname "$LOG_FILE")"
log "INFO" "==================== WiFi Manager Started ===================="

# Check if WiFi is enabled
is_wifi_enabled() {
    [[ $(nmcli radio wifi) == "enabled" ]]
}

# Toggle WiFi on/off
toggle_wifi() {
    if is_wifi_enabled; then
        log "INFO" "Disabling WiFi"
        nmcli radio wifi off
        notify-send -a "WiFi Manager" -i "network-wireless-disabled" "WiFi Disabled" "WiFi has been turned off"
        log "INFO" "WiFi disabled successfully"
        echo "false"
    else
        log "INFO" "Enabling WiFi"
        notify-send -a "WiFi Manager" -i "network-wireless-acquiring" "WiFi Enabling" "Searching for available networks..."
        nmcli radio wifi on
        sleep 2
        # Trigger a scan
        log "INFO" "Starting network scan"
        nmcli device wifi rescan >/dev/null 2>&1 &
        sleep 1
        notify-send -a "WiFi Manager" -i "network-wireless" "WiFi Enabled" "Networks found. Select a network to connect."
        log "INFO" "WiFi enabled successfully, scan initiated"
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
        log "INFO" "Triggering background network rescan"
        nmcli device wifi rescan >/dev/null 2>&1 &
    fi

    # Get network list from cache
    log "DEBUG" "Fetching network list from cache"
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

    log "INFO" "Attempting to connect to network: $ssid (saved: $is_saved)"

    # Get current connection
    local current_connection
    current_connection=$(get_current_connection)

    if [[ -n "$current_connection" ]]; then
        log "INFO" "Currently connected to: $current_connection"
    else
        log "INFO" "No active WiFi connection"
    fi

    # If we're already connected to a different network, disconnect first
    if [[ -n "$current_connection" ]] && [[ "$current_connection" != "$ssid" ]]; then
        log "INFO" "Switching networks: $current_connection -> $ssid"
        send_notification "Switching Network" "Disconnecting from $current_connection..."
        disconnect_current
        sleep 1
    fi

    if [[ "$is_saved" == "true" ]]; then
        # Try to connect to saved network
        log "INFO" "Connecting to saved network: $ssid"
        if nmcli connection up "$ssid" >/dev/null 2>&1; then
            log "INFO" "Successfully connected to saved network: $ssid"
            send_notification "WiFi Connected" "Successfully connected to $ssid"
            return 0
        else
            log "WARN" "Failed to connect using saved connection, may need password"
            # If saved connection fails, prompt for password
            if [[ -z "$password" ]]; then
                password=$(prompt_password "$ssid")
                [[ -z "$password" ]] && log "INFO" "User cancelled password prompt" && return 1
            fi
        fi
    fi

    # Connect with password or without
    local output
    if [[ -n "$password" ]]; then
        log "INFO" "Connecting to $ssid with password"
        output=$(nmcli device wifi connect "$ssid" password "$password" 2>&1)
    else
        log "INFO" "Connecting to $ssid without password (open network)"
        output=$(nmcli device wifi connect "$ssid" 2>&1)
    fi

    if [[ $? -eq 0 ]]; then
        log "INFO" "Successfully connected to: $ssid"
        send_notification "WiFi Connected" "Successfully connected to $ssid"
        return 0
    else
        log "ERROR" "Failed to connect to $ssid - $output"
        send_notification "Connection Failed" "Failed to connect to $ssid"
        return 1
    fi
}

# Disconnect from current network
disconnect_current() {
    log "INFO" "Attempting to disconnect from current network"
    if nmcli device disconnect wlan0 >/dev/null 2>&1 ||
        nmcli device disconnect wlp0s20f3 >/dev/null 2>&1; then
        log "INFO" "Successfully disconnected from network"
        send_notification "WiFi Disconnected" "Disconnected from network"
        return 0
    fi
    log "ERROR" "Failed to disconnect from network"
    return 1
}

# Forget network
forget_network() {
    local ssid="$1"
    log "INFO" "Attempting to forget network: $ssid"
    if nmcli connection delete "$ssid" >/dev/null 2>&1; then
        log "INFO" "Successfully forgot network: $ssid"
        send_notification "Network Forgotten" "Removed $ssid from saved networks"
        return 0
    fi
    log "ERROR" "Failed to forget network: $ssid"
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

    log "INFO" "Main menu opened (rescan: $rescan)"

    if ! is_wifi_enabled; then
        log "INFO" "WiFi is currently disabled"
        local options=" Enable WiFi
 Exit"

        local selection
        selection=$(echo "$options" | show_rofi "WiFi (Disabled)")

        # Exit if nothing selected (Esc pressed)
        [[ -z "$selection" ]] && log "INFO" "User cancelled from disabled menu" && return

        if [[ "$selection" == *"Enable WiFi"* ]]; then
            log "INFO" "User selected: Enable WiFi"
            notify-send -a "WiFi Manager" -i "network-wireless-acquiring" "WiFi Enabling" "Searching for available networks..."
            nmcli radio wifi on
            sleep 2
            # Trigger a scan
            nmcli device wifi rescan >/dev/null 2>&1 &
            sleep 1
            notify-send -a "WiFi Manager" -i "network-wireless" "WiFi Enabled" "Networks found. Select a network to connect."
            # Show the network list
            main_menu "false"
        fi
        return
    fi

    log "INFO" "WiFi is currently enabled"

    # Start background scan
    if [[ "$rescan" == "true" ]]; then
        log "INFO" "User requested network rescan"
        notify-send -a "WiFi Manager" -i "network-wireless-acquiring" "Rescanning" "Searching for networks..."
        nmcli device wifi rescan >/dev/null 2>&1 &
        sleep 1
    fi

    # Get current connection
    local current
    current=$(get_current_connection)

    if [[ -n "$current" ]]; then
        log "INFO" "Currently connected to network: $current"
    else
        log "INFO" "Not connected to any network"
    fi

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
    [[ -z "$selection" ]] && log "INFO" "User cancelled from main menu" && return

    log "INFO" "User selected: $selection"

    case "$selection" in
    *"Refresh"* | *"Rescan"*)
        log "INFO" "Initiating network rescan"
        main_menu "true"
        ;;
    *"Disable WiFi"*)
        log "INFO" "Disabling WiFi via menu"
        toggle_wifi >/dev/null
        ;;
    *"Disconnect from"*)
        log "INFO" "Disconnecting from current network via menu"
        disconnect_current
        ;;
    *"Manage Saved"*)
        log "INFO" "Opening saved networks menu"
        manage_saved_networks
        ;;
    *"Exit"*)
        log "INFO" "User exited WiFi Manager"
        exit 0
        ;;
    *)
        # Network selected - find matching network in list
        # Strip the rofi index prefix (format is "index:display")
        local selection_display="${selection#*:}"
        log "DEBUG" "Selection after stripping index: $selection_display"

        local found=false
        while IFS='|' read -r net_display net_ssid net_security net_in_use net_is_saved; do
            if [[ "$net_display" == "$selection_display" ]]; then
                found=true
                log "INFO" "Network selected: $net_ssid (security: $net_security, saved: $net_is_saved, in_use: $net_in_use)"

                if [[ "$net_in_use" == "*" ]]; then
                    # Already connected
                    log "INFO" "Opening options menu for connected network: $net_ssid"
                    network_options_menu "$net_ssid" "true"
                elif [[ "$net_is_saved" == "true" ]]; then
                    # Saved network
                    log "INFO" "Connecting to saved network: $net_ssid"
                    connect_to_network "$net_ssid" "" "true"
                elif [[ "$net_security" == "Open" ]]; then
                    # Open network
                    log "INFO" "Connecting to open network: $net_ssid"
                    connect_to_network "$net_ssid" "" "false"
                else
                    # Secured network - prompt for password
                    log "INFO" "Prompting for password for secured network: $net_ssid"
                    local password
                    password=$(prompt_password "$net_ssid")
                    if [[ -n "$password" ]]; then
                        connect_to_network "$net_ssid" "$password" "false"
                    else
                        log "INFO" "User cancelled password entry for: $net_ssid"
                    fi
                fi
                break
            fi
        done <<<"$network_list"

        if [[ "$found" == "false" ]]; then
            log "WARN" "Selected network not found in network list: $selection_display"
        fi
        ;;
    esac
}

# Handle command line arguments
case "${1:-}" in
--toggle)
    log "INFO" "CLI command: --toggle"
    toggle_wifi
    ;;
--status)
    log "INFO" "CLI command: --status"
    is_wifi_enabled && echo "true" || echo "false"
    ;;
--enable)
    log "INFO" "CLI command: --enable"
    nmcli radio wifi on
    send_notification "WiFi Enabled" "WiFi has been enabled"
    ;;
--disable)
    log "INFO" "CLI command: --disable"
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
    log "INFO" "Launching interactive menu"
    main_menu "true"
    ;;
esac

log "INFO" "==================== WiFi Manager Exited ===================="
