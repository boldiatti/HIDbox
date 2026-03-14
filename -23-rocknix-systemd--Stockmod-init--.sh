#!/bin/sh
#===============================================================================
# HIDBOX Systemd Service Installer for RG35XX H
# Installs systemd service files for hidboxd and watchdog.
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
SERVICE_DIR="/etc/systemd/system"
BUILDDIR="/tmp/hidbox-systemd"

#===============================================================================
# Create temporary build directory
#===============================================================================
echo "[INFO] Creating build directory: $BUILDDIR"
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

#===============================================================================
# Write service files
#===============================================================================
echo "[INFO] Writing systemd service files..."

# hidboxd.service
cat > "$BUILDDIR/hidboxd.service" << 'EOF'
[Unit]
Description=HIDBOX Daemon
After=multi-user.target bluetooth.service
Wants=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/local/bin/hidboxd
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=hidboxd
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# hidbox-watchdog.service
cat > "$BUILDDIR/hidbox-watchdog.service" << 'EOF'
[Unit]
Description=HIDBOX Watchdog
After=hidboxd.service
Requires=hidboxd.service

[Service]
Type=simple
ExecStart=/usr/local/bin/hidbox-watchdog
Restart=always
RestartSec=10
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

#===============================================================================
# Install service files
#===============================================================================
echo "[INFO] Installing systemd service files to $SERVICE_DIR"
mkdir -p "$SERVICE_DIR"
cp "$BUILDDIR/hidboxd.service" "$BUILDDIR/hidbox-watchdog.service" "$SERVICE_DIR/"
chmod 644 "$SERVICE_DIR/hidboxd.service" "$SERVICE_DIR/hidbox-watchdog.service"

#===============================================================================
# Reload systemd
#===============================================================================
echo "[INFO] Reloading systemd..."
systemctl daemon-reload 2>/dev/null || echo "[WARN] systemctl not available (non-fatal)"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX systemd services installed successfully."
echo "     Services: hidboxd.service, hidbox-watchdog.service"
echo "     To enable: systemctl enable hidboxd.service"
exit 0
EOF