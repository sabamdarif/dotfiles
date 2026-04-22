#!/bin/bash
# update-click.sh — Waybar custom/updates on-click handler
# Supports: PackageKit (offline updates), dnf, pacman, apt, and flatpak

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ── Terminal detection ─────────────────────────────────────────────────────────

find_terminal() {
    local terms=("ghostty:-e" "foot:-e" "kitty:--" "alacritty:-e"
        "wezterm:start --" "gnome-terminal:--" "xterm:-e" "konsole:-e")
    for entry in "${terms[@]}"; do
        local bin="${entry%%:*}" flag="${entry##*:}"
        command -v "$bin" &>/dev/null && {
            echo "$bin $flag"
            return
        }
    done
}

# ── Package manager detection ──────────────────────────────────────────────────

detect_pkg_manager() {
    if command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v apt &>/dev/null; then
        echo "apt"
    else
        echo "unknown"
    fi
}

detect_aur_helper() {
    if command -v paru &>/dev/null; then
        echo "paru"
    elif command -v yay &>/dev/null; then
        echo "yay"
    else
        echo ""
    fi
}

# Check if pacman-offline is available (Arch-specific offline updates)
check_pacman_offline() {
    if command -v pacman-offline &>/dev/null; then
        echo "yes"
    else
        echo "no"
    fi
}

# Check if PackageKit is available and functional
check_packagekit() {
    if command -v pkcon &>/dev/null; then
        # Test if pkcon is actually working (some systems have it installed but not configured)
        if pkcon --version &>/dev/null; then
            echo "yes"
            return
        fi
    fi
    echo "no"
}

# ── Build the script that runs inside the terminal ─────────────────────────────

