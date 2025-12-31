#!/bin/bash

niri msg action do-screen-transition --delay-ms 300

# Source color variables from matugen
source "$HOME/.config/swaylock/colors"

# Source font name
source "$HOME/.config/swaylock/font"

swaylock \
    --image "$HOME/.config/blurred-background" \
    --scaling fill \
    --daemonize \
    --ignore-empty-password \
    --font "$CUTTRNT_FONT" \
    --indicator-radius 150 \
    --key-hl-color "$key_hl_color" \
    --ring-color "$ring_color" \
    --text-color "$text_color" \
    --inside-clear-color "$inside_clear_color" \
    --ring-clear-color "$ring_clear_color" \
    --text-clear-color "$text_clear_color" \
    --inside-ver-color "$inside_ver_color" \
    --ring-ver-color "$ring_ver_color" \
    --text-ver-color "$text_ver_color" \
    --bs-hl-color "$bs_hl_color" \
    --inside-wrong-color "$inside_wrong_color" \
    --ring-wrong-color "$ring_wrong_color" \
    --text-wrong-color "$text_wrong_color"
