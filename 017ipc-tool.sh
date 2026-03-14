#!/bin/sh
#===============================================================================
# HIDBOX Calibration Library Installer for RG35XX H
# Builds and installs libhidbox-calibration.a for analog stick calibration.
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
LIBNAME="hidbox-calibration"
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

# calibration.h
cat > "$BUILDDIR/calibration.h" << 'EOF'
#ifndef HIDBOX_CALIBRATION_H
#define HIDBOX_CALIBRATION_H

#include <stdint.h>
#include <stdbool.h>

#define MAX_AXES 8
#define CALIB_SAMPLES 100

typedef struct {
    int16_t min[MAX_AXES];
    int16_t max[MAX_AXES];
    int16_t center[MAX_AXES];
    bool calibrated[MAX_AXES];
    uint64_t timestamp;
} CalibrationData;

typedef struct {
    int16_t samples[MAX_AXES][CALIB_SAMPLES];
    int sample_count[MAX_AXES];
    bool collecting;
} CalibrationSession;

void calibration_start(CalibrationSession* session);
void calibration_add_sample(CalibrationSession* session, int axis, int16_t value);
bool calibration_complete(const CalibrationSession* session);
void calibration_compute(CalibrationSession* session, CalibrationData* out);
void calibration_reset(CalibrationData* data);
int16_t calibration_apply(const CalibrationData* data, int axis, int16_t value);

#endif
EOF

# calibration.c
cat > "$BUILDDIR/calibration.c" << 'EOF'
#include "calibration.h"
#include <string.h>

void calibration_start(CalibrationSession* session) {
    memset(session, 0, sizeof(CalibrationSession));
    session->collecting = true;
}

void calibration_add_sample(CalibrationSession* session, int axis, int16_t value) {
    if (!session->collecting) return;
    if (axis >= MAX_AXES) return;
    if (session->sample_count[axis] < CALIB_SAMPLES) {
        session->samples[axis][session->sample_count[axis]++] = value;
    }
}

bool calibration_complete(const CalibrationSession* session) {
    if (!session->collecting) return false;
    for (int i = 0; i < MAX_AXES; i++) {
        if (session->sample_count[i] < CALIB_SAMPLES) return false;
    }
    return true;
}

void calibration_compute(CalibrationSession* session, CalibrationData* out) {
    for (int axis = 0; axis < MAX_AXES; axis++) {
        int32_t sum = 0;
        int16_t min = 32767;
        int16_t max = -32768;
        
        for (int i = 0; i < session->sample_count[axis]; i++) {
            int16_t val = session->samples[axis][i];
            sum += val;
            if (val < min) min = val;
            if (val > max) max = val;
        }
        
        out->min[axis] = min;
        out->max[axis] = max;
        out->center[axis] = sum / session->sample_count[axis];
        out->calibrated[axis] = true;
    }
    out->timestamp = 0; // caller should set
    session->collecting = false;
}

void calibration_reset(CalibrationData* data) {
    memset(data, 0, sizeof(CalibrationData));
}

int16_t calibration_apply(const CalibrationData* data, int axis, int16_t value) {
    if (!data->calibrated[axis]) return value;
    return value - data->center[axis];
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c calibration.c
ar rcs libhidbox-calibration.a calibration.o
ranlib libhidbox-calibration.a

if [ ! -f "libhidbox-calibration.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-calibration.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-calibration.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp calibration.h "$INCDIR/"
chmod 644 "$INCDIR/calibration.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX Calibration library installed successfully."
echo "     Library: $LIBDIR/libhidbox-calibration.a"
echo "     Header: $INCDIR/calibration.h"
exit 0
EOF