build_update_script() {
    local pkg_mgr="$1" aur_helper="$2" has_flatpak="$3" has_pacman_offline="$4" has_pkcon="$5"

    cat <<'HEADER'
#!/bin/bash
sep() { printf '\n'; printf '%.0s─' {1..50}; printf '\n\n'; }
pause() { read -r -p "Press Enter to close..."; }
HEADER

    # Flatpak updates first (if available)
    if [[ "$has_flatpak" == "yes" ]]; then
        cat <<'EOF'
sep
echo "━━━  Flatpak Updates  ━━━"
flatpak update -y || true
EOF
    fi

    # Arch-specific offline update support (preferred for Arch systems)
    if [[ "$has_pacman_offline" == "yes" ]]; then
        cat <<'EOF'
sep
echo "━━━  System Updates (pacman-offline)  ━━━"

# Check for pending offline update
if systemctl list-units --all | grep -q "system-update.target"; then
    if systemctl is-active --quiet system-update.target || [ -L /system-update ]; then
        echo "⚙  Offline update already prepared."
        read -r -p "Reboot now to install updates? [y/N] " r
        if [[ "${r,,}" == "y" ]]; then
            sudo systemctl reboot || { echo "⚠ Failed to reboot. Please reboot manually."; pause; exit 1; }
        fi
        pause; exit 0
    fi
fi

echo "Syncing package databases..."
if sudo pacman -Sy; then
    sep
    # Check if updates are available
    if sudo pacman -Qu 2>/dev/null | grep -q .; then
        echo "Available updates:"
        echo
        sudo pacman -Qu | head -10
        [ $(sudo pacman -Qu | wc -l) -gt 10 ] && echo "... and more"
        echo
        read -r -p "Prepare offline update (install at next reboot)? [y/N] " r
        if [[ "${r,,}" == "y" ]]; then
            sep
            echo "Downloading packages for offline update..."
            echo
            if sudo pacman-offline; then
                echo "✓ Offline update prepared successfully."
                read -r -p "Reboot now to install updates? [y/N] " r
                if [[ "${r,,}" == "y" ]]; then
                    sudo pacman-offline -r || { echo "⚠ Failed to trigger reboot."; pause; exit 1; }
                else
                    echo "Updates will be installed at next reboot."
                fi
            else
                echo "⚠ Failed to prepare offline update."
            fi
        else
            echo "Skipping offline update."
            echo
            read -r -p "Install updates now (without reboot)? [y/N] " r
            if [[ "${r,,}" == "y" ]]; then
                sep
                echo "Installing updates now..."
                echo
                sudo pacman -Syu || echo "⚠ Update failed."
EOF
        if [[ -n "$aur_helper" ]]; then
            cat <<EOF
                sep
                echo "━━━  AUR Updates (${aur_helper})  ━━━"
                ${aur_helper} -Sua || true
EOF
        fi
        cat <<'EOF'
            fi
        fi
    else
        echo "No updates available."
    fi
else
    echo "⚠ Failed to sync package databases."
fi
EOF
    # PackageKit offline update support (works across different package managers)
    elif [[ "$has_pkcon" == "yes" ]]; then
        cat <<'EOF'
sep
echo "━━━  System Updates (PackageKit)  ━━━"

# Check for pending offline update
if pkcon offline-status 2>/dev/null | grep -qi "prepared\|trigger"; then
    echo "⚙  Offline update already prepared."
    read -r -p "Reboot now to install updates? [y/N] " r
    if [[ "${r,,}" == "y" ]]; then
        systemctl reboot || { echo "⚠ Failed to reboot. Please reboot manually."; pause; exit 1; }
    fi
    pause; exit 0
fi

# Refresh package information
echo "Refreshing package information..."
pkcon refresh force || { echo "⚠ Failed to refresh package data."; }

# Check for available updates
if pkcon get-updates 2>/dev/null | grep -q "^[a-zA-Z]"; then
    echo
    echo "Updates are available."
    read -r -p "Prepare offline update (install at next reboot)? [y/N] " r
    if [[ "${r,,}" == "y" ]]; then
        echo "Preparing offline update..."
        if pkcon offline-trigger 2>&1; then
            echo "✓ Offline update prepared successfully."
            read -r -p "Reboot now to install updates? [y/N] " r
            if [[ "${r,,}" == "y" ]]; then
                systemctl reboot || { echo "⚠ Failed to reboot. Please reboot manually."; pause; exit 1; }
            else
                echo "Updates will be installed at next reboot."
            fi
        else
            echo "⚠ Failed to prepare offline update."
            echo "Falling back to direct update..."
            pkcon update -y || echo "⚠ Update failed."
        fi
    else
        echo "Skipping offline update. You can install updates now instead."
        read -r -p "Install updates now (without reboot)? [y/N] " r
        if [[ "${r,,}" == "y" ]]; then
            pkcon update -y || echo "⚠ Update failed."
        fi
    fi
else
    echo "No updates available."
fi
EOF
    # If PackageKit is not available, fall back to package-manager-specific methods
    elif [[ "$pkg_mgr" == "dnf" ]]; then
        cat <<'EOF'
sep
echo "━━━  DNF Updates  ━━━"
if sudo dnf offline-upgrade status &>/dev/null 2>&1; then
    echo "⚙  Offline upgrade already pending."
    read -r -p "Reboot now to install? [y/N] " r
    [[ "${r,,}" == "y" ]] && sudo dnf offline-upgrade reboot
    pause; exit 0
fi
if sudo dnf check-update; then
    echo
    read -r -p "Download & prepare offline upgrade? [y/N] " r
    if [[ "${r,,}" == "y" ]]; then
        sudo dnf offline-upgrade download && {
            read -r -p "Reboot now to install? [y/N] " r
            [[ "${r,,}" == "y" ]] && sudo dnf offline-upgrade reboot
        }
    fi
else
    echo "No DNF updates available."
fi
EOF
    elif [[ "$pkg_mgr" == "pacman" ]]; then
        echo 'sep'
        echo 'echo "━━━  Pacman Updates  ━━━"'
        echo 'sudo pacman -Syu || true'
        if [[ -n "$aur_helper" ]]; then
            echo 'sep'
            echo "echo '━━━  AUR Updates (${aur_helper})  ━━━'"
            echo "${aur_helper} -Sua || true"
        fi
    elif [[ "$pkg_mgr" == "apt" ]]; then
        cat <<'EOF'
sep
echo "━━━  APT Updates  ━━━"
sudo apt update
sep
sudo apt upgrade
EOF
    else
        echo 'echo "⚠ No supported package manager detected (dnf/pacman/apt)."'
    fi

    echo 'sep; echo "✔  Done."; pause'
}

# ── Main ───────────────────────────────────────────────────────────────────────

PKG_MGR=$(detect_pkg_manager)
AUR_HELPER=""
[[ "$PKG_MGR" == "pacman" ]] && AUR_HELPER=$(detect_aur_helper)
HAS_FLATPAK="no"
command -v flatpak &>/dev/null && HAS_FLATPAK="yes"
HAS_PACMAN_OFFLINE="no"
[[ "$PKG_MGR" == "pacman" ]] && HAS_PACMAN_OFFLINE=$(check_pacman_offline)
HAS_PKCON=$(check_packagekit)

TERM_CMD=$(find_terminal)
if [[ -z "$TERM_CMD" ]]; then
    notify-send "Waybar Updates" "No supported terminal found." -u critical
    exit 1
fi

TMPSCRIPT=$(mktemp /tmp/waybar-update-XXXXXX.sh)
chmod +x "$TMPSCRIPT"
build_update_script "$PKG_MGR" "$AUR_HELPER" "$HAS_FLATPAK" "$HAS_PACMAN_OFFLINE" "$HAS_PKCON" >"$TMPSCRIPT"

read -r TERM_BIN TERM_FLAG <<<"$TERM_CMD"
exec "$TERM_BIN" $TERM_FLAG bash "$TMPSCRIPT"
