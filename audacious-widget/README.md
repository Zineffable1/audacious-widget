# Audacious Control Widget for KDE Plasma

A system tray widget for Audacious with **working scroll wheel support** on Wayland!

## Features

- **Scroll on tray icon to change volume** (the main feature you wanted!)
- Click to play/pause
- Middle-click to show/hide Audacious window
- Full popup with playback controls
- Volume slider
- Track info display

## Installation

```bash
# Extract the widget
unzip audacious-widget.zip

# Install it
kpackagetool6 --type Plasma/Applet --install audacious-widget

# Or if updating:
kpackagetool6 --type Plasma/Applet --upgrade audacious-widget
```

## Usage

1. Right-click on your panel or desktop
2. Select "Add Widgets..."
3. Search for "Audacious Control"
4. Add it to your system tray or panel

## How It Works

Unlike the broken statusicon-qt plugin which uses QSystemTrayIcon (doesn't support scroll on Wayland), this is a native Plasma widget that:

- Uses MPRIS2 to control Audacious (standard Linux media player protocol)
- Uses QML MouseArea which **actually receives scroll events** on Wayland
- Works as a proper Plasma widget in the system tray

## Scroll Behavior

- Scroll **up** = increase volume by 5%
- Scroll **down** = decrease volume by 5%

You can modify the volume step in main.qml line 65 if you want bigger/smaller increments.

## Requirements

- KDE Plasma 6
- Audacious (any recent version with MPRIS support)

## Troubleshooting

If Audacious doesn't show up:
1. Make sure Audacious is actually running
2. Check that MPRIS is enabled in Audacious (it should be by default)
3. Restart the widget (remove and re-add it)

## Why This Instead of statusicon-qt?

The statusicon-qt plugin uses QSystemTrayIcon, which on Wayland becomes a StatusNotifierItem via DBus. Qt's implementation has a **fundamental bug** where the Scroll DBus method exists but does nothing - there's no way to hook into it from C++/Qt without patching Qt itself.

Plasma widgets use QML and the standard Qt event system which works properly. This is the correct solution for Wayland.
