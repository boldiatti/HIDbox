#!/bin/sh
#===============================================================================
# HIDBOX Watchdog Native Installer for RG35XX H
# Builds and installs hidbox-watchdog (simple watchdog daemon).
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
APPNAME="hidbox-watchdog"
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

# watchdog.c
cat > "$BUILDDIR/watchdog.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <sys/timerfd.h>
#include <pthread.h>

#define WATCHDOG_TIMEOUT 30
#define PID_FILE "/var/run/hidbox-watchdog.pid"
#define LOG_FILE "/var/log/hidbox-watchdog.log"

static int g_timer_fd = -1;
static volatile sig_atomic_t g_running = 1;
static FILE* g_log = NULL;

void log_msg(const char* msg) {
    time_t now = time(NULL);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
    fprintf(g_log, "[%s] %s\n", time_str, msg);
    fflush(g_log);
}

void signal_handler(int sig) {
    (void)sig;
    g_running = 0;
}

int check_process(const char* name) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "pgrep -x %s >/dev/null 2>&1", name);
    return (system(cmd) == 0);
}

void restart_process(const char* name) {
    log_msg("Process not running, restarting...");
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "%s &", name);
    system(cmd);
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    
    // Daemonize
    pid_t pid = fork();
    if (pid < 0) exit(1);
    if (pid > 0) exit(0);
    setsid();
    pid = fork();
    if (pid < 0) exit(1);
    if (pid > 0) exit(0);
    chdir("/");
    close(0); close(1); close(2);
    
    // Open log
    g_log = fopen(LOG_FILE, "a");
    if (!g_log) g_log = stderr;
    
    // Write PID
    FILE* pf = fopen(PID_FILE, "w");
    if (pf) {
        fprintf(pf, "%d\n", getpid());
        fclose(pf);
    }
    
    log_msg("Watchdog started");
    
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    // Main loop
    while (g_running) {
        if (!check_process("hidboxd")) {
            restart_process("/usr/local/bin/hidboxd");
        }
        if (!check_process("hidbox-ui")) {
            restart_process("/usr/local/bin/hidbox-ui");
        }
        sleep(WATCHDOG_TIMEOUT);
    }
    
    log_msg("Watchdog stopped");
    if (g_log != stderr) fclose(g_log);
    unlink(PID_FILE);
    return 0;
}
EOF

#===============================================================================
# Compile
#===============================================================================
echo "[INFO] Compiling hidbox-watchdog..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -o hidbox-watchdog watchdog.c

if [ ! -f "hidbox-watchdog" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install
#===============================================================================
echo "[INFO] Installing to $APPDIR"
mkdir -p "$APPDIR"
cp hidbox-watchdog "$APPDIR/"
chmod 755 "$APPDIR/hidbox-watchdog"

#===============================================================================
# Create launcher
#===============================================================================
echo "[INFO] Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
cd "$APPDIR"
./hidbox-watchdog
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
echo "[OK] HIDBOX Watchdog installed successfully."
echo "     Binary: $APPDIR/hidbox-watchdog"
echo "     Launcher: $LAUNCHER"
echo "     It will auto-start hidboxd and hidbox-ui if they crash."
exit 0
EOF