#!/bin/sh
#===============================================================================
# HIDBOX HID Descriptors Library Installer for RG35XX H
# Builds and installs libhidbox-descriptors.a for HID descriptor handling.
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
LIBNAME="hidbox-descriptors"
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

# hid_descriptors.h
cat > "$BUILDDIR/hid_descriptors.h" << 'EOF'
#ifndef HIDBOX_HID_DESCRIPTORS_H
#define HIDBOX_HID_DESCRIPTORS_H

#include <stdint.h>
#include <stddef.h>

typedef enum {
    CONTROLLER_TYPE_GENERIC = 0,
    CONTROLLER_TYPE_XBOX360,
    CONTROLLER_TYPE_PS4,
    CONTROLLER_TYPE_SWITCH_PRO,
    CONTROLLER_TYPE_RG35XXH,
    CONTROLLER_TYPE_MAX
} ControllerType;

const uint8_t* hid_descriptor_get(ControllerType type, size_t* len);

#endif
EOF

# hid_descriptors.c
cat > "$BUILDDIR/hid_descriptors.c" << 'EOF'
#include "hid_descriptors.h"

// Generic gamepad HID descriptor (16 buttons, 4 axes, 2 triggers)
static const uint8_t hid_desc_generic[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x05,        // Usage (Game Pad)
    0xA1, 0x01,        // Collection (Application)
    // Buttons 1-16
    0x05, 0x09,        // Usage Page (Button)
    0x19, 0x01,        // Usage Minimum (1)
    0x29, 0x10,        // Usage Maximum (16)
    0x15, 0x00,        // Logical Minimum (0)
    0x25, 0x01,        // Logical Maximum (1)
    0x75, 0x01,        // Report Size (1)
    0x95, 0x10,        // Report Count (16)
    0x81, 0x02,        // Input (Data,Var,Abs)
    // X, Y, Z, Rz axes (16-bit)
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x30,        // Usage (X)
    0x09, 0x31,        // Usage (Y)
    0x09, 0x32,        // Usage (Z)
    0x09, 0x35,        // Usage (Rz)
    0x16, 0x00, 0x80,  // Logical Minimum (-32768)
    0x26, 0xFF, 0x7F,  // Logical Maximum (32767)
    0x75, 0x10,        // Report Size (16)
    0x95, 0x04,        // Report Count (4)
    0x81, 0x02,        // Input (Data,Var,Abs)
    // Triggers (8-bit)
    0x09, 0x33,        // Usage (Rx) - Left trigger
    0x09, 0x34,        // Usage (Ry) - Right trigger
    0x15, 0x00,        // Logical Minimum (0)
    0x26, 0xFF, 0x00,  // Logical Maximum (255)
    0x75, 0x08,        // Report Size (8)
    0x95, 0x02,        // Report Count (2)
    0x81, 0x02,        // Input (Data,Var,Abs)
    0xC0                // End Collection
};

// Xbox 360 HID descriptor (simplified)
static const uint8_t hid_desc_xbox360[] = {
    0x05, 0x01, 0x09, 0x05, 0xA1, 0x01,
    0x05, 0x09, 0x19, 0x01, 0x29, 0x0E, 0x15, 0x00, 0x25, 0x01,
    0x75, 0x01, 0x95, 0x0E, 0x81, 0x02,
    0x75, 0x01, 0x95, 0x02, 0x81, 0x03,
    0x05, 0x01, 0x09, 0x39, 0x15, 0x00, 0x25, 0x07, 0x35, 0x00,
    0x46, 0x3B, 0x01, 0x65, 0x14, 0x75, 0x04, 0x95, 0x01, 0x81, 0x42,
    0x75, 0x04, 0x95, 0x01, 0x81, 0x03,
    0x05, 0x02, 0x09, 0xC5, 0x09, 0xC4, 0x15, 0x00, 0x26, 0xFF, 0x00,
    0x75, 0x08, 0x95, 0x02, 0x81, 0x02,
    0x05, 0x01, 0x09, 0x30, 0x09, 0x31, 0x09, 0x32, 0x09, 0x35,
    0x16, 0x00, 0x80, 0x26, 0xFF, 0x7F, 0x75, 0x10, 0x95, 0x04, 0x81, 0x02,
    0xC0
};

const uint8_t* hid_descriptor_get(ControllerType type, size_t* len) {
    switch (type) {
        case CONTROLLER_TYPE_XBOX360:
            *len = sizeof(hid_desc_xbox360);
            return hid_desc_xbox360;
        case CONTROLLER_TYPE_PS4:
        case CONTROLLER_TYPE_SWITCH_PRO:
        case CONTROLLER_TYPE_RG35XXH:
        case CONTROLLER_TYPE_GENERIC:
        default:
            *len = sizeof(hid_desc_generic);
            return hid_desc_generic;
    }
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c hid_descriptors.c
ar rcs libhidbox-descriptors.a hid_descriptors.o
ranlib libhidbox-descriptors.a

if [ ! -f "libhidbox-descriptors.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-descriptors.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-descriptors.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp hid_descriptors.h "$INCDIR/"
chmod 644 "$INCDIR/hid_descriptors.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX HID Descriptors library installed successfully."
echo "     Library: $LIBDIR/libhidbox-descriptors.a"
echo "     Header: $INCDIR/hid_descriptors.h"
exit 0
EOF