#ifndef __BLUETOOTH_H
#define __BLUETOOTH_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/* Bluetooth addressing */
typedef struct {
    uint8_t b[6];
} __attribute__((packed)) bdaddr_t;

#define BDADDR_ANY   (&(bdaddr_t) {{0, 0, 0, 0, 0, 0}})
#define BDADDR_LOCAL (&(bdaddr_t) {{0, 0, 0, 0xff, 0xff, 0xff}})

/* Compare two Bluetooth addresses */
static inline int bacmp(const bdaddr_t *ba1, const bdaddr_t *ba2) {
    return memcmp(ba1, ba2, sizeof(bdaddr_t));
}

/* Copy Bluetooth address */
static inline void bacpy(bdaddr_t *dst, const bdaddr_t *src) {
    memcpy(dst, src, sizeof(bdaddr_t));
}

/* Convert string to Bluetooth address */
int str2ba(const char *str, bdaddr_t *ba);

/* Convert Bluetooth address to string */
char *batostr(const bdaddr_t *ba);

/* Bluetooth protocol families */
#define AF_BLUETOOTH 31
#define PF_BLUETOOTH AF_BLUETOOTH

/* Bluetooth socket levels */
#define SOL_BLUETOOTH 274

/* Bluetooth protocols */
#define BTPROTO_L2CAP 0
#define BTPROTO_HCI   1
#define BTPROTO_SCO   2
#define BTPROTO_RFCOMM 3
#define BTPROTO_BNEP  4
#define BTPROTO_CMTP  5
#define BTPROTO_HIDP  6
#define BTPROTO_AVDTP 7

/* Byte order conversions (for little-endian ARM) */
#define htobs(d) (d)
#define htobl(d) (d)
#define btohs(d) (d)
#define btohl(d) (d)

#ifdef __cplusplus
}
#endif

#endif /* __BLUETOOTH_H */