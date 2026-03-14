#include "hidbox.h"
#include <sys/socket.h>
#include <linux/netlink.h>
#include <unistd.h>
#include <string.h>

int udev_monitor_init(UdevMonitor *mon) {
    mon->fd = socket(AF_NETLINK, SOCK_RAW, NETLINK_KOBJECT_UEVENT);
    if (mon->fd < 0) return -1;
    struct sockaddr_nl addr;
    memset(&addr, 0, sizeof(addr));
    addr.nl_family = AF_NETLINK;
    addr.nl_pid = getpid();
    addr.nl_groups = 1;
    if (bind(mon->fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(mon->fd);
        mon->fd = -1;
        return -1;
    }
    return 0;
}

int udev_monitor_get_fd(const UdevMonitor *mon) {
    return mon->fd;
}

int udev_monitor_read_event(UdevMonitor *mon, char *buf, size_t len) {
    return recv(mon->fd, buf, len, 0);
}

void udev_monitor_cleanup(UdevMonitor *mon) {
    if (mon->fd >= 0) close(mon->fd);
    mon->fd = -1;
}