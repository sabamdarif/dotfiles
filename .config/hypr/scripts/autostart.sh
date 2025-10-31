#!/bin/bash

# Function to check if a process is running
is_running() {
    local cmd="$1"

    # Extract the base command (first word/executable)
    local base_cmd exec_name
    base_cmd=$(echo "$cmd" | awk '{print $1}')
    exec_name=$(basename "$base_cmd")

    # Check if process is running by executable name
    if pgrep -x "$exec_name" >/dev/null 2>&1; then
        return 0
    fi

    # Also check with full command pattern for processes with arguments
    if pgrep -f "$cmd" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

# Process all .desktop files in autostart directories
for file in ~/.config/autostart/*.desktop; do
    [ -f "$file" ] || continue

    # Check if Hidden=true
    if grep -q "^Hidden=true" "$file"; then
        continue
    fi

    # Extract Exec line
    exec_line=$(grep '^Exec=' "$file" | head -1 | sed 's/^Exec=//' | sed 's/ %[fFuU]//' | sed 's/ %[kcdnNvm]//g')

    # Run the command in background only if not already running
    if [ -n "$exec_line" ]; then
        if is_running "$exec_line"; then
            echo "Already running: $exec_line"
        else
            echo "Starting: $exec_line"
            sh -c "$exec_line" &
        fi
    fi
done
