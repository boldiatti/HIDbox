#ifndef __HCI_LIB_H
#define __HCI_LIB_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/* Get route to Bluetooth device */
int hci_get_route(bdaddr_t *bdaddr);

/* Open HCI socket */
int hci_open_dev(int dev_id);

/* Close HCI socket */
int hci_close_dev(int dd);

/* Send HCI command */
int hci_send_cmd(int dd, uint16_t ogf, uint16_t ocf, uint8_t plen, void *param);

/* Read local version information */
int hci_read_local_version(int dd, struct hci_version *ver, int to);

/* Read local Bluetooth address */
int hci_read_bd_addr(int dd, bdaddr_t *bdaddr, int to);

/* Device information */
int hci_devinfo(int dev_id, struct hci_dev_info *di);

/* Inquiry scan */
int hci_inquiry(int dev_id, int len, int max_rsp, uint8_t *lap, inquiry_info **ii, long flags);

/* Remote name request */
int hci_read_remote_name(int dd, bdaddr_t *bdaddr, int len, char *name, int to);

/* Simple wrappers for hci_get_route */
static inline int hci_get_route(bdaddr_t *bdaddr) {
    (void)bdaddr;
    return 0; /* Assume device 0 exists */
}

#ifdef __cplusplus
}
#endif

#endif /* __HCI_LIB_H */