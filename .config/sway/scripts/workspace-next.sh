#!/bin/bash
# Get current workspace
current=$(swaymsg -t get_workspaces | jq '.[] | select(.focused==true).num')
next=$((current + 1))
swaymsg workspace number $next
