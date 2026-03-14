#ifndef __HIDP_H
#define __HIDP_H

#ifdef __cplusplus
extern "C" {
#endif

/* HIDP protocol service multiplexer (PSM) values */
#define HIDP_PSM_CONTROL  0x11
#define HIDP_PSM_INTERRUPT 0x13

/* HIDP header sizes */
#define HIDP_HEADER_SIZE   6

/* HIDP transaction types */
#define HIDP_TRANS_HANDSHAKE 0x00
#define HIDP_TRANS_HID_CONTROL 0x10
#define HIDP_TRANS_GET_REPORT 0x40
#define HIDP_TRANS_SET_REPORT 0x50
#define HIDP_TRANS_GET_PROTOCOL 0x60
#define HIDP_TRANS_SET_PROTOCOL 0x70
#define HIDP_TRANS_GET_IDLE   0x80
#define HIDP_TRANS_SET_IDLE   0x90
#define HIDP_TRANS_DATA       0xa0
#define HIDP_TRANS_DATC       0xb0

/* HIDP handshake parameters */
#define HIDP_HSHK_SUCCESSFUL 0x00
#define HIDP_HSHK_NOT_READY  0x01
#define HIDP_HSHK_ERR_INVALID_REPORT_ID 0x02
#define HIDP_HSHK_ERR_UNSUPPORTED_REQUEST 0x03
#define HIDP_HSHK_ERR_INVALID_PARAMETER 0x04
#define HIDP_HSHK_ERR_UNKNOWN 0x0e
#define HIDP_HSHK_ERR_FATAL   0x0f

/* HID control operations */
#define HIDP_CTRL_NOP        0x00
#define HIDP_CTRL_HARD_RESET 0x01
#define HIDP_CTRL_SOFT_RESET 0x02
#define HIDP_CTRL_SUSPEND    0x03
#define HIDP_CTRL_EXIT_SUSPEND 0x04
#define HIDP_CTRL_VIRTUAL_CABLE_UNPLUG 0x05

/* HID protocol modes */
#define HIDP_PROTO_BOOT_MODE   0x00
#define HIDP_PROTO_REPORT_MODE 0x01

#ifdef __cplusplus
}
#endif

#endif /* __HIDP_H */