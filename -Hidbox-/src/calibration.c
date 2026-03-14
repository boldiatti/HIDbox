#include "hidbox.h"
#include <string.h>

static int16_t samples[MAX_AXES][100];
static int sample_count[MAX_AXES];
static bool calibrating = false;

void calibration_start(void) {
    calibrating = true;
    for (int i = 0; i < MAX_AXES; i++)
        sample_count[i] = 0;
}

void calibration_add_sample(int axis, int16_t value) {
    if (!calibrating) return;
    if (axis >= MAX_AXES) return;
    if (sample_count[axis] < 100)
        samples[axis][sample_count[axis]++] = value;
}

bool calibration_complete(void) {
    if (!calibrating) return false;
    for (int i = 0; i < MAX_AXES; i++)
        if (sample_count[i] < 100) return false;
    return true;
}

void calibration_compute(CalibrationData *out) {
    for (int axis = 0; axis < MAX_AXES; axis++) {
        int32_t sum = 0;
        int16_t min = 32767, max = -32768;
        for (int i = 0; i < sample_count[axis]; i++) {
            int16_t v = samples[axis][i];
            sum += v;
            if (v < min) min = v;
            if (v > max) max = v;
        }
        out->min[axis] = min;
        out->max[axis] = max;
        out->center[axis] = sum / sample_count[axis];
        out->calibrated[axis] = true;
    }
    out->timestamp = get_timestamp_us();
    calibrating = false;
}

void calibration_reset(CalibrationData *data) {
    memset(data, 0, sizeof(CalibrationData));
}

int16_t calibration_apply(const CalibrationData *data, int axis, int16_t value) {
    if (!data->calibrated[axis]) return value;
    return value - data->center[axis];
}