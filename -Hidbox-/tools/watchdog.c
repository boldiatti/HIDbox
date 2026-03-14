#include "hidbox.h"
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>

#define WATCHDOG_INTERVAL 30
static volatile int running = 1;

void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

int check_process(const char *name) {
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "pgrep -x %s >/dev/null 2>&1", name);
    return (system(cmd) == 0);
}

void restart_process(const char *name, const char *path) {
    pid_t pid = fork();
    if (pid == 0) {
        execl(path, name, NULL);
        _exit(1);
    } else if (pid > 0) {
        waitpid(pid, NULL, 0);
    }
}

int main() {
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    while (running) {
        if (!check_process("hidboxd"))
            restart_process("hidboxd", "/mnt/SDCARD/App/hidbox/bin/hidboxd");
        if (!check_process("hidbox-ui"))
            restart_process("hidbox-ui", "/mnt/SDCARD/App/hidbox/bin/hidbox-ui");
        sleep(WATCHDOG_INTERVAL);
    }
    return 0;
}