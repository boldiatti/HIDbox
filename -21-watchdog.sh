#!/bin/sh
#===============================================================================
# HIDBOX Skin Manager Library Installer for RG35XX H
# Builds and installs libhidbox-skin.a for UI skin management.
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
LIBNAME="hidbox-skin"
LIBDIR="/mnt/SDCARD/hidbox/lib"
INCDIR="/mnt/SDCARD/hidbox/include"
BUILDDIR="/tmp/${LIBNAME}-build"

#===============================================================================
# Check required tools and libraries
#===============================================================================
echo "[INFO] Checking required tools..."
for tool in gcc ar ranlib pkg-config mkdir cp rm; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERROR] $tool not found. Please install base development tools." >&2
        exit 1
    fi
done

if ! pkg-config --exists sdl2; then
    echo "[ERROR] SDL2 development libraries not found." >&2
    exit 1
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

# skin_manager.h
cat > "$BUILDDIR/skin_manager.h" << 'EOF'
#ifndef HIDBOX_SKIN_MANAGER_H
#define HIDBOX_SKIN_MANAGER_H

#include <SDL2/SDL.h>
#include <stdbool.h>

typedef struct {
    char name[64];
    SDL_Texture* bg;
    SDL_Texture* buttons[16];
    SDL_Texture* axes[6];
} Skin;

bool skin_load(Skin* skin, SDL_Renderer* renderer, const char* base_path, const char* skin_name);
void skin_free(Skin* skin);
SDL_Texture* skin_get_button(const Skin* skin, int idx, bool pressed);
SDL_Texture* skin_get_background(const Skin* skin);

#endif
EOF

# skin_manager.c
cat > "$BUILDDIR/skin_manager.c" << 'EOF'
#include "skin_manager.h"
#include <SDL2/SDL_image.h>
#include <string.h>
#include <stdio.h>

bool skin_load(Skin* skin, SDL_Renderer* renderer, const char* base_path, const char* skin_name) {
    memset(skin, 0, sizeof(Skin));
    strncpy(skin->name, skin_name, 63);
    
    char path[256];
    snprintf(path, sizeof(path), "%s/%s/bg.png", base_path, skin_name);
    SDL_Surface* surf = IMG_Load(path);
    if (surf) {
        skin->bg = SDL_CreateTextureFromSurface(renderer, surf);
        SDL_FreeSurface(surf);
    }
    
    const char* btn_files[] = {"a", "b", "x", "y", "l1", "r1", "l2", "r2",
                                "select", "start", "home", "l3", "r3",
                                "dpad_up", "dpad_down", "dpad_left", "dpad_right"};
    for (int i = 0; i < 16; i++) {
        snprintf(path, sizeof(path), "%s/%s/btn_%s.png", base_path, skin_name, btn_files[i]);
        surf = IMG_Load(path);
        if (surf) {
            skin->buttons[i] = SDL_CreateTextureFromSurface(renderer, surf);
            SDL_FreeSurface(surf);
        }
    }
    return true;
}

void skin_free(Skin* skin) {
    if (skin->bg) SDL_DestroyTexture(skin->bg);
    for (int i = 0; i < 16; i++) {
        if (skin->buttons[i]) SDL_DestroyTexture(skin->buttons[i]);
    }
    memset(skin, 0, sizeof(Skin));
}

SDL_Texture* skin_get_button(const Skin* skin, int idx, bool pressed) {
    (void)pressed; // could use separate pressed texture
    if (idx >= 0 && idx < 16) return skin->buttons[idx];
    return NULL;
}

SDL_Texture* skin_get_background(const Skin* skin) {
    return skin->bg;
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
SDL_CFLAGS=$(pkg-config --cflags sdl2)
SDL_LIBS=$(pkg-config --libs sdl2)
gcc -O2 -march=armv8-a -mtune=cortex-a53 $SDL_CFLAGS -c skin_manager.c
ar rcs libhidbox-skin.a skin_manager.o
ranlib libhidbox-skin.a

if [ ! -f "libhidbox-skin.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-skin.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-skin.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp skin_manager.h "$INCDIR/"
chmod 644 "$INCDIR/skin_manager.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX Skin Manager library installed successfully."
echo "     Library: $LIBDIR/libhidbox-skin.a"
echo "     Header: $INCDIR/skin_manager.h"
exit 0
EOF