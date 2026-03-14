#!/bin/sh
#===============================================================================
# HIDBOX Udev Monitor Library Installer for RG35XX H
# Builds and installs libhidbox-udev.a for device hotplug monitoring.
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
LIBNAME="hidbox-udev"
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

# udev_monitor.h
cat > "$BUILDDIR/udev_monitor.h" << 'EOF'
#ifndef HIDBOX_UDEV_MONITOR_H
#define HIDBOX_UDEV_MONITOR_H

#include <stdbool.h>

typedef struct {
    int fd;
} UdevMonitor;

int udev_monitor_init(UdevMonitor* mon);
int udev_monitor_get_fd(const UdevMonitor* mon);
int udev_monitor_read_event(UdevMonitor* mon, char* buf, size_t len);
void udev_monitor_cleanup(UdevMonitor* mon);

#endif
EOF

# udev_monitor.c
cat > "$BUILDDIR/udev_monitor.c" << 'EOF'
#include "udev_monitor.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <linux/netlink.h>

#define UEVENT_BUFFER_SIZE 2048

int udev_monitor_init(UdevMonitor* mon) {
    mon->fd = socket(AF_NETLINK, SOCK_RAW, NETLINK_KOBJECT_UEVENT);
    if (mon->fd < 0) return -1;
    
    struct sockaddr_nl addr;
    memset(&addr, 0, sizeof(addr));
    addr.nl_family = AF_NETLINK;
    addr.nl_pid = getpid();
    addr.nl_groups = 1;
    
    if (bind(mon->fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(mon->fd);
        mon->fd = -1;
        return -1;
    }
    return 0;
}

int udev_monitor_get_fd(const UdevMonitor* mon) {
    return mon->fd;
}

int udev_monitor_read_event(UdevMonitor* mon, char* buf, size_t len) {
    return recv(mon->fd, buf, len, 0);
}

void udev_monitor_cleanup(UdevMonitor* mon) {
    if (mon->fd >= 0) {
        close(mon->fd);
        mon->fd = -1;
    }
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c udev_monitor.c
ar rcs libhidbox-udev.a udev_monitor.o
ranlib libhidbox-udev.a

if [ ! -f "libhidbox-udev.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-udev.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-udev.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp udev_monitor.h "$INCDIR/"
chmod 644 "$INCDIR/udev_monitor.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX Udev Monitor library installed successfully."
echo "     Library: $LIBDIR/libhidbox-udev.a"
echo "     Header: $INCDIR/udev_monitor.h"
exit 0
EOF