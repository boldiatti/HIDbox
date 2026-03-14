#include "hidbox.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

static int usb_fd = -1;

bool usb_gadget_init(void) {
    const char *paths[] = {"/dev/hidg0", "/dev/hidg1", NULL};
    for (int i = 0; paths[i]; i++) {
        usb_fd = open(paths[i], O_RDWR | O_NONBLOCK);
        if (usb_fd >= 0) {
            return true;
        }
    }
    return false;
}

bool usb_gadget_send_report(const uint8_t *report, size_t len) {
    if (usb_fd < 0) return false;
    ssize_t w = write(usb_fd, report, len);
    if (w < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
        close(usb_fd);
        usb_fd = -1;
        return false;
    }
    return (w == (ssize_t)len);
}

void usb_gadget_cleanup(void) {
    if (usb_fd >= 0) close(usb_fd);
    usb_fd = -1;
}

bool usb_gadget_is_connected(void) {
    return usb_fd >= 0;
}