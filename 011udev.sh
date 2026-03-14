#!/bin/sh
#===============================================================================
# HIDBOX Evdev Input Handling Library Installer for RG35XX H
# Builds and installs libhidbox-evdev.a for evdev input processing.
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
LIBNAME="hidbox-evdev"
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

# evdev.h
cat > "$BUILDDIR/evdev.h" << 'EOF'
#ifndef HIDBOX_EVDEV_H
#define HIDBOX_EVDEV_H

#include <stdint.h>
#include <stdbool.h>
#include <linux/input.h>

int open_evdev(void);
void close_evdev(int fd);
int read_evdev(int fd, int* button_map, int* axis_map);

#endif
EOF

# evdev.c
cat > "$BUILDDIR/evdev.c" << 'EOF'
#include "evdev.h"
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>
#include <sys/ioctl.h>

#define MAX_DEVICES 16
#define INPUT_DIR "/dev/input"

int open_evdev(void) {
    DIR* dir = opendir(INPUT_DIR);
    if (!dir) return -1;
    
    struct dirent* entry;
    int devices[MAX_DEVICES];
    int device_count = 0;
    int selected_fd = -1;
    
    while ((entry = readdir(dir)) != NULL && device_count < MAX_DEVICES) {
        if (strncmp(entry->d_name, "event", 5) != 0) continue;
        
        char path[256];
        snprintf(path, sizeof(path), "%s/%s", INPUT_DIR, entry->d_name);
        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;
        
        char name[256];
        if (ioctl(fd, EVIOCGNAME(sizeof(name)), name) < 0) {
            close(fd);
            continue;
        }
        
        if (strstr(name, "gamepad") || strstr(name, "GPIO") || 
            strstr(name, "Controller") || strstr(name, "JOY") ||
            strstr(name, "retrogame") || strstr(name, "adc")) {
            devices[device_count++] = fd;
        } else {
            close(fd);
        }
    }
    closedir(dir);
    
    if (device_count > 0) {
        selected_fd = devices[0];
        for (int i = 1; i < device_count; i++) close(devices[i]);
    }
    return selected_fd;
}

void close_evdev(int fd) {
    if (fd >= 0) close(fd);
}

int read_evdev(int fd, int* button_map, int* axis_map) {
    struct input_event ev;
    int events = 0;
    while (1) {
        int rd = read(fd, &ev, sizeof(ev));
        if (rd < (int)sizeof(ev)) {
            if (errno == EAGAIN) break;
            return -1;
        }
        events++;
        if (ev.type == EV_KEY && ev.code < KEY_MAX)
            button_map[ev.code] = ev.value;
        else if (ev.type == EV_ABS && ev.code < ABS_MAX)
            axis_map[ev.code] = ev.value;
    }
    return events;
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c evdev.c
ar rcs libhidbox-evdev.a evdev.o
ranlib libhidbox-evdev.a

if [ ! -f "libhidbox-evdev.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-evdev.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-evdev.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp evdev.h "$INCDIR/"
chmod 644 "$INCDIR/evdev.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX Evdev library installed successfully."
echo "     Library: $LIBDIR/libhidbox-evdev.a"
echo "     Header: $INCDIR/evdev.h"
exit 0
EOF