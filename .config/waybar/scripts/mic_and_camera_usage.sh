#!/usr/bin/env bash
set -euo pipefail

# Optional: be nice to the scheduler + disk
command -v ionice >/dev/null && ionice -c3 -p $$
command -v renice >/dev/null && renice 10 $$ >/dev/null

get_mic_users() {
    local -a mic_apps=()

    # Check PipeWire for recording streams
    if command -v pw-cli >/dev/null; then
        while IFS= read -r line; do
            # Look for "Stream/Input/Audio" nodes with state "running"
            if [[ $line =~ application\.process\.binary\ =\ \"([^\"]+)\" ]]; then
                mic_apps+=("${BASH_REMATCH[1]}")
            fi
        done < <(pw-cli list-objects Node 2>/dev/null | grep -A20 "Stream/Input/Audio" | grep -E "(application\.process\.binary|node\.name.*input)" || true)
    # Fallback to PulseAudio
    elif command -v pactl >/dev/null; then
        while IFS= read -r line; do
            if [[ $line =~ application\.process\.binary\ =\ \"([^\"]+)\" ]]; then
                mic_apps+=("${BASH_REMATCH[1]}")
            fi
        done < <(pactl list source-outputs 2>/dev/null || true)
    fi

    printf '%s\n' "${mic_apps[@]}" | sort -u
}

emit() {
    local -A seen=()
    local -a cam_tips=() mic_tips=()

    # Check camera usage (/dev/video*)
    if read -ra cam_pids <<<"$(fuser /dev/video* 2>/dev/null || true)"; then
        local pid comm
        for pid in "${cam_pids[@]}"; do
            [[ -r "/proc/$pid/comm" ]] || continue
            [[ ${seen[$pid]+x} ]] && continue
            seen[$pid]=1
            IFS= read -r comm <"/proc/$pid/comm" || continue
            # unwrap "foo.bar-wrapped" → "bar"
            if [[ $comm =~ \.(.*)-wra?p?pe?d?$ ]]; then
                comm="${BASH_REMATCH[1]}"
            fi
            cam_tips+=("$comm [$pid]")
        done
    fi

    # Check microphone usage via audio server
    while IFS= read -r app; do
        [[ -n $app ]] || continue
        # Try to find PID for this app
        local pid
        pid=$(pgrep -x "$app" -n 2>/dev/null || echo "?")
        mic_tips+=("$app [$pid]")
    done < <(get_mic_users)

    # Build output
    local text="" tooltip=""
    local -a all_tips=()

    if ((${#cam_tips[@]})); then
        text+=""
        local tip
        for tip in "${cam_tips[@]}"; do
            all_tips+=(" $tip")
        done
    fi

    if ((${#mic_tips[@]})); then
        [[ -n $text ]] && text+=" "
        text+=""
        local tip
        for tip in "${mic_tips[@]}"; do
            all_tips+=(" $tip")
        done
    fi

    if ((${#all_tips[@]})); then
        # Join with \r like Waybar tooltip
        printf -v tooltip '%s' "$(
            IFS=$'\r'
            echo "${all_tips[*]}"
        )"
        jq -cn --arg text "$text" --arg tt "$tooltip" '{text:$text, tooltip:$tt}'
        return
    fi

    jq -cn '{text:"", tooltip:"No spying eyes or ears!"}'
}

# initial output
emit

# Poll-based approach since PipeWire/PulseAudio don't have easy inotify hooks
# Check every 2 seconds for changes
while :; do
    sleep 2
    emit
done
