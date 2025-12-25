#!/bin/bash

CACHE_FILE="$HOME/.cache/total-update"
TOOLTIP_FILE="$HOME/.cache/total-update-tooltip"
OFFLINE_STATUS_FILE="$HOME/.cache/offline-update-status"

rm -rf "$CACHE_FILE" "$TOOLTIP_FILE" "$OFFLINE_STATUS_FILE"
mkdir -p "$(dirname "$CACHE_FILE")"

# Function to check if offline update is pending
check_offline_update() {
    if [ -L "/system-update" ] || dnf offline-upgrade status &>/dev/null; then
        echo "pending"
    else
        echo "none"
    fi
}

# Function to download and prepare offline update
prepare_offline_update() {
    notify-send "System Updates" "Downloading updates for offline installation..." -u normal

    if sudo dnf offline-upgrade download 2>&1 | tee /tmp/dnf-offline-download.log; then
        notify-send "System Updates" "Updates ready! Reboot to install." -u normal
        echo "ready" >"$OFFLINE_STATUS_FILE"
        return 0
    else
        notify-send "System Updates" "Failed to prepare updates. Check logs." -u critical
        echo "failed" >"$OFFLINE_STATUS_FILE"
        return 1
    fi
}

# Function to apply offline update with reboot
apply_offline_update() {
    notify-send "System Updates" "Rebooting to install updates..." -u normal
    sleep 2
    sudo dnf offline-upgrade reboot
}

# Handle click action (passed as argument)
if [ "$1" = "prepare" ]; then
    prepare_offline_update
    exit 0
elif [ "$1" = "apply" ]; then
    apply_offline_update
    exit 0
elif [ "$1" = "cancel" ]; then
    sudo dnf offline-upgrade clean
    echo "none" >"$OFFLINE_STATUS_FILE"
    notify-send "System Updates" "Offline update cancelled." -u normal
    exit 0
fi

# Main monitoring loop
while true; do
    # Check offline update status
    offline_status=$(check_offline_update)

    # Count DNF updates
    dnf_updates=$(dnf check-update 2>/dev/null | grep -c "^[a-zA-Z0-9]")

    # Count Flatpak updates
    flatpak_updates=$(flatpak remote-ls --updates 2>/dev/null | wc -l)

    # Total
    total=$((dnf_updates + flatpak_updates))

    # Build tooltip based on offline update status
    if [ "$offline_status" = "pending" ]; then
        tooltip="⚠️ Offline Update Ready\\nReboot to install updates\\n---\\nDNF: $dnf_updates\\nFlatpak: $flatpak_updates\\nTotal: $total"
        display_text="$total ⚡"
    else
        tooltip="DNF: $dnf_updates\\nFlatpak: $flatpak_updates\\nTotal: $total"
        display_text="$total"
    fi

    # Write count
    echo "$total" >"$CACHE_FILE"

    # Write valid JSON with proper escaping
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
        "$display_text" "$tooltip" "$offline_status" >"$TOOLTIP_FILE"

    # Store offline status
    echo "$offline_status" >"$OFFLINE_STATUS_FILE"

    # Check every 5 minutes (300 seconds)
    sleep 300
done
