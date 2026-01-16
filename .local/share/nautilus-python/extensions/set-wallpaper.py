#!/usr/bin/env python3
"""
Nautilus extension to set wallpaper using swww
Install to: ~/.local/share/nautilus-python/extensions/
"""

import os
import subprocess

from gi import require_version

require_version("Nautilus", "4.1")
from gi.repository import Gio, GObject, Nautilus  # type: ignore


class SetWallpaperExtension(GObject.GObject, Nautilus.MenuProvider):
    """Nautilus extension to set wallpaper via custom script"""

    def __init__(self):
        super().__init__()
        self.script_path = os.path.expanduser("~/.config/rofi/bin/set-wallpaper")

    def _is_image_file(self, file_info):
        """Check if the file is an image"""
        if file_info.get_uri_scheme() != "file":
            return False

        mime_type = file_info.get_mime_type()
        if not mime_type:
            return False

        # Check for image MIME types
        image_types = [
            "image/jpeg",
            "image/png",
            "image/gif",
            "image/webp",
            "image/bmp",
            "image/tiff",
            "image/svg+xml",
        ]

        return mime_type in image_types

    def _set_wallpaper(self, menu, file_path):
        """Execute the wallpaper script with the selected image"""
        try:
            # Run the script using Gio.Subprocess
            cmd = [self.script_path, file_path]
            Gio.Subprocess.new(cmd, Gio.SubprocessFlags.NONE)
        except Exception as e:
            print(f"Error setting wallpaper: {e}")

    def _menu_item_activated(self, menu, files):
        """Handle menu item activation"""
        for file_info in files:
            location = file_info.get_location()
            file_path = location.get_path()
            if file_path:
                self._set_wallpaper(menu, file_path)

    def _make_item(self, name, files):
        """Create the menu item"""
        item = Nautilus.MenuItem(
            name=name,
            label="Set as Wallpaper (swww)",
            tip="Set this image as wallpaper using swww",
        )
        item.connect("activate", self._menu_item_activated, files)
        return item

    def get_file_items(self, *args):
        """Return menu items for file selection"""
        # Nautilus 3.0 API passes args (window, files), 4.0 API just passes files
        files = args[0] if len(args) == 1 else args[1]

        # Check if script exists
        if not os.path.exists(self.script_path):
            return []

        # Only show for image files
        image_files = [f for f in files if self._is_image_file(f)]

        if not image_files:
            return []

        return [
            self._make_item(
                name="SetWallpaperExtension::set_wallpaper", files=image_files
            )
        ]

    def get_background_items(self, *args):
        """No background menu items"""
        return []
