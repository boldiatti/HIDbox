#!/bin/sh
#===============================================================================
# HIDBOX Safe Installer for RG35XX H (Rocknix / any OS)
# Installs everything self‑contained on the SD card.
# No system files are modified unless you explicitly choose optional steps.
#===============================================================================

set -e

#===============================================================================
# Safety checks
#===============================================================================
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] This installer must be run as root." >&2
    exit 1
fi

# Detect OS (just informational)
if grep -qi "rocknix" /etc/os-release 2>/dev/null; then
    OS="Rocknix"
elif grep -qi "buildroot" /etc/os-release 2>/dev/null; then
    OS="Buildroot (Stock/Modded)"
else
    OS="Unknown"
fi
echo "[INFO] Detected OS: $OS"

#===============================================================================
# Configuration – all paths are under /mnt/SDCARD
#===============================================================================
BASE_DIR="/mnt/SDCARD/App/hidbox"
BIN_DIR="$BASE_DIR/bin"
SHARE_DIR="$BASE_DIR/share"
PROFILE_DIR="$SHARE_DIR/profiles"
OVERLAY_DIR="$SHARE_DIR/overlays"
SKIN_DIR="$SHARE_DIR/skins"
CONFIG_DIR="$BASE_DIR/config"
LAUNCHER_DIR="/mnt/SDCARD/Roms/Apps"
BACKUP_DIR="/mnt/SDCARD/App/hidbox-backup-$(date +%Y%m%d-%H%M%S)"

#===============================================================================
# Backup existing installation
#===============================================================================
if [ -d "$BASE_DIR" ]; then
    echo "[INFO] Backing up existing hidbox installation to $BACKUP_DIR"
    mv "$BASE_DIR" "$BACKUP_DIR"
fi

#===============================================================================
# Create directory structure
#===============================================================================
echo "[INFO] Creating directories under $BASE_DIR"
mkdir -p "$BIN_DIR" "$PROFILE_DIR" "$OVERLAY_DIR" "$SKIN_DIR" "$CONFIG_DIR"

