#!/bin/sh
#===============================================================================
# HIDBOX Profile Management Library Installer for RG35XX H
# Builds and installs libhidbox-profile.a for profile loading/saving.
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
LIBNAME="hidbox-profile"
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

# profile.h
cat > "$BUILDDIR/profile.h" << 'EOF'
#ifndef HIDBOX_PROFILE_H
#define HIDBOX_PROFILE_H

#include <stdbool.h>
#include <stdint.h>

#define MAX_PROFILE_NAME 64
#define DEADZONE_DEFAULT 2000
#define KEY_MAX 512
#define ABS_MAX 64

typedef struct {
    char name[MAX_PROFILE_NAME];
    int deadzone;
    bool invert_lx, invert_ly, invert_rx, invert_ry;
    int16_t calib_lx_center, calib_ly_center, calib_rx_center, calib_ry_center;
    int button_map[KEY_MAX];
    int axis_map[ABS_MAX];
} ControllerProfile;

bool profile_load(ControllerProfile* profile, const char* path);
bool profile_save(const ControllerProfile* profile, const char* path);
void profile_set_default(ControllerProfile* profile);
void profile_apply_deadzone(ControllerProfile* profile, int deadzone);

#endif
EOF

# profile.c
cat > "$BUILDDIR/profile.c" << 'EOF'
#include "profile.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void profile_set_default(ControllerProfile* profile) {
    strcpy(profile->name, "Default");
    profile->deadzone = DEADZONE_DEFAULT;
    profile->invert_lx = false;
    profile->invert_ly = false;
    profile->invert_rx = false;
    profile->invert_ry = false;
    profile->calib_lx_center = 0;
    profile->calib_ly_center = 0;
    profile->calib_rx_center = 0;
    profile->calib_ry_center = 0;
    memset(profile->button_map, 0, sizeof(profile->button_map));
    memset(profile->axis_map, 0, sizeof(profile->axis_map));
}

bool profile_load(ControllerProfile* profile, const char* path) {
    FILE* f = fopen(path, "r");
    if (!f) {
        profile_set_default(profile);
        return false;
    }
    
    // Very simple JSON parsing (just reads name and deadzone)
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "\"name\"")) {
            char* start = strchr(line, ':') + 1;
            while (*start == ' ' || *start == '"') start++;
            char* end = strchr(start, '"');
            if (end) *end = '\0';
            strncpy(profile->name, start, MAX_PROFILE_NAME-1);
        } else if (strstr(line, "\"deadzone\"")) {
            char* start = strchr(line, ':') + 1;
            profile->deadzone = atoi(start);
        }
    }
    fclose(f);
    return true;
}

bool profile_save(const ControllerProfile* profile, const char* path) {
    FILE* f = fopen(path, "w");
    if (!f) return false;
    fprintf(f, "{\n");
    fprintf(f, "  \"name\": \"%s\",\n", profile->name);
    fprintf(f, "  \"deadzone\": %d,\n", profile->deadzone);
    fprintf(f, "  \"invert_lx\": %s,\n", profile->invert_lx ? "true" : "false");
    fprintf(f, "  \"invert_ly\": %s,\n", profile->invert_ly ? "true" : "false");
    fprintf(f, "  \"invert_rx\": %s,\n", profile->invert_rx ? "true" : "false");
    fprintf(f, "  \"invert_ry\": %s\n", profile->invert_ry ? "true" : "false");
    fprintf(f, "}\n");
    fclose(f);
    return true;
}

void profile_apply_deadzone(ControllerProfile* profile, int deadzone) {
    profile->deadzone = deadzone;
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c profile.c
ar rcs libhidbox-profile.a profile.o
ranlib libhidbox-profile.a

if [ ! -f "libhidbox-profile.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-profile.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-profile.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp profile.h "$INCDIR/"
chmod 644 "$INCDIR/profile.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX Profile library installed successfully."
echo "     Library: $LIBDIR/libhidbox-profile.a"
echo "     Header: $INCDIR/profile.h"
exit 0
EOF