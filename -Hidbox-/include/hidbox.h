#ifndef HIDBOX_H
#define HIDBOX_H

#include <stdint.h>
#include <stdbool.h>
#include <linux/input.h>
#include <time.h>
#include <pthread.h>

// Include our local Bluetooth headers
#include <bluetooth/bluetooth.h>
#include <bluetooth/hci.h>
#include <bluetooth/hci_lib.h>
#include <bluetooth/l2cap.h>
#include <bluetooth/hidp.h>

#define HIDBOX_SOCKET_PATH "/tmp/hidbox.sock"
#define MAX_PROFILE_NAME 64
#define MAX_BUTTONS 32
#define MAX_AXES 8
#define DEADZONE_DEFAULT 2000
#define AXIS_MAX 32767
#define AXIS_MIN -32767
#define KEY_MAX 512
#define ABS_MAX 64

typedef enum {
    HID_BTN_A, HID_BTN_B, HID_BTN_X, HID_BTN_Y,
    HID_BTN_L1, HID_BTN_R1, HID_BTN_L2, HID_BTN_R2,
    HID_BTN_SELECT, HID_BTN_START, HID_BTN_HOME,
    HID_BTN_THUMBL, HID_BTN_THUMBR,
    HID_BTN_DPAD_UP, HID_BTN_DPAD_DOWN, HID_BTN_DPAD_LEFT, HID_BTN_DPAD_RIGHT,
    HID_BTN_MAX
} HIDButton;

typedef enum {
    HID_AXIS_LX, HID_AXIS_LY, HID_AXIS_RX, HID_AXIS_RY,
    HID_AXIS_LT, HID_AXIS_RT, HID_AXIS_MAX
} HIDAxis;

typedef struct {
    uint8_t buttons[(HID_BTN_MAX + 7) / 8];
    int16_t axes[HID_AXIS_MAX];
    uint64_t timestamp;
} HIDReport;

typedef struct {
    char name[MAX_PROFILE_NAME];
    int deadzone;
    bool invert_lx, invert_ly, invert_rx, invert_ry;
    int16_t calib_lx_center, calib_ly_center, calib_rx_center, calib_ry_center;
    int button_map[KEY_MAX];
    int axis_map[ABS_MAX];
} ControllerProfile;

// evdev
int open_evdev(void);
void close_evdev(int fd);
int read_evdev(int fd, int* button_map, int* axis_map);

// hid report
void hid_report_clear(HIDReport* report);
void hid_report_set_button(HIDReport* report, HIDButton btn, int pressed);
void hid_report_set_axis(HIDReport* report, HIDAxis axis, int16_t value);
void hid_report_build_usb(uint8_t* out, const HIDReport* report);

// usb gadget
bool usb_gadget_init(void);
bool usb_gadget_send_report(const uint8_t* report, size_t len);
void usb_gadget_cleanup(void);
bool usb_gadget_is_connected(void);

// bluetooth hid (always available, may fail at runtime)
bool bt_hid_init(void);
bool bt_hid_send_report(const uint8_t* report, size_t len);
void bt_hid_cleanup(void);
bool bt_hid_is_connected(void);

// ipc
typedef struct { int socket_fd; int client_fd; } IPCContext;
int ipc_server_init(IPCContext* ctx);
void ipc_server_cleanup(IPCContext* ctx);
int ipc_server_accept(IPCContext* ctx);
int ipc_server_recv(IPCContext* ctx, char* buf, size_t size);
int ipc_server_send(IPCContext* ctx, const char* buf, size_t len);
int ipc_client_connect(void);
int ipc_client_send(int fd, const char* cmd);
int ipc_client_recv(int fd, char* buf, size_t size);

// profile
bool profile_load(ControllerProfile* profile, const char* path);
bool profile_save(const ControllerProfile* profile, const char* path);
void profile_set_default(ControllerProfile* profile);

// calibration
typedef struct { int16_t min[MAX_AXES]; int16_t max[MAX_AXES]; int16_t center[MAX_AXES]; bool calibrated[MAX_AXES]; uint64_t timestamp; } CalibrationData;
void calibration_start(void);
void calibration_add_sample(int axis, int16_t value);
bool calibration_complete(void);
void calibration_compute(CalibrationData* out);
void calibration_reset(CalibrationData* data);
int16_t calibration_apply(const CalibrationData* data, int axis, int16_t value);

// descriptors
typedef enum { CONTROLLER_TYPE_GENERIC, CONTROLLER_TYPE_XBOX360, CONTROLLER_TYPE_PS4, CONTROLLER_TYPE_SWITCH_PRO, CONTROLLER_TYPE_RG35XXH, CONTROLLER_TYPE_MAX } ControllerType;
const uint8_t* hid_descriptor_get(ControllerType type, size_t* len);

// reconnect
typedef struct { int attempts; bool in_progress; bool enabled; } ReconnectContext;
void reconnect_init(ReconnectContext* ctx);
bool reconnect_start(ReconnectContext* ctx);
void reconnect_stop(ReconnectContext* ctx);
bool reconnect_attempt(ReconnectContext* ctx, bool (*connect_func)(void));

// udev monitor
typedef struct { int fd; } UdevMonitor;
int udev_monitor_init(UdevMonitor* mon);
int udev_monitor_get_fd(const UdevMonitor* mon);
int udev_monitor_read_event(UdevMonitor* mon, char* buf, size_t len);
void udev_monitor_cleanup(UdevMonitor* mon);

// skin manager (needs SDL2)
#ifdef USE_SDL2
#include <SDL2/SDL.h>
typedef struct { char name[64]; SDL_Texture* bg; SDL_Texture* buttons[16]; SDL_Texture* axes[6]; } Skin;
bool skin_load(Skin* skin, SDL_Renderer* renderer, const char* base_path, const char* skin_name);
void skin_free(Skin* skin);
#endif

// utils
uint64_t get_timestamp_us(void);
void sleep_ms(int ms);
char* strdup_safe(const char* s);
void trim_string(char* str);
int16_t apply_deadzone(int16_t value, int16_t deadzone);
int16_t map_value(int16_t value, int16_t in_min, int16_t in_max, int16_t out_min, int16_t out_max);
bool file_exists(const char* path);
bool create_directory(const char* path);
int get_pid_of_process(const char* process_name);
bool kill_process(int pid);

// logging
typedef enum { LOG_LEVEL_ERROR, LOG_LEVEL_WARNING, LOG_LEVEL_INFO, LOG_LEVEL_DEBUG, LOG_LEVEL_TRACE } LogLevel;
int logger_init(const char* log_path, LogLevel level);
void logger_cleanup(void);
void log_message(LogLevel level, const char* file, int line, const char* func, const char* format, ...);
#define LOG_ERROR(fmt, ...) log_message(LOG_LEVEL_ERROR, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define LOG_WARN(fmt, ...)  log_message(LOG_LEVEL_WARNING, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define LOG_INFO(fmt, ...)  log_message(LOG_LEVEL_INFO, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define LOG_DEBUG(fmt, ...) log_message(LOG_LEVEL_DEBUG, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define LOG_TRACE(fmt, ...) log_message(LOG_LEVEL_TRACE, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)

#endif