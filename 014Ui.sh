#!/bin/sh
#===============================================================================
# HIDBOX Bluetooth HID Library Installer for RG35XX H
# Builds and installs libhidbox-bthid.a for Bluetooth HID communication.
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
LIBNAME="hidbox-bthid"
LIBDIR="/mnt/SDCARD/hidbox/lib"
INCDIR="/mnt/SDCARD/hidbox/include"
BUILDDIR="/tmp/${LIBNAME}-build"

#===============================================================================
# Check required tools and libraries
#===============================================================================
echo "[INFO] Checking required tools..."
for tool in gcc ar ranlib mkdir cp rm; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERROR] $tool not found. Please install base development tools." >&2
        exit 1
    fi
done

# Check for Bluetooth headers
if [ ! -f "/usr/include/bluetooth/bluetooth.h" ] && [ ! -f "/usr/include/bluetooth/hci.h" ]; then
    echo "[WARN] Bluetooth headers not found. Install bluez-libs-dev."
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

# bt_hid.h
cat > "$BUILDDIR/bt_hid.h" << 'EOF'
#ifndef HIDBOX_BT_HID_H
#define HIDBOX_BT_HID_H

#include <stdbool.h>
#include <stdint.h>

bool bt_hid_init(void);
bool bt_hid_send_report(const uint8_t* report, size_t len);
void bt_hid_cleanup(void);
bool bt_hid_is_connected(void);

#endif
EOF

# bt_hid.c
cat > "$BUILDDIR/bt_hid.c" << 'EOF'
#include "bt_hid.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>
#include <bluetooth/l2cap.h>
#include <bluetooth/hidp.h>

static int bt_control_fd = -1;
static bool bt_available = false;

bool bt_hid_init(void) {
    int dev_id = hci_get_route(NULL);
    if (dev_id < 0) return false;
    
    bt_control_fd = socket(PF_BLUETOOTH, SOCK_SEQPACKET, BTPROTO_L2CAP);
    if (bt_control_fd < 0) return false;
    
    struct sockaddr_l2 addr;
    memset(&addr, 0, sizeof(addr));
    addr.l2_family = AF_BLUETOOTH;
    addr.l2_psm = htobs(HIDP_PSM_CONTROL);
    
    if (bind(bt_control_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(bt_control_fd);
        bt_control_fd = -1;
        return false;
    }
    
    bt_available = true;
    return true;
}

bool bt_hid_send_report(const uint8_t* report, size_t len) {
    if (!bt_available || bt_control_fd < 0) return false;
    ssize_t written = write(bt_control_fd, report, len);
    return (written == (ssize_t)len);
}

void bt_hid_cleanup(void) {
    if (bt_control_fd >= 0) {
        close(bt_control_fd);
        bt_control_fd = -1;
    }
    bt_available = false;
}

bool bt_hid_is_connected(void) {
    return bt_available && bt_control_fd >= 0;
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c bt_hid.c -lbluetooth
ar rcs libhidbox-bthid.a bt_hid.o
ranlib libhidbox-bthid.a

if [ ! -f "libhidbox-bthid.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-bthid.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-bthid.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp bt_hid.h "$INCDIR/"
chmod 644 "$INCDIR/bt_hid.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX Bluetooth HID library installed successfully."
echo "     Library: $LIBDIR/libhidbox-bthid.a"
echo "     Header: $INCDIR/bt_hid.h"
exit 0
EOF