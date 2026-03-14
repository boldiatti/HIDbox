#ifndef __L2CAP_H
#define __L2CAP_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <sys/socket.h>

/* L2CAP sockets */
#define BTPROTO_L2CAP 0

/* L2CAP options */
#define L2CAP_OPTIONS 1
#define L2CAP_LM      2

/* L2CAP modes */
#define L2CAP_MODE_BASIC      0x00
#define L2CAP_MODE_RETRANS    0x01
#define L2CAP_MODE_FLOWCTL    0x02
#define L2CAP_MODE_ERTM       0x03
#define L2CAP_MODE_STREAMING  0x04

/* L2CAP link modes */
#define L2CAP_LM_MASTER   0x0001
#define L2CAP_LM_AUTH     0x0002
#define L2CAP_LM_ENCRYPT  0x0004
#define L2CAP_LM_TRUSTED  0x0008
#define L2CAP_LM_RELIABLE 0x0010
#define L2CAP_LM_SECURE   0x0020

/* L2CAP socket address */
struct sockaddr_l2 {
    sa_family_t    l2_family;
    unsigned short l2_psm;
    bdaddr_t       l2_bdaddr;
    unsigned short l2_cid;
    uint8_t        l2_bdaddr_type;
};

/* L2CAP options structure */
struct l2cap_options {
    uint16_t omtu;
    uint16_t imtu;
    uint16_t flush_to;
    uint8_t  mode;
    uint8_t  fcs;
    uint8_t  max_tx;
    uint16_t txwin_size;
};

#ifdef __cplusplus
}
#endif

#endif /* __L2CAP_H */