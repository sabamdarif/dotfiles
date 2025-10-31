#!/bin/bash

# Hyprland Post-Init Service Checker and Theme Generator
# This script ensures all necessary services are running and theme is generated

LOG_FILE="$HOME/.config/hypr/post-init.log"
BACKGROUND_IMAGE="$HOME/.config/background"
COLOR_CSS="$HOME/.config/hypr/colors.conf"
LOCK_FILE="/tmp/hyprland-post-init.lock"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Prevent multiple instances
if [ -f "$LOCK_FILE" ]; then
    log "Post-init already running, exiting..."
    exit 0
fi
touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Wait for Hyprland to fully initialize
log "====== Hyprland Post-Init Starting ======"
log "Waiting 3 seconds for Hyprland to initialize..."
sleep 3

# Function to check if a process is running
is_running() {
    pgrep -x "$1" >/dev/null 2>&1
}

# Function to check if a systemd user service is active
is_service_active() {
    systemctl --user is-active "$1" >/dev/null 2>&1
}

# Function to start a process if not running
ensure_process() {
    local process_name="$1"
    local start_command="$2"

    if is_running "$process_name"; then
        log "✓ $process_name is already running"
        return 0
    else
        log "✗ $process_name not running, starting..."
        eval "$start_command" &
        sleep 1.5
        if is_running "$process_name"; then
            log "✓ $process_name started successfully"
            return 0
        else
            log "✗ Failed to start $process_name"
            return 1
        fi
    fi
}

# Function to ensure systemd service is running
ensure_service() {
    local service_name="$1"

    if is_service_active "$service_name"; then
        log "✓ $service_name is active"
        return 0
    else
        log "✗ $service_name not active, starting..."
        systemctl --user start "$service_name"
        sleep 1
        if is_service_active "$service_name"; then
            log "✓ $service_name started successfully"
            return 0
        else
            log "✗ Failed to start $service_name"
            return 1
        fi
    fi
}

log "--- Checking Background Processes ---"
ensure_process "swww-daemon" "swww-daemon"
ensure_process "mako" "mako"
ensure_process "nm-applet" "nm-applet --indicator"
ensure_process "waybar" "waybar"
ensure_process "swayosd-server" "swayosd-server"
ensure_process "swaync" "swaync"
ensure_process "nwg-dock-hyprland" "nwg-dock-hyprland -d"
ensure_process "hyprshell" "hyprshell run"

# Uncomment these if you use them
# ensure_process "blueman-applet" "blueman-applet"
# ensure_process "kdeconnectd" "kdeconnectd"

log "--- Checking Systemd Services ---"
ensure_service "hyprpolkitagent.service"
ensure_service "hypridle-runner.service"

# Check clipboard manager
if pgrep -f "wl-paste.*cliphist" >/dev/null; then
    log "✓ Clipboard manager (wl-paste) is running"
else
    log "✗ Clipboard manager not running, starting..."
    wl-paste --watch cliphist store &
    log "✓ Clipboard manager started"
fi

# Check and generate colors.conf if needed
log "--- Checking Theme Configuration ---"
if [ ! -f "$COLOR_CSS" ]; then
    log "✗ colors.conf not found, generating..."

    if [ -f "$BACKGROUND_IMAGE" ]; then
        log "Generating color scheme from $BACKGROUND_IMAGE"

        # Run matugen and capture output
        if ~/.cargo/bin/matugen image "$BACKGROUND_IMAGE" 2>&1 | tee -a "$LOG_FILE"; then
            sleep 1
            if [ -f "$COLOR_CSS" ]; then
                log "✓ colors.conf generated successfully"
            else
                log "✗ colors.conf still not found after matugen"
                log "Checking matugen config location..."
                find ~/.config -name "colors.conf" 2>/dev/null | tee -a "$LOG_FILE"
            fi
        else
            log "✗ matugen command failed"
        fi
    else
        log "✗ Background image not found at $BACKGROUND_IMAGE"
        log "Please create a background image at that location"
    fi
else
    log "✓ colors.conf exists"
fi

# Run custom autostart script if it exists
AUTOSTART_SCRIPT="$HOME/.config/hypr/scripts/autostart.sh"
if [ -f "$AUTOSTART_SCRIPT" ] && [ -x "$AUTOSTART_SCRIPT" ]; then
    log "--- Running Custom Autostart Script ---"
    bash "$AUTOSTART_SCRIPT" 2>&1 | tee -a "$LOG_FILE"
else
    log "ℹ Custom autostart script not found or not executable at $AUTOSTART_SCRIPT"
fi

# Reload all components
log "--- Reloading All Components ---"
RELOAD_SCRIPT="$HOME/.local/bin/reload_all"
if [ -f "$RELOAD_SCRIPT" ] && [ -x "$RELOAD_SCRIPT" ]; then
    log "Executing reload_all script"
    "$RELOAD_SCRIPT" 2>&1 | tee -a "$LOG_FILE"
    log "✓ Reload complete"
else
    log "✗ reload_all script not found or not executable at $RELOAD_SCRIPT"
    if [ -f "$RELOAD_SCRIPT" ]; then
        log "Making reload_all executable..."
        chmod +x "$RELOAD_SCRIPT"
    fi
fi

log "====== Post-Init Complete ======"
log ""
