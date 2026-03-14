#include "hidbox.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>

void print_usage(const char *prog) {
    printf("Usage: %s <command> [args]\n", prog);
    printf("Commands:\n");
    printf("  toggle_bt              Toggle Bluetooth output\n");
    printf("  toggle_usb             Toggle USB output\n");
    printf("  set_profile <name>     Switch profile (rg35xxh, xbox360, ps4, switch_pro, generic)\n");
    printf("  set_deadzone <value>   Set deadzone (0-10000)\n");
    printf("  get_info               Request state from daemon\n");
}

int main(int argc, char **argv) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    int fd = ipc_client_connect();
    if (fd < 0) {
        fprintf(stderr, "Cannot connect to hidboxd. Is it running?\n");
        return 1;
    }

    char cmd[256];
    if (strcmp(argv[1], "toggle_bt") == 0) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"toggle_bt\"}");
    } else if (strcmp(argv[1], "toggle_usb") == 0) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"toggle_usb\"}");
    } else if (strcmp(argv[1], "set_profile") == 0 && argc == 3) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"set_profile\",\"profile\":\"%s\"}", argv[2]);
    } else if (strcmp(argv[1], "set_deadzone") == 0 && argc == 3) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"set_deadzone\",\"deadzone\":%s}", argv[2]);
    } else if (strcmp(argv[1], "get_info") == 0) {
        snprintf(cmd, sizeof(cmd), "{\"command\":\"get_info\"}");
    } else {
        fprintf(stderr, "Unknown command.\n");
        close(fd);
        return 1;
    }

    ipc_client_send(fd, cmd);
    char buf[1024];
    int n = ipc_client_recv(fd, buf, sizeof(buf)-1);
    if (n > 0) {
        buf[n] = 0;
        printf("%s\n", buf);
    }
    close(fd);
    return 0;
}