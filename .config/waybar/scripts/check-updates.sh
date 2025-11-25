#!/bin/bash

CACHE_FILE="$HOME/.cache/total-update"
TOOLTIP_FILE="$HOME/.cache/total-update-tooltip"

rm -rf "$CACHE_FILE" "$TOOLTIP_FILE"

mkdir -p "$(dirname "$CACHE_FILE")"

while true; do
    # Count DNF updates
    dnf_updates=$(dnf check-update 2>/dev/null | grep -c "^[a-zA-Z0-9]")

    # Count Flatpak updates
    flatpak_updates=$(flatpak remote-ls flathub --updates 2>/dev/null | wc -l)

    # Total
    total=$((dnf_updates + flatpak_updates))

    # Write count
    echo "$total" >"$CACHE_FILE"

    # Write valid JSON with proper escaping
    printf '{"text":"%s","tooltip":"DNF: %s\\nFlatpak: %s\\nTotal: %s"}\n' \
        "$total" "$dnf_updates" "$flatpak_updates" "$total" >"$TOOLTIP_FILE"

    sleep 300
done
