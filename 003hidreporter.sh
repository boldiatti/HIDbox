#!/bin/sh
#===============================================================================
# HIDBOX Assets Installer for RG35XX H
# Copies profiles, overlays, skins, and configuration to the SD card.
#===============================================================================

set -e

#===============================================================================
# Safety checks
#===============================================================================
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] This installer must be run as root." >&2
    exit 1
fi

#===============================================================================
# Configuration
#===============================================================================
APPNAME="hidbox-assets"
APPDIR="/mnt/SDCARD/App/${APPNAME}"
BUILDDIR="/tmp/${APPNAME}-build"
PROFILE_DEST="/usr/local/share/hidbox/profiles"
OVERLAY_DEST="/usr/local/share/hidbox/overlays"
SKIN_DEST="/usr/local/share/hidbox/skins"
CONFIG_DEST="/etc/hidbox"

#===============================================================================
# Create temporary build directory
#===============================================================================
echo "[INFO] Creating build directory: $BUILDDIR"
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

#===============================================================================
# Write asset files
#===============================================================================
echo "[INFO] Writing asset files..."

# Profiles
mkdir -p "$BUILDDIR/profiles"

# rg35xxh.json
cat > "$BUILDDIR/profiles/rg35xxh.json" << 'EOF'
{
    "name": "RG35XXH Native",
    "version": "1.0",
    "deadzone": 2000,
    "mapping": {
        "invert_lx": false,
        "invert_ly": false,
        "invert_rx": false,
        "invert_ry": false
    }
}
EOF

# xbox360.json
cat > "$BUILDDIR/profiles/xbox360.json" << 'EOF'
{
    "name": "Xbox 360",
    "version": "1.0",
    "deadzone": 2500,
    "mapping": {
        "invert_lx": false,
        "invert_ly": true,
        "invert_rx": false,
        "invert_ry": true
    }
}
EOF

# ps4.json
cat > "$BUILDDIR/profiles/ps4.json" << 'EOF'
{
    "name": "PS4 DualShock",
    "version": "1.0",
    "deadzone": 2000,
    "mapping": {
        "invert_lx": false,
        "invert_ly": false,
        "invert_rx": false,
        "invert_ry": false
    }
}
EOF

# switch_pro.json
cat > "$BUILDDIR/profiles/switch_pro.json" << 'EOF'
{
    "name": "Switch Pro",
    "version": "1.0",
    "deadzone": 2200,
    "mapping": {
        "invert_lx": false,
        "invert_ly": true,
        "invert_rx": false,
        "invert_ry": true
    }
}
EOF

# generic.json
cat > "$BUILDDIR/profiles/generic.json" << 'EOF'
{
    "name": "Generic",
    "version": "1.0",
    "deadzone": 2000,
    "mapping": {
        "invert_lx": false,
        "invert_ly": false,
        "invert_rx": false,
        "invert_ry": false
    }
}
EOF

# Overlays (placeholders)
mkdir -p "$BUILDDIR/overlays"
for profile in xbox360 ps4 switch_pro rg35xxh; do
    mkdir -p "$BUILDDIR/overlays/$profile"
    cat > "$BUILDDIR/overlays/$profile/README.txt" << INNER
Place controller skin PNG files here for $profile profile.

Required:
- bg.png
- button_a.png
- button_b.png
- button_x.png
- button_y.png
- dpad.png
- stick_left.png
- stick_right.png
INNER
done

# Skins (placeholders)
mkdir -p "$BUILDDIR/skins"
for skin in default dark classic; do
    mkdir -p "$BUILDDIR/skins/$skin"
    cat > "$BUILDDIR/skins/$skin/README.txt" << INNER
Place skin PNG files here.

Required:
- bg.png (640x480 background)
- controller.png (controller overlay)
- btn_*.png for each button
INNER
done

# Config
mkdir -p "$BUILDDIR/config"
cat > "$BUILDDIR/config/config.json" << 'EOF'
{
    "version": "1.0.0",
    "default_profile": "rg35xxh",
    "deadzone": 2000,
    "background_color": "#1a1a2e",
    "bt_enabled": true,
    "usb_enabled": true,
    "display_timeout": 60,
    "profiles": [
        "rg35xxh",
        "xbox360",
        "ps4",
        "switch_pro",
        "generic"
    ]
}
EOF

#===============================================================================
# Install assets
#===============================================================================
echo "[INFO] Installing profiles to $PROFILE_DEST"
mkdir -p "$PROFILE_DEST"
cp -r "$BUILDDIR/profiles/"* "$PROFILE_DEST/"

echo "[INFO] Installing overlays to $OVERLAY_DEST"
mkdir -p "$OVERLAY_DEST"
cp -r "$BUILDDIR/overlays/"* "$OVERLAY_DEST/"

echo "[INFO] Installing skins to $SKIN_DEST"
mkdir -p "$SKIN_DEST"
cp -r "$BUILDDIR/skins/"* "$SKIN_DEST/"

echo "[INFO] Installing config to $CONFIG_DEST"
mkdir -p "$CONFIG_DEST"
cp "$BUILDDIR/config/config.json" "$CONFIG_DEST/"

#===============================================================================
# Create launcher (optional, just a placeholder)
#===============================================================================
LAUNCHER="/mnt/SDCARD/Roms/Apps/hidbox-assets.sh"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
echo "HIDBOX assets are installed."
echo "Profiles: $PROFILE_DEST"
echo "Overlays: $OVERLAY_DEST"
echo "Skins: $SKIN_DEST"
echo "Config: $CONFIG_DEST/config.json"
read -p "Press Enter to exit"
EOF
chmod 755 "$LAUNCHER"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX assets installed successfully."
echo "     Profiles: $PROFILE_DEST"
echo "     Overlays: $OVERLAY_DEST"
echo "     Skins: $SKIN_DEST"
echo "     Config: $CONFIG_DEST/config.json"
exit 0
EOF