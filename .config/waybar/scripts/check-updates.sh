#!/bin/bash
# check-updates.sh — Waybar update checker (dnf / pacman / apt)

TOOLTIP_FILE="$HOME/.cache/total-update-tooltip"
mkdir -p "$(dirname "$TOOLTIP_FILE")"

# ── Detection ──────────────────────────────────────────────────────────────────

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

# ── Counters ───────────────────────────────────────────────────────────────────

count_dnf() {
    dnf check-update --quiet 2>/dev/null | grep -c "^[a-zA-Z0-9]" || echo 0
}

count_pacman() {
    checkupdates 2>/dev/null | wc -l || pacman -Qu 2>/dev/null | wc -l || echo 0
}

count_aur() {
    local helper="$1"
    [[ -z "$helper" ]] && {
        echo 0
        return
    }
    "$helper" -Qua 2>/dev/null | wc -l || echo 0
}

count_apt() {
    apt-get -s upgrade 2>/dev/null | grep -c "^Inst " || echo 0
}

count_flatpak() {
    command -v flatpak &>/dev/null || {
        echo 0
        return
    }
    flatpak remote-ls --updates 2>/dev/null | wc -l || echo 0
}

# ── DNF offline status ─────────────────────────────────────────────────────────

dnf_offline_status() {
    { [ -L "/system-update" ] || dnf offline-upgrade status &>/dev/null; } &&
        echo "pending" || echo "none"
}

# ── Main loop ──────────────────────────────────────────────────────────────────

PKG_MGR=$(detect_pkg_manager)
AUR_HELPER=""
[[ "$PKG_MGR" == "pacman" ]] && AUR_HELPER=$(detect_aur_helper)

while true; do
    aur=0
    css_class="$PKG_MGR"

    case "$PKG_MGR" in
    dnf)
        native=$(($(count_dnf)))
        offline=$(dnf_offline_status)
        [[ "$offline" == "pending" ]] && css_class="pending"
        tooltip="DNF: ${native}"
        [[ "$offline" == "pending" ]] && tooltip="${tooltip}\\n⚙ Offline update pending"
        ;;
    pacman)
        native=$(($(count_pacman)))
        aur=$(($(count_aur "$AUR_HELPER")))
        tooltip="Pacman: ${native}"
        [[ -n "$AUR_HELPER" ]] && tooltip="${tooltip}\\nAUR (${AUR_HELPER}): ${aur}"
        ;;
    apt)
        native=$(($(count_apt)))
        tooltip="APT: ${native}"
        ;;
    *)
        native=0
        tooltip="No supported package manager found"
        ;;
    esac

    flatpak=$(($(count_flatpak)))
    command -v flatpak &>/dev/null && tooltip="${tooltip}\\nFlatpak: ${flatpak}"

    total=$((native + aur + flatpak))
    tooltip="${tooltip}\\nTotal: ${total}"

    if [[ "$total" -gt 0 ]]; then
        printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' \
            "$total" "$tooltip" "$css_class" >"$TOOLTIP_FILE"
    else
        printf '{"text":"","tooltip":"No updates available","class":"none"}\n' \
            >"$TOOLTIP_FILE"
    fi

    sleep 300
done
