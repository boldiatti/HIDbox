#include "hidbox.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

static int bt_control_fd = -1;
static bool bt_available = false;

bool bt_hid_init(void) {
    int dev_id = hci_get_route(NULL);
    if (dev_id < 0) {
        fprintf(stderr, "bt_hid: No Bluetooth adapter found\n");
        return false;
    }
    bt_control_fd = socket(PF_BLUETOOTH, SOCK_SEQPACKET, BTPROTO_L2CAP);
    if (bt_control_fd < 0) {
        perror("bt_hid: socket");
        return false;
    }
    struct sockaddr_l2 addr;
    memset(&addr, 0, sizeof(addr));
    addr.l2_family = AF_BLUETOOTH;
    addr.l2_psm = htobs(HIDP_PSM_CONTROL);
    if (bind(bt_control_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bt_hid: bind");
        close(bt_control_fd);
        bt_control_fd = -1;
        return false;
    }
    // Non‑blocking for safety
    int flags = fcntl(bt_control_fd, F_GETFL, 0);
    fcntl(bt_control_fd, F_SETFL, flags | O_NONBLOCK);
    bt_available = true;
    return true;
}

bool bt_hid_send_report(const uint8_t* report, size_t len) {
    if (!bt_available || bt_control_fd < 0) return false;
    ssize_t written = write(bt_control_fd, report, len);
    if (written < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
        bt_available = false;
        close(bt_control_fd);
        bt_control_fd = -1;
        return false;
    }
    return (written == (ssize_t)len);
}

void bt_hid_cleanup(void) {
    if (bt_control_fd >= 0) close(bt_control_fd);
    bt_control_fd = -1;
    bt_available = false;
}

bool bt_hid_is_connected(void) {
    return bt_available && bt_control_fd >= 0;
}