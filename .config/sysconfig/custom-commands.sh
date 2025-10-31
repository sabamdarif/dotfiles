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

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

sudo dnf install \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-"$(rpm -E %fedora)".noarch.rpm -y

sudo dnf install \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$(rpm -E %fedora)".noarch.rpm -y

sudo dnf remove swaylock -y

sudo timedatectl set-timezone Asia/Kolkata
sudo systemctl restart systemd-timesyncd.service
sudo timedatectl set-ntp true

flatpak override --user \
    --filesystem=xdg-config/gtk-2.0:ro \
    --filesystem=xdg-config/gtk-3.0:ro \
    --filesystem=xdg-config/gtk-4.0:ro \
    --filesystem=~/.gtkrc-2.0:ro

flatpak override --user \
    --filesystem=xdg-config/qt5ct:ro \
    --filesystem=xdg-config/qt6ct:ro \
    --env=QT_QPA_PLATFORMTHEME=qt6ct

gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty'
systemctl --user enable --now swaync
