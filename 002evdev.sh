#!/bin/sh
#===============================================================================
# HIDBOX UI Native Installer for RG35XX H
# Builds and installs hidbox-ui directly on the device.
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
APPNAME="hidbox-ui"
APPDIR="/mnt/SDCARD/App/${APPNAME}"
BUILDDIR="/tmp/${APPNAME}-build"
LAUNCHER="/mnt/SDCARD/Roms/Apps/${APPNAME}.sh"

#===============================================================================
# Check required tools and libraries
#===============================================================================
echo "[INFO] Checking required tools..."
for tool in gcc make pkg-config mkdir chmod rm cat; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERROR] $tool not found. Please install base development tools." >&2
        exit 1
    fi
done

echo "[INFO] Checking for SDL2..."
if ! pkg-config --exists sdl2; then
    echo "[ERROR] SDL2 development libraries not found." >&2
    echo "        On Rocknix: pacman -S sdl2" >&2
    echo "        On Knulli: opkg install libsdl2-dev" >&2
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

# ui.h
cat > "$BUILDDIR/ui.h" << 'EOF'
#ifndef UI_H
#define UI_H

#include <SDL2/SDL.h>
#include <stdbool.h>

typedef struct {
    SDL_Window* window;
    SDL_Renderer* renderer;
    SDL_Texture* controller_tex;
    SDL_Rect buttons[16];
    bool button_states[16];
    int axis_values[6];
    int socket_fd;
    bool running;
} UIState;

int init_ui(UIState* ui);
void cleanup_ui(UIState* ui);
void render_ui(UIState* ui);
void handle_events(UIState* ui);

#endif
EOF

# main.c
cat > "$BUILDDIR/main.c" << 'EOF'
#include "ui.h"
#include "../hidboxd/ipc.h"
#include <stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

#define HIDBOX_SOCKET_PATH "/tmp/hidbox.sock"

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    
    UIState ui;
    
    if (!init_ui(&ui)) {
        fprintf(stderr, "Failed to initialize UI\n");
        return 1;
    }
    
    ui.socket_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (ui.socket_fd >= 0) {
        struct sockaddr_un addr;
        addr.sun_family = AF_UNIX;
        strcpy(addr.sun_path, HIDBOX_SOCKET_PATH);
        connect(ui.socket_fd, (struct sockaddr*)&addr, sizeof(addr));
    }
    
    while (ui.running) {
        handle_events(&ui);
        render_ui(&ui);
        SDL_Delay(16);
    }
    
    cleanup_ui(&ui);
    return 0;
}
EOF

# renderer.c
cat > "$BUILDDIR/renderer.c" << 'EOF'
#include "ui.h"
#include <stdio.h>
#include <string.h>

int init_ui(UIState* ui) {
    memset(ui, 0, sizeof(UIState));
    
    if (SDL_Init(SDL_INIT_VIDEO) < 0) return 0;
    
    ui->window = SDL_CreateWindow("HIDBOX Controller",
                                  SDL_WINDOWPOS_UNDEFINED,
                                  SDL_WINDOWPOS_UNDEFINED,
                                  640, 480,
                                  SDL_WINDOW_SHOWN);
    if (!ui->window) {
        SDL_Quit();
        return 0;
    }
    
    ui->renderer = SDL_CreateRenderer(ui->window, -1, SDL_RENDERER_ACCELERATED);
    ui->running = true;
    return 1;
}

void cleanup_ui(UIState* ui) {
    if (ui->renderer) SDL_DestroyRenderer(ui->renderer);
    if (ui->window) SDL_DestroyWindow(ui->window);
    if (ui->socket_fd >= 0) close(ui->socket_fd);
    SDL_Quit();
}

void render_ui(UIState* ui) {
    SDL_SetRenderDrawColor(ui->renderer, 26, 26, 46, 255);
    SDL_RenderClear(ui->renderer);
    
    SDL_SetRenderDrawColor(ui->renderer, 255, 255, 255, 255);
    
    for (int i = 0; i < 16; i++) {
        SDL_Rect rect = {100 + (i % 4) * 60, 100 + (i / 4) * 60, 50, 50};
        if (ui->button_states[i]) {
            SDL_SetRenderDrawColor(ui->renderer, 0, 255, 0, 255);
        } else {
            SDL_SetRenderDrawColor(ui->renderer, 100, 100, 100, 255);
        }
        SDL_RenderFillRect(ui->renderer, &rect);
    }
    
    SDL_RenderPresent(ui->renderer);
}

void handle_events(UIState* ui) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_QUIT) {
            ui->running = false;
        }
    }
}
EOF

# input_display.c
cat > "$BUILDDIR/input_display.c" << 'EOF'
#include "ui.h"
#include <string.h>
#include <stdio.h>

