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

dnf remove swaylock -y
