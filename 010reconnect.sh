#!/bin/sh
#===============================================================================
# HIDBOX Bluetooth HID Test Tool Native Installer for RG35XX H
# Builds and installs hidbox-bt (simple Bluetooth HID test utility).
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
APPNAME="hidbox-bt"
APPDIR="/mnt/SDCARD/App/${APPNAME}"
BUILDDIR="/tmp/${APPNAME}-build"
LAUNCHER="/mnt/SDCARD/Roms/Apps/${APPNAME}.sh"

#===============================================================================
# Check required tools and libraries
#===============================================================================
echo "[INFO] Checking required tools..."
for tool in gcc mkdir cp rm; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERROR] $tool not found. Please install base development tools." >&2
        exit 1
    fi
done

# Check for Bluetooth headers
if [ ! -f "/usr/include/bluetooth/bluetooth.h" ]; then
    echo "[WARN] Bluetooth headers not found. Compilation may fail."
    echo "       On Rocknix: pacman -S bluez-libs"
    echo "       On Knulli: opkg install bluez-libs-dev"
fi

#===============================================================================
# Create temporary build directory
#===============================================================================
echo "[INFO] Creating build directory: $BUILDDIR"
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

#===============================================================================
# Write source files
#===============================================================================
echo "[INFO] Writing source files..."

# bt_test.c
cat > "$BUILDDIR/bt_test.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>
#include <bluetooth/l2cap.h>
#include <bluetooth/hidp.h>

int main(int argc, char** argv) {
    int dev_id = hci_get_route(NULL);
    if (dev_id < 0) {
        fprintf(stderr, "No Bluetooth adapter found.\n");
        return 1;
    }
    
    int ctl = socket(PF_BLUETOOTH, SOCK_SEQPACKET, BTPROTO_L2CAP);
    if (ctl < 0) {
        perror("socket");
        return 1;
    }
    
    struct sockaddr_l2 addr;
    memset(&addr, 0, sizeof(addr));
    addr.l2_family = AF_BLUETOOTH;
    addr.l2_psm = htobs(HIDP_PSM_CONTROL);
    
    if (bind(ctl, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(ctl);
        return 1;
    }
    
    printf("Bluetooth HID control socket created successfully.\n");
    printf("Adapter present. Use hidboxd for full functionality.\n");
    
    close(ctl);
    return 0;
}
EOF

#===============================================================================
# Compile
#===============================================================================
echo "[INFO] Compiling hidbox-bt..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -o hidbox-bt bt_test.c -lbluetooth

if [ ! -f "hidbox-bt" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install
#===============================================================================
echo "[INFO] Installing to $APPDIR"
mkdir -p "$APPDIR"
cp hidbox-bt "$APPDIR/"
chmod 755 "$APPDIR/hidbox-bt"

#===============================================================================
# Create launcher
#===============================================================================
echo "[INFO] Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
cd "$APPDIR"
./hidbox-bt "\$@"
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
echo "[OK] HIDBOX Bluetooth Test Tool installed successfully."
echo "     Binary: $APPDIR/hidbox-bt"
exit 0
EOF