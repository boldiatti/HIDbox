#!/bin/sh
#===============================================================================
# HIDBOX Init Script Installer for RG35XX H (non-systemd systems)
# Installs init.d script for hidboxd.
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
INIT_DIR="/etc/init.d"
BUILDDIR="/tmp/hidbox-init"

#===============================================================================
# Create temporary build directory
#===============================================================================
echo "[INFO] Creating build directory: $BUILDDIR"
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

#===============================================================================
# Write init script
#===============================================================================
echo "[INFO] Writing init script..."

cat > "$BUILDDIR/S99hidbox" << 'EOF'
#!/bin/sh
# HIDBOX init script for non-systemd systems

case "$1" in
    start)
        echo "Starting HIDBOX..."
        /usr/local/bin/hidboxd &
        ;;
    stop)
        echo "Stopping HIDBOX..."
        killall hidboxd
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    status)
        if pgrep -x "hidboxd" > /dev/null; then
            echo "HIDBOX is running"
            exit 0
        else
            echo "HIDBOX is stopped"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
exit 0
EOF

#===============================================================================
# Install init script
#===============================================================================
echo "[INFO] Installing init script to $INIT_DIR"
mkdir -p "$INIT_DIR"
cp "$BUILDDIR/S99hidbox" "$INIT_DIR/"
chmod 755 "$INIT_DIR/S99hidbox"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX init script installed successfully."
echo "     Script: $INIT_DIR/S99hidbox"
exit 0
EOF