#!/bin/sh
#===============================================================================
# HIDBOX IPC Test Tool Native Installer for RG35XX H
# Builds and installs hidbox-ipc (command-line IPC client).
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
APPNAME="hidbox-ipc"
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

# ipc_client.c
cat > "$BUILDDIR/ipc_client.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>

#define HIDBOX_SOCKET_PATH "/tmp/hidbox.sock"

void print_usage(const char* prog) {
    printf("Usage: %s <command> [data]\n", prog);
    printf("Commands:\n");
    printf("  set_profile <name>   Switch profile (rg35xxh/xbox360/ps4/switch/generic)\n");
    printf("  set_deadzone <value> Set deadzone (0-10000)\n");
    printf("  toggle_bt            Toggle Bluetooth\n");
    printf("  toggle_usb           Toggle USB\n");
    printf("  get_info             Request state\n");
    printf("  raw <json>           Send raw JSON command\n");
}

int main(int argc, char** argv) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }
    
    char cmd[1024];
    if (strcmp(argv[1], "set_profile") == 0 && argc == 3) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"set_profile\",\"profile\":\"%s\"}", argv[2]);
    } else if (strcmp(argv[1], "set_deadzone") == 0 && argc == 3) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"set_deadzone\",\"deadzone\":%s}", argv[2]);
    } else if (strcmp(argv[1], "toggle_bt") == 0) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"toggle_bt\"}");
    } else if (strcmp(argv[1], "toggle_usb") == 0) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"toggle_usb\"}");
    } else if (strcmp(argv[1], "get_info") == 0) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"get_info\"}");
    } else if (strcmp(argv[1], "raw") == 0 && argc >= 3) {
        strncpy(cmd, argv[2], sizeof(cmd)-1);
    } else {
        print_usage(argv[0]);
        return 1;
    }
    
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, HIDBOX_SOCKET_PATH);
    
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("connect");
        close(sock);
        return 1;
    }
    
    write(sock, cmd, strlen(cmd));
    
    char buf[4096];
    int n = read(sock, buf, sizeof(buf)-1);
    if (n > 0) {
        buf[n] = '\0';
        printf("%s\n", buf);
    }
    
    close(sock);
    return 0;
}
EOF

#===============================================================================
# Compile
#===============================================================================
echo "[INFO] Compiling hidbox-ipc..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -o hidbox-ipc ipc_client.c

if [ ! -f "hidbox-ipc" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install
#===============================================================================
echo "[INFO] Installing to $APPDIR"
mkdir -p "$APPDIR"
cp hidbox-ipc "$APPDIR/"
chmod 755 "$APPDIR/hidbox-ipc"

#===============================================================================
# Create launcher
#===============================================================================
echo "[INFO] Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
cd "$APPDIR"
./hidbox-ipc "\$@"
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
echo "[OK] HIDBOX IPC Tool installed successfully."
echo "     Binary: $APPDIR/hidbox-ipc"
echo "     Launcher: $LAUNCHER"
echo "     Use: hidbox-ipc --help"
exit 0
EOF