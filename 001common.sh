#!/bin/sh
#===============================================================================
# HIDBOX Daemon Native Installer for RG35XX H
# Builds and installs hidboxd directly on the device.
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
APPNAME="hidboxd"
APPDIR="/mnt/SDCARD/App/${APPNAME}"
BUILDDIR="/tmp/${APPNAME}-build"
LAUNCHER="/mnt/SDCARD/Roms/Apps/${APPNAME}.sh"

#===============================================================================
# Check required tools
#===============================================================================
echo "[INFO] Checking required tools..."
for tool in gcc make mkdir chmod rm cat; do
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

# hidboxd.h
cat > "$BUILDDIR/hidboxd.h" << 'EOF'
#ifndef HIDBOXD_H
#define HIDBOXD_H

#include <stdint.h>
#include <stdbool.h>
#include <linux/input.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <time.h>

#define HIDBOX_SOCKET_PATH "/tmp/hidbox.sock"
#define MAX_PROFILE_NAME 64
#define MAX_BUTTONS 32
#define MAX_AXES 8
#define DEADZONE_DEFAULT 2000
#define AXIS_MAX 32767
#define AXIS_MIN -32767

typedef enum {
    HID_BTN_A = 0,
    HID_BTN_B,
    HID_BTN_X,
    HID_BTN_Y,
    HID_BTN_L1,
    HID_BTN_R1,
    HID_BTN_L2,
    HID_BTN_R2,
    HID_BTN_SELECT,
    HID_BTN_START,
    HID_BTN_HOME,
    HID_BTN_THUMBL,
    HID_BTN_THUMBR,
    HID_BTN_DPAD_UP,
    HID_BTN_DPAD_DOWN,
    HID_BTN_DPAD_LEFT,
    HID_BTN_DPAD_RIGHT,
    HID_BTN_MAX
} HIDButton;

typedef enum {
    HID_AXIS_LX = 0,
    HID_AXIS_LY,
    HID_AXIS_RX,
    HID_AXIS_RY,
    HID_AXIS_LT,
    HID_AXIS_RT,
    HID_AXIS_MAX
} HIDAxis;

typedef struct {
    uint8_t buttons[(HID_BTN_MAX + 7) / 8];
    int16_t axes[HID_AXIS_MAX];
    uint64_t timestamp;
} HIDReport;

typedef struct {
    char name[MAX_PROFILE_NAME];
    uint8_t hid_descriptor[256];
    size_t desc_len;
    int button_map[KEY_MAX];
    int axis_map[ABS_MAX];
    int deadzone;
    bool invert_lx;
    bool invert_ly;
    bool invert_rx;
    bool invert_ry;
    int16_t calib_lx_center;
    int16_t calib_ly_center;
    int16_t calib_rx_center;
    int16_t calib_ry_center;
} ControllerProfile;

typedef struct {
    int evdev_fd;
    ControllerProfile profile;
    HIDReport current_report;
    int socket_fd;
    int client_fd;
    bool bt_enabled;
    bool usb_enabled;
    bool running;
    uint32_t bg_color;
    int display_timeout;
    int display_timer;
} HIDBoxDaemon;

int open_evdev(void);
void close_evdev(int fd);
int read_evdev(HIDBoxDaemon* daemon);
void apply_profile_mapping(HIDBoxDaemon* daemon);
void build_hid_report(HIDBoxDaemon* daemon);
bool init_usb_gadget(void);
bool send_usb_report(HIDReport* report);
void cleanup_usb_gadget(void);
bool init_bt_hid(void);
bool send_bt_report(HIDReport* report);
void cleanup_bt_hid(void);
int create_ipc_socket(HIDBoxDaemon* daemon);
void close_ipc_socket(HIDBoxDaemon* daemon);
void handle_ipc_commands(HIDBoxDaemon* daemon);
void send_state_to_ui(HIDBoxDaemon* daemon);
bool load_profile(ControllerProfile* profile, const char* path);
void process_command(HIDBoxDaemon* daemon, const char* cmd_json);

#endif
EOF

# main.c
cat > "$BUILDDIR/main.c" << 'EOF'
#include "hidboxd.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>

static HIDBoxDaemon g_daemon;
static volatile sig_atomic_t g_running = 1;

void signal_handler(int sig) {
    (void)sig;
    g_running = 0;
}

