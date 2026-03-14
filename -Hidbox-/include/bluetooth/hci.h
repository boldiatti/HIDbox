#ifndef __HCI_H
#define __HCI_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/* HCI device identifiers */
#define HCI_DEV_NONE  0xffff

/* HCI socket options */
#define HCI_DATA_DIR  1
#define HCI_FILTER    2
#define HCI_TIME_STAMP 3

/* HCI filter flags */
#define HCI_FLAG_TYPE     0x01
#define HCI_FLAG_EVENT    0x02
#define HCI_FLAG_RAW      0x04

/* HCI packet types */
#define HCI_COMMAND_PKT   0x01
#define HCI_ACLDATA_PKT   0x02
#define HCI_SCODATA_PKT   0x03
#define HCI_EVENT_PKT     0x04
#define HCI_VENDOR_PKT    0xff

/* HCI max event size */
#define HCI_MAX_EVENT_SIZE 260

/* HCI device info */
struct hci_dev_info {
    uint16_t dev_id;
    char     name[8];
    bdaddr_t bdaddr;
    uint32_t flags;
    uint8_t  type;
    uint8_t  features[8];
    uint32_t pkt_type;
    uint32_t link_policy;
    uint32_t link_mode;
    uint16_t acl_mtu;
    uint16_t sco_mtu;
    uint16_t acl_pkts;
    uint16_t sco_pkts;
    struct   sockaddr_hci {
        sa_family_t hci_family;
        uint16_t    hci_dev;
        uint16_t    hci_channel;
    } stat;
};

/* HCI device flags */
#define HCIDEV_UP      0x0001
#define HCIDEV_RUNNING 0x0002
#define HCIDEV_RAW     0x0004

/* HCI filter */
struct hci_filter {
    uint32_t type_mask;
    uint32_t event_mask[2];
    uint16_t opcode;
};

#ifdef __cplusplus
}
#endif

#endif /* __HCI_H */