#include "hidbox.h"
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>
#include <sys/ioctl.h>

#define INPUT_DIR "/dev/input"

int open_evdev(void) {
    DIR *dir = opendir(INPUT_DIR);
    if (!dir) return -1;

    struct dirent *entry;
    int found_fd = -1;

    while ((entry = readdir(dir)) != NULL) {
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

        // Detect common gamepad names
        if (strstr(name, "gamepad") || strstr(name, "GPIO") ||
            strstr(name, "Controller") || strstr(name, "JOY") ||
            strstr(name, "retrogame") || strstr(name, "adc")) {
            found_fd = fd;
            break;
        } else {
            close(fd);
        }
    }
    closedir(dir);
    return found_fd;
}

void close_evdev(int fd) {
    if (fd >= 0) close(fd);
}

int read_evdev(int fd, int *button_map, int *axis_map) {
    struct input_event ev;
    int events = 0;
    while (1) {
        int n = read(fd, &ev, sizeof(ev));
        if (n < (int)sizeof(ev)) {
            if (errno == EAGAIN) break;
            return -1;
        }
        events++;
        if (ev.type == EV_KEY && ev.code < KEY_MAX)
            button_map[ev.code] = ev.value;
        else if (ev.type == EV_ABS && ev.code < ABS_MAX)
            axis_map[ev.code] = ev.value;
    }
    return events;
}