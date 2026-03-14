#!/bin/sh
#===============================================================================
# HIDBOX USB Gadget Test Tool Native Installer for RG35XX H
# Builds and installs hidbox-usb (simple USB HID test utility).
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
APPNAME="hidbox-usb"
APPDIR="/mnt/SDCARD/App/${APPNAME}"
BUILDDIR="/tmp/${APPNAME}-build"
LAUNCHER="/mnt/SDCARD/Roms/Apps/${APPNAME}.sh"

#===============================================================================
# Check required tools
#===============================================================================
echo "[INFO] Checking required tools..."
for tool in gcc mkdir cp rm; do
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

# usb_test.c
cat > "$BUILDDIR/usb_test.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#define HIDG_PATH "/dev/hidg0"

int main(int argc, char** argv) {
    int fd = open(HIDG_PATH, O_RDWR);
    if (fd < 0) {
        perror("open");
        fprintf(stderr, "USB gadget not available. Make sure kernel module is loaded.\n");
        return 1;
    }
    
    if (argc > 1 && strcmp(argv[1], "test") == 0) {
        // Send a test report (all buttons off, axes centered)
        unsigned char report[8] = {0};
        write(fd, report, sizeof(report));
        printf("Test report sent.\n");
    } else {
        printf("Usage: %s test\n", argv[0]);
        printf("  Sends a zero HID report to test USB gadget.\n");
    }
    
    close(fd);
    return 0;
}
EOF

#===============================================================================
# Compile
#===============================================================================
echo "[INFO] Compiling hidbox-usb..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -o hidbox-usb usb_test.c

if [ ! -f "hidbox-usb" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install
#===============================================================================
echo "[INFO] Installing to $APPDIR"
mkdir -p "$APPDIR"
cp hidbox-usb "$APPDIR/"
chmod 755 "$APPDIR/hidbox-usb"

#===============================================================================
# Create launcher
#===============================================================================
echo "[INFO] Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
cd "$APPDIR"
./hidbox-usb "\$@"
EOF
chmod 755 "$LAUNCHER"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX USB Test Tool installed successfully."
echo "     Binary: $APPDIR/hidbox-usb"
exit 0
EOF