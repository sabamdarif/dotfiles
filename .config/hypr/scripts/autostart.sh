#!/bin/bash

# Process all .desktop files in autostart directories
for file in ~/.config/autostart/*.desktop; do
    [ -f "$file" ] || continue

    # Check if Hidden=true
    if grep -q "^Hidden=true" "$file"; then
        continue
    fi

    # Extract Exec line
    exec_line=$(grep '^Exec=' "$file" | head -1 | sed 's/^Exec=//' | sed 's/ %[fFuU]//' | sed 's/ %[kcdnNvm]//g')

    # Check OnlyShowIn and NotShowIn
    only_show_in=$(grep '^OnlyShowIn=' "$file" | sed 's/^OnlyShowIn=//')
    not_show_in=$(grep '^NotShowIn=' "$file" | sed 's/^NotShowIn=//')

    # Skip if NotShowIn contains Sway
    if echo "$not_show_in" | grep -qi "sway"; then
        continue
    fi

    # If OnlyShowIn is set, check if Sway is in it
    if [ -n "$only_show_in" ] && ! echo "$only_show_in" | grep -qi "sway"; then
        continue
    fi

    # Run the command in background
    if [ -n "$exec_line" ]; then
        sh -c "$exec_line" &
    fi
done
