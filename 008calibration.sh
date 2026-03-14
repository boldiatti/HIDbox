#!/bin/sh
#===============================================================================
# HIDBOX Profile Manager Native Installer for RG35XX H
# Builds and installs hidbox-profile (command-line profile utility).
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
APPNAME="hidbox-profile"
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

# profile_tool.c
cat > "$BUILDDIR/profile_tool.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#define PROFILES_DIR "/usr/local/share/hidbox/profiles"

void list_profiles(void) {
    DIR* dir = opendir(PROFILES_DIR);
    if (!dir) {
        perror("opendir");
        return;
    }
    struct dirent* entry;
    printf("Available profiles:\n");
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_REG) {
            char* dot = strrchr(entry->d_name, '.');
            if (dot && strcmp(dot, ".json") == 0) {
                *dot = '\0';
                printf("  %s\n", entry->d_name);
            }
        }
    }
    closedir(dir);
}

void show_profile(const char* name) {
    char path[256];
    snprintf(path, sizeof(path), "%s/%s.json", PROFILES_DIR, name);
    FILE* f = fopen(path, "r");
    if (!f) {
        fprintf(stderr, "Profile not found: %s\n", name);
        return;
    }
    char buf[1024];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), f)) > 0) {
        fwrite(buf, 1, n, stdout);
    }
    fclose(f);
}

int main(int argc, char** argv) {
    int opt;
    int option_index = 0;
    static struct option long_options[] = {
        {"list", no_argument, 0, 'l'},
        {"show", required_argument, 0, 's'},
        {"help", no_argument, 0, 'h'},
        {0,0,0,0}
    };
    
    if (argc == 1) {
        printf("Usage: %s [options]\n", argv[0]);
        printf("  -l, --list           List profiles\n");
        printf("  -s, --show <name>    Show profile JSON\n");
        printf("  -h, --help           This help\n");
        return 0;
    }
    
    while ((opt = getopt_long(argc, argv, "ls:h", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'l':
                list_profiles();
                break;
            case 's':
                show_profile(optarg);
                break;
            case 'h':
                printf("Usage: %s [options]\n", argv[0]);
                return 0;
            default:
                return 1;
        }
    }
    return 0;
}
EOF

#===============================================================================
# Compile
#===============================================================================
echo "[INFO] Compiling hidbox-profile..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -o hidbox-profile profile_tool.c

if [ ! -f "hidbox-profile" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install
#===============================================================================
echo "[INFO] Installing to $APPDIR"
mkdir -p "$APPDIR"
cp hidbox-profile "$APPDIR/"
chmod 755 "$APPDIR/hidbox-profile"

#===============================================================================
# Create launcher
#===============================================================================
echo "[INFO] Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
cd "$APPDIR"
./hidbox-profile "\$@"
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
echo "[OK] HIDBOX Profile Manager installed successfully."
echo "     Binary: $APPDIR/hidbox-profile"
echo "     Launcher: $LAUNCHER"
exit 0
EOF