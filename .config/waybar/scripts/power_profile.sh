#!/bin/bash

ICON_POWERSAVE="󰌪"
ICON_PERFORMANCE="󰓅"

# Check if using auto-cpufreq daemon or manual control
is_auto_cpufreq_active() {
    systemctl is-active --quiet auto-cpufreq
}

get_current_governor() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
}

get_current_epp() {
    cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null
}

detect_current_mode() {
    local governor=$(get_current_governor)
    local epp=$(get_current_epp)

    # Performance mode: governor=performance AND epp=performance
    # Everything else is powersave
    if [ "$governor" = "performance" ] && [ "$epp" = "performance" ]; then
        echo "performance"
    else
        echo "powersave"
    fi
}

set_power_mode() {
    local mode=$1

    if is_auto_cpufreq_active; then
        # If auto-cpufreq daemon is running, stop it first
        case $mode in
        powersave)
            pkexec sh -c 'systemctl stop auto-cpufreq; echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null; echo power | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null'
            ;;
        performance)
            pkexec sh -c 'systemctl stop auto-cpufreq; echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null; echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null'
            ;;
        esac
    else
        # Direct control without auto-cpufreq
        case $mode in
        powersave)
            pkexec sh -c 'echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null; echo power | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null'
            ;;
        performance)
            pkexec sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null; echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null'
            ;;
        esac
    fi
}

toggle_mode() {
    local current=$(detect_current_mode)

    if [ "$current" = "powersave" ]; then
        echo "Switching to performance mode..." >&2
        set_power_mode "performance"
    else
        echo "Switching to powersave mode..." >&2
        set_power_mode "powersave"
    fi

    # Wait a moment for changes to take effect
    sleep 0.5

    # Show new status
    echo "New mode: $(detect_current_mode)" >&2
}

output_json() {
    local mode=$(detect_current_mode)
    local governor=$(get_current_governor)
    local epp=$(get_current_epp)

    local icon=""
    local text=""
    local extra=""

    # Check if auto-cpufreq is running
    if is_auto_cpufreq_active; then
        extra=" (auto-cpufreq active)"
    fi

    case $mode in
    powersave)
        icon="$ICON_POWERSAVE"
        text="Power Saver"
        ;;
    performance)
        icon="$ICON_PERFORMANCE"
        text="Performance"
        ;;
    esac

    printf '{"text":"%s","tooltip":"Power Profile: %s%s\\nGovernor: %s\\nEPP: %s","class":"%s"}\n' \
        "$icon" "$text" "$extra" "$governor" "$epp" "$mode"
}

# Main logic
case "${1:-status}" in
toggle)
    toggle_mode
    ;;
status)
    output_json
    ;;
*)
    output_json
    ;;
esac