void update_input_display(UIState* ui, const char* data) {
    if (strstr(data, "\"btns\":")) {
        char* btns = strstr(data, "[");
        if (btns) {
            unsigned int b0, b1;
            sscanf(btns, "[%u,%u]", &b0, &b1);
            for (int i = 0; i < 8; i++) {
                ui->button_states[i] = (b0 >> i) & 1;
                ui->button_states[i+8] = (b1 >> i) & 1;
            }
        }
    }
}
EOF

# menu.c
cat > "$BUILDDIR/menu.c" << 'EOF'
#include "ui.h"

void draw_menu(UIState* ui) {
    SDL_SetRenderDrawColor(ui->renderer, 50, 50, 50, 255);
    SDL_Rect menu_rect = {10, 10, 200, 460};
    SDL_RenderFillRect(ui->renderer, &menu_rect);
}
EOF

# ipc.c (from hidboxd, needed for IPC client)
cat > "$BUILDDIR/ipc.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>
#include <fcntl.h>

// Minimal IPC functions for UI (just to satisfy linking)
int create_ipc_socket(void* daemon) { (void)daemon; return -1; }
void close_ipc_socket(void* daemon) { (void)daemon; }
void handle_ipc_commands(void* daemon) { (void)daemon; }
void send_state_to_ui(void* daemon) { (void)daemon; }
bool load_profile(void* profile, const char* path) { (void)profile; (void)path; return false; }
void process_command(void* daemon, const char* cmd_json) { (void)daemon; (void)cmd_json; }
EOF

# profile.c (from hidboxd, needed for linking)
cat > "$BUILDDIR/profile.c" << 'EOF'
#include <stdbool.h>
#include <string.h>

#define DEADZONE_DEFAULT 2000

typedef struct {
    char name[64];
    int deadzone;
    bool invert_lx, invert_ly, invert_rx, invert_ry;
    int16_t calib_lx_center, calib_ly_center, calib_rx_center, calib_ry_center;
    int button_map[512];
    int axis_map[64];
} ControllerProfile;

bool load_profile(ControllerProfile* profile, const char* path) {
    (void)path;
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
    return true;
}
EOF

# cJSON.h (from hidboxd)
cat > "$BUILDDIR/cJSON.h" << 'EOF'
#ifndef CJSON_H
#define CJSON_H

typedef struct cJSON {
    struct cJSON *next;
    struct cJSON *prev;
    struct cJSON *child;
    int type;
    char *valuestring;
    double valuedouble;
    char *string;
} cJSON;

#define cJSON_Object 1
#define cJSON_Array 2
#define cJSON_String 3
#define cJSON_Number 4

cJSON* cJSON_Parse(const char *value);
void cJSON_Delete(cJSON *item);
cJSON* cJSON_GetObjectItem(const cJSON * const object, const char * const string);
int cJSON_IsTrue(const cJSON * const item);
double cJSON_GetNumberValue(const cJSON * const item);

#endif
EOF

# cJSON.c
cat > "$BUILDDIR/cJSON.c" << 'EOF'
#include "cJSON.h"
#include <stdlib.h>
#include <string.h>

cJSON* cJSON_Parse(const char *value) { (void)value; return NULL; }
void cJSON_Delete(cJSON *item) { (void)item; }
cJSON* cJSON_GetObjectItem(const cJSON * const object, const char * const string) { (void)object; (void)string; return NULL; }
int cJSON_IsTrue(const cJSON * const item) { (void)item; return 0; }
double cJSON_GetNumberValue(const cJSON * const item) { (void)item; return 0; }
EOF

#===============================================================================
# Compile
#===============================================================================
echo "[INFO] Compiling hidbox-ui..."
cd "$BUILDDIR"

# Get SDL2 flags
SDL_CFLAGS=$(pkg-config --cflags sdl2)
SDL_LIBS=$(pkg-config --libs sdl2)

gcc -O2 -march=armv8-a -mtune=cortex-a53 $SDL_CFLAGS -o hidbox-ui \
    main.c renderer.c input_display.c menu.c ipc.c profile.c cJSON.c \
    $SDL_LIBS -lpthread

if [ ! -f "$BUILDDIR/hidbox-ui" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install
#===============================================================================
echo "[INFO] Installing to $APPDIR"
mkdir -p "$APPDIR"
cp "$BUILDDIR/hidbox-ui" "$APPDIR/"
chmod 755 "$APPDIR/hidbox-ui"

#===============================================================================
# Create launcher
#===============================================================================
echo "[INFO] Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
cd "$APPDIR"
exec ./hidbox-ui
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
echo "[OK] HIDBOX UI installed successfully."
echo "     Binary: $APPDIR/hidbox-ui"
echo "     Launcher: $LAUNCHER"
echo "     You can now run it from the Apps section."
exit 0
EOF