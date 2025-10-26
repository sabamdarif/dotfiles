#!/bin/bash
# Toggle wlsunset night light

if pgrep -x wlsunset >/dev/null; then
    pkill -x wlsunset
else
    wlsunset -T 5001 -t 5000 &
fi
