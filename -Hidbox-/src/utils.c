#include "hidbox.h"
#include <time.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/stat.h>
#include <dirent.h>
#include <signal.h>

uint64_t get_timestamp_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

void sleep_ms(int ms) {
    usleep(ms * 1000);
}

char *strdup_safe(const char *s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char *p = malloc(len);
    if (p) memcpy(p, s, len);
    return p;
}

void trim_string(char *str) {
    if (!str) return;
    char *start = str;
    while (isspace(*start)) start++;
    if (start != str) memmove(str, start, strlen(start)+1);
    char *end = str + strlen(str) - 1;
    while (end >= str && isspace(*end)) *end-- = '\0';
}

int16_t apply_deadzone(int16_t value, int16_t deadzone) {
    if (abs(value) < deadzone) return 0;
    return value;
}

int16_t map_value(int16_t value, int16_t in_min, int16_t in_max,
                   int16_t out_min, int16_t out_max) {
    if (in_max == in_min) return out_min;
    return (int16_t)((value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min);
}

bool file_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0;
}

bool create_directory(const char *path) {
    if (mkdir(path, 0755) == 0) return true;
    return errno == EEXIST;
}

int get_pid_of_process(const char *process_name) {
    DIR *dir = opendir("/proc");
    if (!dir) return -1;
    struct dirent *entry;
    char path[256], line[256];
    while ((entry = readdir(dir)) != NULL) {
        if (!isdigit(entry->d_name[0])) continue;
        snprintf(path, sizeof(path), "/proc/%s/comm", entry->d_name);
        FILE *f = fopen(path, "r");
        if (!f) continue;
        if (fgets(line, sizeof(line), f)) {
            line[strcspn(line, "\n")] = 0;
            if (strcmp(line, process_name) == 0) {
                fclose(f);
                closedir(dir);
                return atoi(entry->d_name);
            }
        }
        fclose(f);
    }
    closedir(dir);
    return -1;
}

bool kill_process(int pid) {
    return kill(pid, SIGTERM) == 0;
}