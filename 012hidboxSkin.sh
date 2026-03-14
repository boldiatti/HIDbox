#!/bin/sh
#===============================================================================
# HIDBOX HID Report Generation Library Installer for RG35XX H
# Builds and installs libhidbox-hidreport.a for HID report building.
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
LIBNAME="hidbox-hidreport"
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

# hid_report.h
cat > "$BUILDDIR/hid_report.h" << 'EOF'
#ifndef HIDBOX_HID_REPORT_H
#define HIDBOX_HID_REPORT_H

#include <stdint.h>
#include <stddef.h>

#define HID_BTN_MAX 17
#define HID_AXIS_MAX 6
#define AXIS_MAX 32767
#define AXIS_MIN -32767

typedef enum {
    HID_BTN_A = 0,
    HID_BTN_B,
    HID_BTN_X,
    HID_BTN_Y,
    HID_BTN_L1,
    HID_BTN_R1,
    HID_BTN_L2,
    HID_BTN_R2,
    HID_BTN_SELECT,
    HID_BTN_START,
    HID_BTN_HOME,
    HID_BTN_THUMBL,
    HID_BTN_THUMBR,
    HID_BTN_DPAD_UP,
    HID_BTN_DPAD_DOWN,
    HID_BTN_DPAD_LEFT,
    HID_BTN_DPAD_RIGHT,
    HID_BTN_MAX
} HIDButton;

typedef enum {
    HID_AXIS_LX = 0,
    HID_AXIS_LY,
    HID_AXIS_RX,
    HID_AXIS_RY,
    HID_AXIS_LT,
    HID_AXIS_RT,
    HID_AXIS_MAX
} HIDAxis;

typedef struct {
    uint8_t buttons[(HID_BTN_MAX + 7) / 8];
    int16_t axes[HID_AXIS_MAX];
    uint64_t timestamp;
} HIDReport;

void hid_report_clear(HIDReport* report);
void hid_report_set_button(HIDReport* report, HIDButton btn, int pressed);
void hid_report_set_axis(HIDReport* report, HIDAxis axis, int16_t value);
void hid_report_build_usb(uint8_t* out, const HIDReport* report);

#endif
EOF

# hid_report.c
cat > "$BUILDDIR/hid_report.c" << 'EOF'
#include "hid_report.h"
#include <string.h>
#include <time.h>

void hid_report_clear(HIDReport* report) {
    memset(report, 0, sizeof(HIDReport));
}

void hid_report_set_button(HIDReport* report, HIDButton btn, int pressed) {
    int byte = btn / 8;
    int bit = btn % 8;
    if (pressed)
        report->buttons[byte] |= (1 << bit);
    else
        report->buttons[byte] &= ~(1 << bit);
}

void hid_report_set_axis(HIDReport* report, HIDAxis axis, int16_t value) {
    if (axis < HID_AXIS_MAX)
        report->axes[axis] = value;
}

void hid_report_build_usb(uint8_t* out, const HIDReport* report) {
    // USB report format: 2 bytes buttons, 4 axes (16-bit), 2 triggers (8-bit)
    out[0] = report->buttons[0];
    out[1] = report->buttons[1];
    // LX
    out[2] = report->axes[HID_AXIS_LX] & 0xFF;
    out[3] = (report->axes[HID_AXIS_LX] >> 8) & 0xFF;
    // LY
    out[4] = report->axes[HID_AXIS_LY] & 0xFF;
    out[5] = (report->axes[HID_AXIS_LY] >> 8) & 0xFF;
    // RX
    out[6] = report->axes[HID_AXIS_RX] & 0xFF;
    out[7] = (report->axes[HID_AXIS_RX] >> 8) & 0xFF;
    // RY
    out[8] = report->axes[HID_AXIS_RY] & 0xFF;
    out[9] = (report->axes[HID_AXIS_RY] >> 8) & 0xFF;
    // LT
    out[10] = (report->axes[HID_AXIS_LT] >> 8) & 0xFF;
    // RT
    out[11] = (report->axes[HID_AXIS_RT] >> 8) & 0xFF;
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c hid_report.c
ar rcs libhidbox-hidreport.a hid_report.o
ranlib libhidbox-hidreport.a

if [ ! -f "libhidbox-hidreport.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-hidreport.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-hidreport.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp hid_report.h "$INCDIR/"
chmod 644 "$INCDIR/hid_report.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX HID Report library installed successfully."
echo "     Library: $LIBDIR/libhidbox-hidreport.a"
echo "     Header: $INCDIR/hid_report.h"
exit 0
EOF