#===============================================================================
# Copy binaries (assumed to be in same directory as this script)
#===============================================================================
echo "[INFO] Installing binaries to $BIN_DIR"
cp hidboxd hidbox-ui hidbox-config hidbox-ipc hidbox-profile hidbox-usb hidbox-bt hidbox-watchdog "$BIN_DIR/" 2>/dev/null || true
chmod 755 "$BIN_DIR"/*

#===============================================================================
# Create default profiles
#===============================================================================
echo "[INFO] Creating default profiles in $PROFILE_DIR"

cat > "$PROFILE_DIR/rg35xxh.json" << 'EOF'
{
    "name": "RG35XXH Native",
    "deadzone": 2000,
    "invert_lx": false,
    "invert_ly": false,
    "invert_rx": false,
    "invert_ry": false
}
EOF

cat > "$PROFILE_DIR/xbox360.json" << 'EOF'
{
    "name": "Xbox 360",
    "deadzone": 2500,
    "invert_lx": false,
    "invert_ly": true,
    "invert_rx": false,
    "invert_ry": true
}
EOF

cat > "$PROFILE_DIR/ps4.json" << 'EOF'
{
    "name": "PS4",
    "deadzone": 2000,
    "invert_lx": false,
    "invert_ly": false,
    "invert_rx": false,
    "invert_ry": false
}
EOF

cat > "$PROFILE_DIR/switch_pro.json" << 'EOF'
{
    "name": "Switch Pro",
    "deadzone": 2200,
    "invert_lx": false,
    "invert_ly": true,
    "invert_rx": false,
    "invert_ry": true
}
EOF

cat > "$PROFILE_DIR/generic.json" << 'EOF'
{
    "name": "Generic",
    "deadzone": 2000,
    "invert_lx": false,
    "invert_ly": false,
    "invert_rx": false,
    "invert_ry": false
}
EOF

#===============================================================================
# Create default config
#===============================================================================
echo "[INFO] Creating default config in $CONFIG_DIR"
cat > "$CONFIG_DIR/config.json" << 'EOF'
{
    "default_profile": "rg35xxh",
    "deadzone": 2000,
    "bt_enabled": true,
    "usb_enabled": true,
    "display_timeout": 60
}
EOF

#===============================================================================
# Create overlay and skin placeholders
#===============================================================================
echo "[INFO] Creating overlay and skin directories (placeholders)"
mkdir -p "$OVERLAY_DIR"/{xbox360,ps4,switch_pro,rg35xxh}
mkdir -p "$SKIN_DIR"/{default,dark,classic}

echo "Place PNG overlay files here" > "$OVERLAY_DIR/xbox360/README.txt"
echo "Place PNG skin files here" > "$SKIN_DIR/default/README.txt"

#===============================================================================
# Create launchers for Apps section
#===============================================================================
echo "[INFO] Creating launchers in $LAUNCHER_DIR"
mkdir -p "$LAUNCHER_DIR"

cat > "$LAUNCHER_DIR/hidboxd.sh" << EOF
#!/bin/sh
cd "$BIN_DIR"
exec ./hidboxd
EOF
chmod 755 "$LAUNCHER_DIR/hidboxd.sh"

cat > "$LAUNCHER_DIR/hidbox-ui.sh" << EOF
#!/bin/sh
cd "$BIN_DIR"
exec ./hidbox-ui
EOF
chmod 755 "$LAUNCHER_DIR/hidbox-ui.sh"

# (Optional launchers for tools – you can add more if desired)

#===============================================================================
# Optional system integration (user must confirm)
#===============================================================================
echo ""
echo "========================================="
echo "HIDBOX core installed successfully in:"
echo "  $BASE_DIR"
echo "========================================="
echo ""
echo "Do you want to install optional system integration files?"
echo "These files help with autostart and device permissions,"
echo "but they will be placed in writable user directories"
echo "(/storage/.config/...) and will NOT modify read-only system areas."
echo "You can always remove them later."
read -p "Install optional system integration? (y/N): " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    echo "[INFO] Installing optional systemd service (for Rocknix)..."

    # systemd user services directory (writable)
    USER_SYSTEMD_DIR="/storage/.config/system.d"
    mkdir -p "$USER_SYSTEMD_DIR"

    cat > "$USER_SYSTEMD_DIR/hidboxd.service" << EOF
[Unit]
Description=HIDBOX Daemon
After=multi-user.target bluetooth.service

[Service]
Type=simple
ExecStart=$BIN_DIR/hidboxd
Restart=always
RestartSec=10
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    cat > "$USER_SYSTEMD_DIR/hidbox-watchdog.service" << EOF
[Unit]
Description=HIDBOX Watchdog
After=hidboxd.service

[Service]
Type=simple
ExecStart=$BIN_DIR/hidbox-watchdog
Restart=always
RestartSec=10
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    echo "[INFO] Installing udev rules (for device permissions)..."
    USER_UDEV_DIR="/storage/.config/udev/rules.d"
    mkdir -p "$USER_UDEV_DIR"
    cat > "$USER_UDEV_DIR/99-hidbox.rules" << 'EOF'
KERNEL=="hidraw*", MODE="0666"
KERNEL=="hidg*", MODE="0666"
SUBSYSTEM=="input", GROUP="input", MODE="0660"
EOF

    echo "[INFO] Reloading systemd and udev..."
    systemctl --user daemon-reload 2>/dev/null || true
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true

    echo "[OK] Optional system integration installed."
else
    echo "[INFO] Skipping system integration."
fi

#===============================================================================
# Uninstall note
#===============================================================================
cat << EOF

=========================================
HIDBOX installation complete!

To uninstall, simply delete:
  $BASE_DIR
  $LAUNCHER_DIR/hidboxd.sh
  $LAUNCHER_DIR/hidbox-ui.sh

If you installed system integration, remove:
  /storage/.config/system.d/hidboxd.service
  /storage/.config/system.d/hidbox-watchdog.service
  /storage/.config/udev/rules.d/99-hidbox.rules
=========================================
EOF

exit 0