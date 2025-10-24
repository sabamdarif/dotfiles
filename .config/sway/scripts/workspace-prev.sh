#!/bin/bash
current=$(swaymsg -t get_workspaces | jq '.[] | select(.focused==true).num')
prev=$((current - 1))
if [ $prev -lt 1 ]; then
    prev=1
fi
swaymsg workspace number $prev