void init_daemon(HIDBoxDaemon* daemon) {
    memset(daemon, 0, sizeof(HIDBoxDaemon));
    daemon->evdev_fd = -1;
    daemon->socket_fd = -1;
    daemon->client_fd = -1;
    daemon->bt_enabled = true;
    daemon->usb_enabled = true;
    daemon->running = true;
    daemon->bg_color = 0x1a1a2eFF;
    daemon->display_timeout = 60;
    daemon->display_timer = 0;
    
    // Load default profile
    load_profile(&daemon->profile, "/usr/local/share/hidbox/profiles/rg35xxh.json");
    
    memset(&daemon->current_report, 0, sizeof(HIDReport));
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    
    printf("HIDBOX Daemon v1.0 starting...\n");
    
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    init_daemon(&g_daemon);
    
    g_daemon.evdev_fd = open_evdev();
    if (g_daemon.evdev_fd < 0) {
        fprintf(stderr, "Error: Failed to open evdev device\n");
        return 1;
    }
    
    int flags = fcntl(g_daemon.evdev_fd, F_GETFL, 0);
    fcntl(g_daemon.evdev_fd, F_SETFL, flags | O_NONBLOCK);
    
    if (!init_usb_gadget()) {
        printf("USB gadget not available - USB output disabled\n");
        g_daemon.usb_enabled = false;
    }
    
    if (!init_bt_hid()) {
        printf("Bluetooth HID not available - BT output disabled\n");
        g_daemon.bt_enabled = false;
    }
    
    if (create_ipc_socket(&g_daemon) < 0) {
        fprintf(stderr, "Error: Failed to create IPC socket\n");
        close_evdev(g_daemon.evdev_fd);
        return 1;
    }
    
    printf("HIDBOX Daemon running. PID: %d\n", getpid());
    printf("  USB HID: %s\n", g_daemon.usb_enabled ? "Enabled" : "Disabled");
    printf("  Bluetooth HID: %s\n", g_daemon.bt_enabled ? "Enabled" : "Disabled");
    
    while (g_running) {
        struct timespec ts = {0, 16000000}; // 16ms = ~60Hz
        
        int input_events = read_evdev(&g_daemon);
        
        if (input_events > 0) {
            apply_profile_mapping(&g_daemon);
            build_hid_report(&g_daemon);
            
            if (g_daemon.usb_enabled) {
                send_usb_report(&g_daemon.current_report);
            }
            if (g_daemon.bt_enabled) {
                send_bt_report(&g_daemon.current_report);
            }
            g_daemon.display_timer = 0;
        } else {
            if (g_daemon.display_timer < g_daemon.display_timeout * 60) {
                g_daemon.display_timer++;
            }
        }
        
        handle_ipc_commands(&g_daemon);
        
        static int ui_counter = 0;
        if (ui_counter++ % 6 == 0) {
            send_state_to_ui(&g_daemon);
        }
        
        nanosleep(&ts, NULL);
    }
    
    printf("\nShutting down HIDBOX Daemon...\n");
    close_ipc_socket(&g_daemon);
    close_evdev(g_daemon.evdev_fd);
    cleanup_usb_gadget();
    cleanup_bt_hid();
    
    printf("HIDBOX Daemon stopped.\n");
    return 0;
}
EOF

# evdev.c
cat > "$BUILDDIR/evdev.c" << 'EOF'
#include "hidboxd.h"
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>
#include <sys/ioctl.h>

#define MAX_DEVICES 16
#define INPUT_DIR "/dev/input"

