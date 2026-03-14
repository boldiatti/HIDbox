#!/bin/sh
#===============================================================================
# HIDBOX Bluetooth Reconnect Library Installer for RG35XX H
# Builds and installs libhidbox-reconnect.a for auto-reconnection logic.
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
LIBNAME="hidbox-reconnect"
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

# reconnect.h
cat > "$BUILDDIR/reconnect.h" << 'EOF'
#ifndef HIDBOX_RECONNECT_H
#define HIDBOX_RECONNECT_H

#include <stdbool.h>

#define BT_RECONNECT_ATTEMPTS 10
#define BT_RECONNECT_DELAY 2

typedef struct {
    int attempts;
    bool in_progress;
    bool enabled;
} ReconnectContext;

void reconnect_init(ReconnectContext* ctx);
bool reconnect_start(ReconnectContext* ctx);
void reconnect_stop(ReconnectContext* ctx);
bool reconnect_attempt(ReconnectContext* ctx, bool (*connect_func)(void));

#endif
EOF

# reconnect.c
cat > "$BUILDDIR/reconnect.c" << 'EOF'
#include "reconnect.h"
#include <unistd.h>

void reconnect_init(ReconnectContext* ctx) {
    ctx->attempts = 0;
    ctx->in_progress = false;
    ctx->enabled = true;
}

bool reconnect_start(ReconnectContext* ctx) {
    if (!ctx->enabled || ctx->in_progress) return false;
    ctx->in_progress = true;
    ctx->attempts = 0;
    return true;
}

void reconnect_stop(ReconnectContext* ctx) {
    ctx->in_progress = false;
    ctx->attempts = 0;
}

bool reconnect_attempt(ReconnectContext* ctx, bool (*connect_func)(void)) {
    if (!ctx->in_progress) return false;
    
    while (ctx->attempts < BT_RECONNECT_ATTEMPTS) {
        ctx->attempts++;
        if (connect_func()) {
            ctx->in_progress = false;
            return true;
        }
        sleep(BT_RECONNECT_DELAY);
    }
    
    ctx->in_progress = false;
    return false;
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c reconnect.c
ar rcs libhidbox-reconnect.a reconnect.o
ranlib libhidbox-reconnect.a

if [ ! -f "libhidbox-reconnect.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-reconnect.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-reconnect.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp reconnect.h "$INCDIR/"
chmod 644 "$INCDIR/reconnect.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX Bluetooth Reconnect library installed successfully."
echo "     Library: $LIBDIR/libhidbox-reconnect.a"
echo "     Header: $INCDIR/reconnect.h"
exit 0
EOF