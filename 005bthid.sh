#!/bin/sh
#===============================================================================
# HIDBOX Config Parser Tool Native Installer for RG35XX H
# Builds and installs hidbox-config (command-line config utility).
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
APPNAME="hidbox-config"
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

# config_tool.c
cat > "$BUILDDIR/config_tool.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <errno.h>

#define HIDBOX_SOCKET_PATH "/tmp/hidbox.sock"
#define CONFIG_PATH "/etc/hidbox/config.json"

void print_usage(const char* prog) {
    printf("Usage: %s [options]\n", prog);
    printf("Options:\n");
    printf("  -g, --get <key>          Get configuration value\n");
    printf("  -s, --set <key=value>    Set configuration value\n");
    printf("  -l, --list                List all configuration\n");
    printf("  -h, --help                 Show this help\n");
}

int send_command(const char* cmd) {
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return -1;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, HIDBOX_SOCKET_PATH);
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return -1;
    }
    write(sock, cmd, strlen(cmd));
    char buf[1024];
    int n = read(sock, buf, sizeof(buf)-1);
    if (n > 0) {
        buf[n] = '\0';
        printf("%s\n", buf);
    }
    close(sock);
    return 0;
}

int main(int argc, char** argv) {
    int opt;
    int option_index = 0;
    static struct option long_options[] = {
        {"get", required_argument, 0, 'g'},
        {"set", required_argument, 0, 's'},
        {"list", no_argument, 0, 'l'},
        {"help", no_argument, 0, 'h'},
        {0,0,0,0}
    };
    
    if (argc == 1) {
        print_usage(argv[0]);
        return 0;
    }
    
    while ((opt = getopt_long(argc, argv, "g:s:lh", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'g':
                printf("Get config key: %s\n", optarg);
                // TODO: implement
                break;
            case 's':
                printf("Set config: %s\n", optarg);
                // TODO: implement
                break;
            case 'l':
                printf("Listing config:\n");
                // TODO: read file
                break;
            case 'h':
                print_usage(argv[0]);
                return 0;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }
    return 0;
}
EOF

#===============================================================================
# Compile
#===============================================================================
echo "[INFO] Compiling hidbox-config..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -o hidbox-config config_tool.c

if [ ! -f "hidbox-config" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install
#===============================================================================
echo "[INFO] Installing to $APPDIR"
mkdir -p "$APPDIR"
cp hidbox-config "$APPDIR/"
chmod 755 "$APPDIR/hidbox-config"

#===============================================================================
# Create launcher
#===============================================================================
echo "[INFO] Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
cd "$APPDIR"
./hidbox-config "\$@"
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
echo "[OK] HIDBOX Config Parser installed successfully."
echo "     Binary: $APPDIR/hidbox-config"
echo "     Launcher: $LAUNCHER"
echo "     Use: hidbox-config --help"
exit 0
EOF