int open_evdev(void) {
    DIR* dir;
    struct dirent* entry;
    int devices[MAX_DEVICES];
    int device_count = 0;
    int selected_fd = -1;
    
    dir = opendir(INPUT_DIR);
    if (!dir) return -1;
    
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
            printf("Found controller: %s (%s)\n", path, name);
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

int read_evdev(HIDBoxDaemon* daemon) {
    struct input_event ev;
    int events = 0;
    int rd;
    
    while (1) {
        rd = read(daemon->evdev_fd, &ev, sizeof(ev));
        if (rd < (int)sizeof(ev)) {
            if (errno == EAGAIN) break;
            return -1;
        }
        events++;
        if (ev.type == EV_KEY && ev.code < KEY_MAX) {
            daemon->profile.button_map[ev.code] = ev.value;
        } else if (ev.type == EV_ABS && ev.code < ABS_MAX) {
            daemon->profile.axis_map[ev.code] = ev.value;
        }
    }
    return events;
}

void apply_profile_mapping(HIDBoxDaemon* daemon) {
    memset(&daemon->current_report, 0, sizeof(HIDReport));
    
    if (daemon->profile.button_map[BTN_A] > 0)
        daemon->current_report.buttons[0] |= (1 << HID_BTN_A);
    if (daemon->profile.button_map[BTN_B] > 0)
        daemon->current_report.buttons[0] |= (1 << HID_BTN_B);
    if (daemon->profile.button_map[BTN_X] > 0)
        daemon->current_report.buttons[0] |= (1 << HID_BTN_X);
    if (daemon->profile.button_map[BTN_Y] > 0)
        daemon->current_report.buttons[0] |= (1 << HID_BTN_Y);
    if (daemon->profile.button_map[BTN_TL] > 0)
        daemon->current_report.buttons[0] |= (1 << HID_BTN_L1);
    if (daemon->profile.button_map[BTN_TR] > 0)
        daemon->current_report.buttons[0] |= (1 << HID_BTN_R1);
    if (daemon->profile.button_map[BTN_TL2] > 0)
        daemon->current_report.buttons[0] |= (1 << HID_BTN_L2);
    if (daemon->profile.button_map[BTN_TR2] > 0)
        daemon->current_report.buttons[0] |= (1 << HID_BTN_R2);
    if (daemon->profile.button_map[BTN_SELECT] > 0)
        daemon->current_report.buttons[1] |= (1 << (HID_BTN_SELECT - 8));
    if (daemon->profile.button_map[BTN_START] > 0)
        daemon->current_report.buttons[1] |= (1 << (HID_BTN_START - 8));
    if (daemon->profile.button_map[BTN_THUMBL] > 0)
        daemon->current_report.buttons[1] |= (1 << (HID_BTN_THUMBL - 8));
    if (daemon->profile.button_map[BTN_THUMBR] > 0)
        daemon->current_report.buttons[1] |= (1 << (HID_BTN_THUMBR - 8));
    
    if (daemon->profile.axis_map[ABS_HAT0X] < 0)
        daemon->current_report.buttons[1] |= (1 << (HID_BTN_DPAD_LEFT - 8));
    else if (daemon->profile.axis_map[ABS_HAT0X] > 0)
        daemon->current_report.buttons[1] |= (1 << (HID_BTN_DPAD_RIGHT - 8));
    
    if (daemon->profile.axis_map[ABS_HAT0Y] < 0)
        daemon->current_report.buttons[1] |= (1 << (HID_BTN_DPAD_UP - 8));
    else if (daemon->profile.axis_map[ABS_HAT0Y] > 0)
        daemon->current_report.buttons[1] |= (1 << (HID_BTN_DPAD_DOWN - 8));
    
    int lx = daemon->profile.axis_map[ABS_X];
    int ly = daemon->profile.axis_map[ABS_Y];
    int rx = daemon->profile.axis_map[ABS_RX];
    int ry = daemon->profile.axis_map[ABS_RY];
    int lt = daemon->profile.axis_map[ABS_Z];
    int rt = daemon->profile.axis_map[ABS_RZ];
    
    if (abs(lx) < daemon->profile.deadzone) lx = 0;
    if (abs(ly) < daemon->profile.deadzone) ly = 0;
    if (abs(rx) < daemon->profile.deadzone) rx = 0;
    if (abs(ry) < daemon->profile.deadzone) ry = 0;
    
    lx -= daemon->profile.calib_lx_center;
    ly -= daemon->profile.calib_ly_center;
    rx -= daemon->profile.calib_rx_center;
    ry -= daemon->profile.calib_ry_center;
    
    if (daemon->profile.invert_lx) lx = -lx;
    if (daemon->profile.invert_ly) ly = -ly;
    if (daemon->profile.invert_rx) rx = -rx;
    if (daemon->profile.invert_ry) ry = -ry;
    
    daemon->current_report.axes[HID_AXIS_LX] = lx;
    daemon->current_report.axes[HID_AXIS_LY] = ly;
    daemon->current_report.axes[HID_AXIS_RX] = rx;
    daemon->current_report.axes[HID_AXIS_RY] = ry;
    daemon->current_report.axes[HID_AXIS_LT] = lt;
    daemon->current_report.axes[HID_AXIS_RT] = rt;
    
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    daemon->current_report.timestamp = ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}
EOF

# hid_report.c
cat > "$BUILDDIR/hid_report.c" << 'EOF'
#include "hidboxd.h"
#include <string.h>

static const uint8_t hid_descriptor_generic[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x05,        // Usage (Game Pad)
    0xA1, 0x01,        // Collection (Application)
    0x05, 0x09,        // Usage Page (Button)
    0x19, 0x01,        // Usage Minimum (1)
    0x29, 0x08,        // Usage Maximum (8)
    0x15, 0x00,        // Logical Minimum (0)
    0x25, 0x01,        // Logical Maximum (1)
    0x75, 0x01,        // Report Size (1)
    0x95, 0x08,        // Report Count (8)
    0x81, 0x02,        // Input (Data,Var,Abs)
    0x05, 0x09,        // Usage Page (Button)
    0x19, 0x09,        // Usage Minimum (9)
    0x29, 0x10,        // Usage Maximum (16)
    0x15, 0x00,        // Logical Minimum (0)
    0x25, 0x01,        // Logical Maximum (1)
    0x75, 0x01,        // Report Size (1)
    0x95, 0x08,        // Report Count (8)
    0x81, 0x02,        // Input (Data,Var,Abs)
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x30,        // Usage (X)
    0x09, 0x31,        // Usage (Y)
    0x09, 0x32,        // Usage (Z)
    0x09, 0x35,        // Usage (Rz)
    0x16, 0x00, 0x80,  // Logical Minimum (-32768)
    0x26, 0xFF, 0x7F,  // Logical Maximum (32767)
    0x75, 0x10,        // Report Size (16)
    0x95, 0x04,        // Report Count (4)
    0x81, 0x02,        // Input (Data,Var,Abs)
    0x09, 0x33,        // Usage (Rx) - Left trigger
    0x09, 0x34,        // Usage (Ry) - Right trigger
    0x15, 0x00,        // Logical Minimum (0)
    0x26, 0xFF, 0x00,  // Logical Maximum (255)
    0x75, 0x08,        // Report Size (8)
    0x95, 0x02,        // Report Count (2)
    0x81, 0x02,        // Input (Data,Var,Abs)
    0xC0                // End Collection
};

void build_hid_report(HIDBoxDaemon* daemon) {
    (void)daemon;
}
EOF

# usb_gadget.c
cat > "$BUILDDIR/usb_gadget.c" << 'EOF'
#include "hidboxd.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

static int usb_hid_fd = -1;
static bool usb_available = false;

bool init_usb_gadget(void) {
    const char* hid_paths[] = {"/dev/hidg0", "/dev/hidg1", NULL};
    for (int i = 0; hid_paths[i] != NULL; i++) {
        usb_hid_fd = open(hid_paths[i], O_RDWR | O_NONBLOCK);
        if (usb_hid_fd >= 0) {
            printf("USB HID gadget opened: %s\n", hid_paths[i]);
            usb_available = true;
            return true;
        }
    }
    usb_available = false;
    return false;
}

bool send_usb_report(HIDReport* report) {
    if (!usb_available || usb_hid_fd < 0) return false;
    
    uint8_t usb_report[8 + 8];
    usb_report[0] = report->buttons[0];
    usb_report[1] = report->buttons[1];
    usb_report[2] = report->axes[HID_AXIS_LX] & 0xFF;
    usb_report[3] = (report->axes[HID_AXIS_LX] >> 8) & 0xFF;
    usb_report[4] = report->axes[HID_AXIS_LY] & 0xFF;
    usb_report[5] = (report->axes[HID_AXIS_LY] >> 8) & 0xFF;
    usb_report[6] = report->axes[HID_AXIS_RX] & 0xFF;
    usb_report[7] = (report->axes[HID_AXIS_RX] >> 8) & 0xFF;
    usb_report[8] = report->axes[HID_AXIS_RY] & 0xFF;
    usb_report[9] = (report->axes[HID_AXIS_RY] >> 8) & 0xFF;
    usb_report[10] = (report->axes[HID_AXIS_LT] >> 8) & 0xFF;
    usb_report[11] = (report->axes[HID_AXIS_RT] >> 8) & 0xFF;
    
    ssize_t written = write(usb_hid_fd, usb_report, 12);
    return (written == 12);
}

void cleanup_usb_gadget(void) {
    if (usb_hid_fd >= 0) close(usb_hid_fd);
    usb_hid_fd = -1;
}
EOF

# bt_hid.c
cat > "$BUILDDIR/bt_hid.c" << 'EOF'
#include "hidboxd.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>
#include <bluetooth/l2cap.h>
#include <bluetooth/hidp.h>

static int bt_control_fd = -1;
static bool bt_available = false;

bool init_bt_hid(void) {
    int dev_id = hci_get_route(NULL);
    if (dev_id < 0) return false;
    
    bt_control_fd = socket(PF_BLUETOOTH, SOCK_SEQPACKET, BTPROTO_L2CAP);
    if (bt_control_fd < 0) return false;
    
    struct sockaddr_l2 addr;
    memset(&addr, 0, sizeof(addr));
    addr.l2_family = AF_BLUETOOTH;
    addr.l2_psm = htobs(HIDP_PSM_CONTROL);
    
    if (bind(bt_control_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(bt_control_fd);
        bt_control_fd = -1;
        return false;
    }
    
    bt_available = true;
    return true;
}

bool send_bt_report(HIDReport* report) {
    if (!bt_available || bt_control_fd < 0) return false;
    
    uint8_t bt_report[12];
    bt_report[0] = report->buttons[0];
    bt_report[1] = report->buttons[1];
    bt_report[2] = report->axes[HID_AXIS_LX] & 0xFF;
    bt_report[3] = (report->axes[HID_AXIS_LX] >> 8) & 0xFF;
    bt_report[4] = report->axes[HID_AXIS_LY] & 0xFF;
    bt_report[5] = (report->axes[HID_AXIS_LY] >> 8) & 0xFF;
    bt_report[6] = report->axes[HID_AXIS_RX] & 0xFF;
    bt_report[7] = (report->axes[HID_AXIS_RX] >> 8) & 0xFF;
    bt_report[8] = report->axes[HID_AXIS_RY] & 0xFF;
    bt_report[9] = (report->axes[HID_AXIS_RY] >> 8) & 0xFF;
    bt_report[10] = (report->axes[HID_AXIS_LT] >> 8) & 0xFF;
    bt_report[11] = (report->axes[HID_AXIS_RT] >> 8) & 0xFF;
    
    ssize_t written = write(bt_control_fd, bt_report, 12);
    return (written == 12);
}

void cleanup_bt_hid(void) {
    if (bt_control_fd >= 0) close(bt_control_fd);
    bt_control_fd = -1;
}
EOF

# ipc.c
cat > "$BUILDDIR/ipc.c" << 'EOF'
#include "hidboxd.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>
#include <fcntl.h>

int create_ipc_socket(HIDBoxDaemon* daemon) {
    unlink(HIDBOX_SOCKET_PATH);
    
    daemon->socket_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (daemon->socket_fd < 0) return -1;
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, HIDBOX_SOCKET_PATH, sizeof(addr.sun_path) - 1);
    
    if (bind(daemon->socket_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(daemon->socket_fd);
        return -1;
    }
    
    if (listen(daemon->socket_fd, 1) < 0) {
        close(daemon->socket_fd);
        return -1;
    }
    
    int flags = fcntl(daemon->socket_fd, F_GETFL, 0);
    fcntl(daemon->socket_fd, F_SETFL, flags | O_NONBLOCK);
    
    return 0;
}

void close_ipc_socket(HIDBoxDaemon* daemon) {
    if (daemon->client_fd >= 0) close(daemon->client_fd);
    if (daemon->socket_fd >= 0) close(daemon->socket_fd);
    unlink(HIDBOX_SOCKET_PATH);
}

void handle_ipc_commands(HIDBoxDaemon* daemon) {
    if (daemon->client_fd < 0) {
        struct sockaddr_un client_addr;
        socklen_t client_len = sizeof(client_addr);
        daemon->client_fd = accept(daemon->socket_fd, 
                                   (struct sockaddr*)&client_addr, 
                                   &client_len);
        if (daemon->client_fd >= 0) {
            int flags = fcntl(daemon->client_fd, F_GETFL, 0);
            fcntl(daemon->client_fd, F_SETFL, flags | O_NONBLOCK);
        }
    }
    
    if (daemon->client_fd >= 0) {
        char buffer[1024];
        int bytes = recv(daemon->client_fd, buffer, sizeof(buffer) - 1, 0);
        if (bytes > 0) {
            buffer[bytes] = '\0';
            process_command(daemon, buffer);
        } else if (bytes == 0) {
            close(daemon->client_fd);
            daemon->client_fd = -1;
        } else if (bytes < 0 && errno != EAGAIN) {
            close(daemon->client_fd);
            daemon->client_fd = -1;
        }
    }
}

void send_state_to_ui(HIDBoxDaemon* daemon) {
    if (daemon->client_fd < 0) return;
    
    char buffer[512];
    int len = snprintf(buffer, sizeof(buffer),
        "{\"state\":{"
        "\"btns\":[%u,%u],"
        "\"axes\":[%d,%d,%d,%d,%d,%d],"
        "\"timestamp\":%llu"
        "}}",
        daemon->current_report.buttons[0],
        daemon->current_report.buttons[1],
        daemon->current_report.axes[HID_AXIS_LX],
        daemon->current_report.axes[HID_AXIS_LY],
        daemon->current_report.axes[HID_AXIS_RX],
        daemon->current_report.axes[HID_AXIS_RY],
        daemon->current_report.axes[HID_AXIS_LT],
        daemon->current_report.axes[HID_AXIS_RT],
        (unsigned long long)daemon->current_report.timestamp
    );
    
    send(daemon->client_fd, buffer, len, 0);
}

void process_command(HIDBoxDaemon* daemon, const char* cmd_json) {
    if (strstr(cmd_json, "set_profile")) {
        if (strstr(cmd_json, "rg35xxh")) {
            load_profile(&daemon->profile, "/usr/local/share/hidbox/profiles/rg35xxh.json");
        } else if (strstr(cmd_json, "xbox360")) {
            load_profile(&daemon->profile, "/usr/local/share/hidbox/profiles/xbox360.json");
        } else if (strstr(cmd_json, "ps4")) {
            load_profile(&daemon->profile, "/usr/local/share/hidbox/profiles/ps4.json");
        } else if (strstr(cmd_json, "switch")) {
            load_profile(&daemon->profile, "/usr/local/share/hidbox/profiles/switch_pro.json");
        } else if (strstr(cmd_json, "generic")) {
            load_profile(&daemon->profile, "/usr/local/share/hidbox/profiles/generic.json");
        }
    } else if (strstr(cmd_json, "set_deadzone")) {
        char* dz_str = strstr(cmd_json, "deadzone");
        if (dz_str) {
            int dz = atoi(dz_str + 9);
            if (dz > 0 && dz < 10000) daemon->profile.deadzone = dz;
        }
    } else if (strstr(cmd_json, "toggle_bt")) {
        daemon->bt_enabled = !daemon->bt_enabled;
    } else if (strstr(cmd_json, "toggle_usb")) {
        daemon->usb_enabled = !daemon->usb_enabled;
    }
}
EOF

# profile.c
cat > "$BUILDDIR/profile.c" << 'EOF'
#include "hidboxd.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

bool load_profile(ControllerProfile* profile, const char* path) {
    FILE* file = fopen(path, "r");
    if (!file) return false;
    
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
    
    memset(profile->button_map, 0, sizeof(profile->button_map));
    memset(profile->axis_map, 0, sizeof(profile->axis_map));
    
    fclose(file);
    return true;
}
EOF

# cJSON.h
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

cJSON* cJSON_Parse(const char *value) {
    (void)value;
    return NULL;
}

void cJSON_Delete(cJSON *item) {
    (void)item;
}

cJSON* cJSON_GetObjectItem(const cJSON * const object, const char * const string) {
    (void)object;
    (void)string;
    return NULL;
}

int cJSON_IsTrue(const cJSON * const item) {
    (void)item;
    return 0;
}

double cJSON_GetNumberValue(const cJSON * const item) {
    (void)item;
    return 0;
}
EOF

#===============================================================================
# Compile
#===============================================================================
echo "[INFO] Compiling hidboxd..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -o hidboxd \
    main.c evdev.c hid_report.c usb_gadget.c bt_hid.c ipc.c profile.c cJSON.c \
    -lpthread -lrt -lm -lbluetooth

if [ ! -f "$BUILDDIR/hidboxd" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install
#===============================================================================
echo "[INFO] Installing to $APPDIR"
mkdir -p "$APPDIR"
cp "$BUILDDIR/hidboxd" "$APPDIR/"
chmod 755 "$APPDIR/hidboxd"

#===============================================================================
# Create launcher
#===============================================================================
echo "[INFO] Creating launcher: $LAUNCHER"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
cd "$APPDIR"
exec ./hidboxd
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
echo "[OK] HIDBOX Daemon installed successfully."
echo "     Binary: $APPDIR/hidboxd"
echo "     Launcher: $LAUNCHER"
echo "     You can now run it from the Apps section or via the launcher."
exit 0
EOF