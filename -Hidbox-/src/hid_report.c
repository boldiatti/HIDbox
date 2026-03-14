#include "hidbox.h"
#include <string.h>
#include <time.h>

void hid_report_clear(HIDReport *report) {
    memset(report, 0, sizeof(HIDReport));
}

void hid_report_set_button(HIDReport *report, HIDButton btn, int pressed) {
    int byte = btn / 8;
    int bit = btn % 8;
    if (byte < (HID_BTN_MAX+7)/8) {
        if (pressed)
            report->buttons[byte] |= (1 << bit);
        else
            report->buttons[byte] &= ~(1 << bit);
    }
}

void hid_report_set_axis(HIDReport *report, HIDAxis axis, int16_t value) {
    if (axis < HID_AXIS_MAX)
        report->axes[axis] = value;
}

void hid_report_build_usb(uint8_t *out, const HIDReport *report) {
    // USB report format: 2 bytes buttons, 4 axes (16-bit), 2 triggers (8-bit)
    out[0] = report->buttons[0];
    out[1] = report->buttons[1];
    // LX
    out[2] = report->axes[HID_AXIS_LX] & 0xFF;
    out[3] = (report->axes[HID_AXIS_LX] >> 8) & 0xFF;
    // LY
    out[4] = report->axes[HID_AXIS_LY] & 0xFF;
    out[5] = (report->axes[HID_AXIS_LY] >> 8) & 0xFF;
    // RX
    out[6] = report->axes[HID_AXIS_RX] & 0xFF;
    out[7] = (report->axes[HID_AXIS_RX] >> 8) & 0xFF;
    // RY
    out[8] = report->axes[HID_AXIS_RY] & 0xFF;
    out[9] = (report->axes[HID_AXIS_RY] >> 8) & 0xFF;
    // LT
    out[10] = (report->axes[HID_AXIS_LT] >> 8) & 0xFF; // or clamp to 0-255
    // RT
    out[11] = (report->axes[HID_AXIS_RT] >> 8) & 0xFF;
}