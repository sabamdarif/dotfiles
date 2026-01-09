#!/bin/bash

# Detect compositor
detect_compositor() {
    if [[ "$XDG_CURRENT_DESKTOP" == "niri" ]]; then
        echo "niri"
    elif [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        echo "hyprland"
    elif [[ "$XDG_CURRENT_DESKTOP" == "sway" ]] || pgrep -x sway >/dev/null; then
        echo "sway"
    else
        echo "unknown"
    fi
}

# Send notification with action to open image
send_notification() {
    local file="$1"
    local message="$2"

    # Use absolute path to avoid issues
    local absolute_file
    absolute_file="$(realpath "$file")"

    notify-send -i "$absolute_file" \
        -A "view=View Image" \
        -A "folder=Open Folder" \
        "󰄀 Screenshot saved" \
        "$message" | while read -r action; do
        case "$action" in
        view)
            loupe "$absolute_file" &
            ;;
        folder)
            xdg-open "$(dirname "$absolute_file")" &
            ;;
        esac
    done &
}

# Find newest screenshot after taking one (for niri)
find_newest_screenshot() {
    local screenshots_before="$1"
    local max_wait=2
    local elapsed=0

    while [[ $elapsed -lt $max_wait ]]; do
        sleep 0.2
        elapsed=$((elapsed + 1))

        # Get current screenshots
        local screenshots_after
        screenshots_after=$(find ~/Pictures/Screenshots -name "screenshot-*.png" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n)

        # Find the new screenshot (one that wasn't in the before list)
        local new_screenshot
        new_screenshot=$(comm -13 <(echo "$screenshots_before" | sort -n) <(echo "$screenshots_after" | sort -n) | tail -n1 | cut -d' ' -f2-)

        if [[ -n "$new_screenshot" && -f "$new_screenshot" ]]; then
            echo "$new_screenshot"
            return 0
        fi
    done

    return 1
}

# Capture current window
capture_current_window() {
    mkdir -p ~/Pictures/Screenshots

    local compositor
    compositor=$(detect_compositor)

    local filename
    filename=~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png

    case "$compositor" in
    hyprland)
        grimblast copysave active "$filename" 2>/dev/null
        if [[ -f "$filename" && -s "$filename" ]]; then
            send_notification "$filename" "Window captured"
        fi
        ;;

    niri)
        # Get list of screenshots before taking new one
        local screenshots_before
        screenshots_before=$(find ~/Pictures/Screenshots -name "screenshot-*.png" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n)

        niri msg action screenshot-window

        # Find the newly created screenshot
        local latest_screenshot
        latest_screenshot=$(find_newest_screenshot "$screenshots_before")

        if [[ -n "$latest_screenshot" ]]; then
            send_notification "$latest_screenshot" "Window captured"
        fi
        ;;

    sway)
        # Get focused window from sway
        local window_info
        window_info=$(swaymsg -t get_tree | jq -r '.. | select(.focused? == true)')

        if [[ -z "$window_info" ]]; then
            return 1
        fi

        # Parse window geometry
        local x y width height
        x=$(echo "$window_info" | jq -r '.rect.x // 0')
        y=$(echo "$window_info" | jq -r '.rect.y // 0')
        width=$(echo "$window_info" | jq -r '.rect.width // 0')
        height=$(echo "$window_info" | jq -r '.rect.height // 0')

        # Check if we got valid geometry
        if [[ "$width" -eq 0 || "$height" -eq 0 ]]; then
            return 1
        fi

        # Capture the window
        grim -g "${x},${y} ${width}x${height}" "$filename" 2>/dev/null

        if [[ $? -eq 0 && -f "$filename" && -s "$filename" ]]; then
            wl-copy <"$filename"
            send_notification "$filename" "Window captured"
        fi
        ;;

    *)
        notify-send "Error" "Unsupported compositor"
        return 1
        ;;
    esac
}

# Capture select area
capture_select_area() {
    mkdir -p ~/Pictures/Screenshots

    local compositor
    compositor=$(detect_compositor)

    local filename
    filename=~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png

    case "$compositor" in
    niri)
        # Get list of screenshots before taking new one
        local screenshots_before
        screenshots_before=$(find ~/Pictures/Screenshots -name "screenshot-*.png" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n)

        niri msg action screenshot

        # Find the newly created screenshot
        local latest_screenshot
        latest_screenshot=$(find_newest_screenshot "$screenshots_before")

        if [[ -n "$latest_screenshot" ]]; then
            send_notification "$latest_screenshot" "Area captured"
        fi
        ;;

    *)
        # Use slurp to select area, then grim to capture
        local geometry
        geometry=$(slurp -b '#00000066' -c '#ffffffff' -w 2 2>/dev/null)

        # Only proceed if user selected an area (didn't cancel)
        if [[ -n "$geometry" ]]; then
            grim -g "$geometry" "$filename" 2>/dev/null

            # Only send notification if screenshot was actually saved
            if [[ -f "$filename" && -s "$filename" ]]; then
                wl-copy <"$filename"
                send_notification "$filename" "Area captured"
            fi
        fi
        ;;
    esac
}

# Capture fullscreen
capture_fullscreen() {
    mkdir -p ~/Pictures/Screenshots

    local compositor
    compositor=$(detect_compositor)

    local filename
    filename=~/Pictures/Screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png

    case "$compositor" in
    hyprland)
        grimblast copysave screen "$filename" 2>/dev/null
        if [[ -f "$filename" && -s "$filename" ]]; then
            send_notification "$filename" "Fullscreen captured"
        fi
        ;;

    niri)
        # Get list of screenshots before taking new one
        local screenshots_before
        screenshots_before=$(find ~/Pictures/Screenshots -name "screenshot-*.png" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n)

        niri msg action screenshot-screen

        # Find the newly created screenshot
        local latest_screenshot
        latest_screenshot=$(find_newest_screenshot "$screenshots_before")

        if [[ -n "$latest_screenshot" ]]; then
            send_notification "$latest_screenshot" "Fullscreen captured"
        fi
        ;;

    sway | *)
        # grim works universally on all Wayland compositors
        grim "$filename" 2>/dev/null

        if [[ -f "$filename" && -s "$filename" ]]; then
            wl-copy <"$filename"
            send_notification "$filename" "Fullscreen captured"
        fi
        ;;
    esac
}

# Parse arguments
case "$1" in
--current-window)
    capture_current_window
    ;;
--select-area)
    capture_select_area
    ;;
--fullscreen | "")
    capture_fullscreen
    ;;
*)
    echo "Usage: $0 [--current-window|--select-area|--fullscreen]"
    exit 1
    ;;
esac
