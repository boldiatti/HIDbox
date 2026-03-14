#include "hidbox.h"
#include <stdio.h>

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    if (usb_gadget_init()) {
        printf("USB gadget opened successfully.\n");
        uint8_t report[12] = {0};
        if (usb_gadget_send_report(report, sizeof(report)))
            printf("Test report sent.\n");
        else
            fprintf(stderr, "Failed to send report.\n");
        usb_gadget_cleanup();
        return 0;
    } else {
        fprintf(stderr, "USB gadget init failed. Is /dev/hidg0 present?\n");
        return 1;
    }
}