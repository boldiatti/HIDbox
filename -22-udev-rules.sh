#!/bin/sh
#===============================================================================
# HIDBOX Udev Rules Installer for RG35XX H
# Installs udev rules for HID gadget permissions.
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
RULES_FILE="99-hidbox.rules"
RULES_DEST="/etc/udev/rules.d"
BUILDDIR="/tmp/hidbox-udev-rules"

#===============================================================================
# Create temporary build directory
#===============================================================================
echo "[INFO] Creating build directory: $BUILDDIR"
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

#===============================================================================
# Write udev rules file
#===============================================================================
echo "[INFO] Writing udev rules..."
cat > "$BUILDDIR/$RULES_FILE" << 'EOF'
# HIDBOX udev rules
# Give hidraw devices proper permissions

KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0666"
KERNEL=="hidg*", MODE="0666"
SUBSYSTEM=="input", GROUP="input", MODE="0660"

# Bluetooth HID
KERNEL=="hci*", MODE="0666"

# USB gadget
SUBSYSTEM=="usb", KERNEL=="gadget*", MODE="0666"

# Trigger reload on device add
ACTION=="add", SUBSYSTEM=="input", RUN+="/usr/bin/udevadm trigger"
EOF

#===============================================================================
# Install rules file
#===============================================================================
echo "[INFO] Installing udev rules to $RULES_DEST"
mkdir -p "$RULES_DEST"
cp "$BUILDDIR/$RULES_FILE" "$RULES_DEST/"
chmod 644 "$RULES_DEST/$RULES_FILE"

#===============================================================================
# Reload udev
#===============================================================================
echo "[INFO] Reloading udev rules..."
udevadm control --reload-rules 2>/dev/null || echo "[WARN] udev reload failed (non-fatal)"
udevadm trigger 2>/dev/null || echo "[WARN] udev trigger failed (non-fatal)"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX udev rules installed successfully."
echo "     File: $RULES_DEST/$RULES_FILE"
exit 0
EOF