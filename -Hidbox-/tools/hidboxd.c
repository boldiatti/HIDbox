#include "hidbox.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <fcntl.h>
#include <errno.h>

typedef struct {
    int evdev_fd;
    ControllerProfile profile;
    HIDReport report;
    IPCContext ipc;
    bool running;
    bool usb_enabled;
    bool bt_enabled;
} HIDBoxDaemon;

static HIDBoxDaemon daemon;

void signal_handler(int sig) {
    (void)sig;
    daemon.running = false;
}

void apply_profile_mapping(void) {
    // Simplified: map actual evdev codes to HID buttons/axes.
    // In a full implementation you'd use daemon.profile.button_map.
    // Here we just copy a few common ones.
    // This function would be more complex in reality.
    hid_report_clear(&daemon.report);

    // Map BTN_A -> HID_BTN_A
    if (daemon.profile.button_map[BTN_A])
        hid_report_set_button(&daemon.report, HID_BTN_A, 1);
    if (daemon.profile.button_map[BTN_B])
        hid_report_set_button(&daemon.report, HID_BTN_B, 1);
    if (daemon.profile.button_map[BTN_X])
        hid_report_set_button(&daemon.report, HID_BTN_X, 1);
    if (daemon.profile.button_map[BTN_Y])
        hid_report_set_button(&daemon.report, HID_BTN_Y, 1);

    // Axes
    int16_t lx = daemon.profile.axis_map[ABS_X];
    int16_t ly = daemon.profile.axis_map[ABS_Y];
    int16_t rx = daemon.profile.axis_map[ABS_RX];
    int16_t ry = daemon.profile.axis_map[ABS_RY];

    lx = apply_deadzone(lx, daemon.profile.deadzone);
    ly = apply_deadzone(ly, daemon.profile.deadzone);
    rx = apply_deadzone(rx, daemon.profile.deadzone);
    ry = apply_deadzone(ry, daemon.profile.deadzone);

    if (daemon.profile.invert_lx) lx = -lx;
    if (daemon.profile.invert_ly) ly = -ly;
    if (daemon.profile.invert_rx) rx = -rx;
    if (daemon.profile.invert_ry) ry = -ry;

    hid_report_set_axis(&daemon.report, HID_AXIS_LX, lx);
    hid_report_set_axis(&daemon.report, HID_AXIS_LY, ly);
    hid_report_set_axis(&daemon.report, HID_AXIS_RX, rx);
    hid_report_set_axis(&daemon.report, HID_AXIS_RY, ry);
}

void handle_ipc_commands(void) {
    if (daemon.ipc.client_fd < 0) return;
    char buf[256];
    int n = ipc_server_recv(&daemon.ipc, buf, sizeof(buf)-1);
    if (n > 0) {
        buf[n] = 0;
        if (strstr(buf, "toggle_bt")) {
            daemon.bt_enabled = !daemon.bt_enabled;
        } else if (strstr(buf, "toggle_usb")) {
            daemon.usb_enabled = !daemon.usb_enabled;
        }
        // Send acknowledgement
        ipc_server_send(&daemon.ipc, "OK", 2);
    }
}

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    // Open evdev
    daemon.evdev_fd = open_evdev();
    if (daemon.evdev_fd < 0) {
        fprintf(stderr, "Error: No gamepad evdev device found.\n");
        return 1;
    }
    int flags = fcntl(daemon.evdev_fd, F_GETFL, 0);
    fcntl(daemon.evdev_fd, F_SETFL, flags | O_NONBLOCK);

    // Load default profile
    profile_set_default(&daemon.profile);
    profile_load(&daemon.profile, "/mnt/SDCARD/App/hidbox/share/profiles/rg35xxh.json");

    // Initialize USB and Bluetooth
    daemon.usb_enabled = usb_gadget_init();
    daemon.bt_enabled = bt_hid_init();
    if (!daemon.bt_enabled)
        fprintf(stderr, "Warning: Bluetooth init failed, BT disabled.\n");

    // IPC server
    if (ipc_server_init(&daemon.ipc) < 0) {
        fprintf(stderr, "Error: IPC server init failed.\n");
        close_evdev(daemon.evdev_fd);
        return 1;
    }

    printf("HIDBOX Daemon started.\n");
    daemon.running = true;

    while (daemon.running) {
        // Read input
        int events = read_evdev(daemon.evdev_fd, daemon.profile.button_map, daemon.profile.axis_map);
        if (events > 0) {
            apply_profile_mapping();
            uint8_t report[12];
            hid_report_build_usb(report, &daemon.report);
            if (daemon.usb_enabled)
                usb_gadget_send_report(report, sizeof(report));
            if (daemon.bt_enabled)
                bt_hid_send_report(report, sizeof(report));
        }

        // Accept IPC connections
        if (daemon.ipc.client_fd < 0)
            ipc_server_accept(&daemon.ipc);
        handle_ipc_commands();

        usleep(16000); // ~60 Hz
    }

    printf("Shutting down...\n");
    close_evdev(daemon.evdev_fd);
    usb_gadget_cleanup();
    bt_hid_cleanup();
    ipc_server_cleanup(&daemon.ipc);
    return 0;
}