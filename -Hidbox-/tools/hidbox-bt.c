#include "hidbox.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    if (bt_hid_init()) {
        printf("Bluetooth HID initialized successfully.\n");
        bt_hid_cleanup();
        return 0;
    } else {
        fprintf(stderr, "Bluetooth HID init failed. Check if Bluetooth adapter is present.\n");
        return 1;
    }
}