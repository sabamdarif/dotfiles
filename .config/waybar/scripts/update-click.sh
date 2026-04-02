#!/bin/bash
# update-click.sh — Waybar custom/updates on-click handler (dnf / pacman / apt)

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

# ── Build the script that runs inside the terminal ─────────────────────────────

build_update_script() {
    local pkg_mgr="$1" aur_helper="$2" has_flatpak="$3"

    cat <<'HEADER'
#!/bin/bash
sep() { printf '\n'; printf '%.0s─' {1..50}; printf '\n\n'; }
pause() { read -r -p "Press Enter to close..."; }
HEADER

    case "$pkg_mgr" in
    dnf)
        cat <<'EOF'
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
        ;;
    pacman)
        echo 'echo "━━━  Pacman Updates  ━━━"'
        echo 'sudo pacman -Syu || true'
        if [[ -n "$aur_helper" ]]; then
            echo 'sep'
            echo "echo '━━━  AUR Updates (${aur_helper})  ━━━'"
            echo "${aur_helper} -Sua || true"
        fi
        ;;
    apt)
        cat <<'EOF'
echo "━━━  APT Updates  ━━━"
sudo apt update
sep
sudo apt upgrade
EOF
        ;;
    *)
        echo 'echo "⚠ No supported package manager detected (dnf/pacman/apt)."'
        ;;
    esac

    if [[ "$has_flatpak" == "yes" ]]; then
        cat <<'EOF'
sep
echo "━━━  Flatpak Updates  ━━━"
flatpak update -y || true
EOF
    fi

    echo 'sep; echo "✔  Done."; pause'
}

# ── Main ───────────────────────────────────────────────────────────────────────

PKG_MGR=$(detect_pkg_manager)
AUR_HELPER=""
[[ "$PKG_MGR" == "pacman" ]] && AUR_HELPER=$(detect_aur_helper)
HAS_FLATPAK="no"
command -v flatpak &>/dev/null && HAS_FLATPAK="yes"

TERM_CMD=$(find_terminal)
if [[ -z "$TERM_CMD" ]]; then
    notify-send "Waybar Updates" "No supported terminal found." -u critical
    exit 1
fi

TMPSCRIPT=$(mktemp /tmp/waybar-update-XXXXXX.sh)
chmod +x "$TMPSCRIPT"
build_update_script "$PKG_MGR" "$AUR_HELPER" "$HAS_FLATPAK" >"$TMPSCRIPT"

read -r TERM_BIN TERM_FLAG <<<"$TERM_CMD"
exec "$TERM_BIN" $TERM_FLAG bash "$TMPSCRIPT"
