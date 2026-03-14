#include "hidbox.h"
#include <stdio.h>
#include <string.h>

// Very simple JSON parsing – just for demonstration.
// In a real project, you'd want a proper JSON library.
void profile_set_default(ControllerProfile *profile) {
    strcpy(profile->name, "Default");
    profile->deadzone = DEADZONE_DEFAULT;
    profile->invert_lx = false;
    profile->invert_ly = false;
    profile->invert_rx = false;
    profile->invert_ry = false;
    profile->calib_lx_center = 0;
    profile->calib_ly_center = 0;
    profile->calib_rx_center = 0;
    profile->calib_ry_center = 0;
    memset(profile->button_map, 0, sizeof(profile->button_map));
    memset(profile->axis_map, 0, sizeof(profile->axis_map));
}

bool profile_load(ControllerProfile *profile, const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) {
        profile_set_default(profile);
        return false;
    }
    // Dummy parse – just reads deadzone and name if present
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "\"name\"")) {
            char *start = strchr(line, ':') + 1;
            while (*start == ' ' || *start == '"') start++;
            char *end = strchr(start, '"');
            if (end) *end = '\0';
            strncpy(profile->name, start, MAX_PROFILE_NAME-1);
            profile->name[MAX_PROFILE_NAME-1] = 0;
        } else if (strstr(line, "\"deadzone\"")) {
            char *start = strchr(line, ':') + 1;
            profile->deadzone = atoi(start);
        }
    }
    fclose(f);
    return true;
}

bool profile_save(const ControllerProfile *profile, const char *path) {
    FILE *f = fopen(path, "w");
    if (!f) return false;
    fprintf(f, "{\n");
    fprintf(f, "  \"name\": \"%s\",\n", profile->name);
    fprintf(f, "  \"deadzone\": %d,\n", profile->deadzone);
    fprintf(f, "  \"invert_lx\": %s,\n", profile->invert_lx ? "true" : "false");
    fprintf(f, "  \"invert_ly\": %s,\n", profile->invert_ly ? "true" : "false");
    fprintf(f, "  \"invert_rx\": %s,\n", profile->invert_rx ? "true" : "false");
    fprintf(f, "  \"invert_ry\": %s\n", profile->invert_ry ? "true" : "false");
    fprintf(f, "}\n");
    fclose(f);
    return true;
}