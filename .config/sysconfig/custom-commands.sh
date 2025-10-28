#!/usr/bin/env bash
# Custom commands to run during system restore
# These commands will be executed after system update but before package installation
#
# Examples:
# echo "Running custom setup..."
# mkdir -p ~/.local/bin
# curl -o ~/.local/bin/some-tool https://example.com/tool
# chmod +x ~/.local/bin/some-tool

# Add your custom commands below:

chsh -s "$(which zsh)"

dnf remove swaylock -y

flatpak override --user \
    --filesystem=xdg-config/gtk-2.0:ro \
    --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem=xdg-config/gtk-4.0:ro \
    --filesystem=~/.gtkrc-2.0:ro

gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty'
systemctl --user enable --now swaync
