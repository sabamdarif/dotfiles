#!/bin/bash

STATE_FILE="$HOME/.config/waybar/.power_mode_state"
ICON_POWERSAVE="󰌪"
ICON_BALANCED=""
ICON_PERFORMANCE="󰓅"

# Create state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "balanced" >"$STATE_FILE"
fi

get_current_mode() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "balanced"
    fi
}

get_current_governor() {
    # cpufreqctl outputs: "powersave powersave powersave..." (one per core)
    # Just get the first one, redirect all errors
    local governor=$(cpufreqctl.auto-cpufreq --governor 2>/dev/null | head -n1 | awk '{print $1}')
    if [ -z "$governor" ]; then
        echo "unknown"
    else
        echo "$governor"
    fi
}

get_current_epp() {
    # Get EPP value - outputs similar format to governor
    local epp=$(cpufreqctl.auto-cpufreq --epp 2>/dev/null | head -n1 | awk '{print $1}')
    if [ -z "$epp" ]; then
        echo "unknown"
    else
        echo "$epp"
    fi
}

set_power_mode() {
    local mode=$1

    case $mode in
    powersave)
        # Set powersave governor and power EPP
        pkexec cpufreqctl.auto-cpufreq --governor --set=powersave >/dev/null 2>&1
        pkexec cpufreqctl.auto-cpufreq --epp --set=power >/dev/null 2>&1
        echo "powersave" >"$STATE_FILE"
        ;;
    balanced)
        # Set powersave governor with balance_performance EPP
        pkexec cpufreqctl.auto-cpufreq --governor --set=powersave >/dev/null 2>&1
        pkexec cpufreqctl.auto-cpufreq --epp --set=balance_performance >/dev/null 2>&1
        echo "balanced" >"$STATE_FILE"
        ;;
    performance)
        # Set performance governor and performance EPP
        pkexec cpufreqctl.auto-cpufreq --governor --set=performance >/dev/null 2>&1
        pkexec cpufreqctl.auto-cpufreq --epp --set=performance >/dev/null 2>&1
        echo "performance" >"$STATE_FILE"
        ;;
    esac
}

cycle_mode() {
    local current=$(get_current_mode)

    case $current in
    powersave)
        set_power_mode "balanced"
        ;;
    balanced)
        set_power_mode "performance"
        ;;
    performance)
        set_power_mode "powersave"
        ;;
    esac
}

output_json() {
    local mode=$(get_current_mode)
    local governor=$(get_current_governor)
    local epp=$(get_current_epp)

    local icon=""
    local text=""

    case $mode in
    powersave)
        icon="$ICON_POWERSAVE"
        text="Power Saver"
        ;;
    balanced)
        icon="$ICON_BALANCED"
        text="Balanced"
        ;;
    performance)
        icon="$ICON_PERFORMANCE"
        text="Performance"
        ;;
    esac

    # Ensure clean output - only JSON, nothing else
    printf '{"text":"%s","tooltip":"Power Profile: %s\\nGovernor: %s\\nEPP: %s","class":"%s"}\n' \
        "$icon" "$text" "$governor" "$epp" "$mode"
}

# Main logic
case "${1:-status}" in
cycle)
    cycle_mode
    ;;
status)
    output_json
    ;;
*)
    output_json
    ;;
esac
