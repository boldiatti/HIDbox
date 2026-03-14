#!/bin/sh
#===============================================================================
# HIDBOX USB Gadget Library Installer for RG35XX H
# Builds and installs libhidbox-usbgadget.a for USB HID communication.
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
LIBNAME="hidbox-usbgadget"
LIBDIR="/mnt/SDCARD/hidbox/lib"
INCDIR="/mnt/SDCARD/hidbox/include"
BUILDDIR="/tmp/${LIBNAME}-build"

#===============================================================================
# Check required tools
#===============================================================================
echo "[INFO] Checking required tools..."
for tool in gcc ar ranlib mkdir cp rm; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERROR] $tool not found. Please install base development tools." >&2
        exit 1
    fi
done

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

# usb_gadget.h
cat > "$BUILDDIR/usb_gadget.h" << 'EOF'
#ifndef HIDBOX_USB_GADGET_H
#define HIDBOX_USB_GADGET_H

#include <stdbool.h>
#include <stdint.h>

bool usb_gadget_init(void);
bool usb_gadget_send_report(const uint8_t* report, size_t len);
void usb_gadget_cleanup(void);
bool usb_gadget_is_connected(void);

#endif
EOF

# usb_gadget.c
cat > "$BUILDDIR/usb_gadget.c" << 'EOF'
#include "usb_gadget.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

static int usb_hid_fd = -1;
static bool usb_available = false;

bool usb_gadget_init(void) {
    const char* paths[] = {"/dev/hidg0", "/dev/hidg1", NULL};
    for (int i = 0; paths[i]; i++) {
        usb_hid_fd = open(paths[i], O_RDWR | O_NONBLOCK);
        if (usb_hid_fd >= 0) {
            usb_available = true;
            return true;
        }
    }
    usb_available = false;
    return false;
}

bool usb_gadget_send_report(const uint8_t* report, size_t len) {
    if (!usb_available || usb_hid_fd < 0) return false;
    ssize_t written = write(usb_hid_fd, report, len);
    return (written == (ssize_t)len);
}

void usb_gadget_cleanup(void) {
    if (usb_hid_fd >= 0) {
        close(usb_hid_fd);
        usb_hid_fd = -1;
    }
    usb_available = false;
}

bool usb_gadget_is_connected(void) {
    return usb_available && usb_hid_fd >= 0;
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c usb_gadget.c
ar rcs libhidbox-usbgadget.a usb_gadget.o
ranlib libhidbox-usbgadget.a

if [ ! -f "libhidbox-usbgadget.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-usbgadget.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-usbgadget.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp usb_gadget.h "$INCDIR/"
chmod 644 "$INCDIR/usb_gadget.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX USB Gadget library installed successfully."
echo "     Library: $LIBDIR/libhidbox-usbgadget.a"
echo "     Header: $INCDIR/usb_gadget.h"
exit 0
EOF