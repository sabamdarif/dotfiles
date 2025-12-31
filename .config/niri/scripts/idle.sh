#!/bin/bash

[ ! -d "$HOME/.local/state" ] && mkdir -p "$HOME/.local/state"

pgrep -x swayidle >/dev/null && pkill swayidle

exec "$HOME/.config/swaylock/swayidle.sh"
