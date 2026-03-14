#!/bin/sh
#===============================================================================
# HIDBOX Common Library Native Installer for RG35XX H
# Builds and installs common static library and headers.
#===============================================================================

set -e

#===============================================================================
# Safety checks
#===============================================================================
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] This installer must be run as root." >&2
    exit 1
fi

#===============================================================================
# Configuration
#===============================================================================
APPNAME="hidbox-common"
APPDIR="/mnt/SDCARD/App/${APPNAME}"
BUILDDIR="/tmp/${APPNAME}-build"
LIBDIR="/usr/local/lib"
INCDIR="/usr/local/include/hidbox"

#===============================================================================
# Check required tools
#===============================================================================
echo "[INFO] Checking required tools..."
for tool in gcc ar ranlib mkdir cp rm; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "[ERROR] $tool not found. Please install base development tools." >&2
        exit 1
    fi
done

#===============================================================================
# Create temporary build directory
#===============================================================================
echo "[INFO] Creating build directory: $BUILDDIR"
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR"

#===============================================================================
# Write source files (common modules)
#===============================================================================
echo "[INFO] Writing common source files..."

# logger.h
cat > "$BUILDDIR/logger.h" << 'EOF'
#ifndef HIDBOX_LOGGER_H
#define HIDBOX_LOGGER_H

#include <stdio.h>
#include <stdarg.h>

typedef enum {
    LOG_LEVEL_ERROR = 0,
    LOG_LEVEL_WARNING,
    LOG_LEVEL_INFO,
    LOG_LEVEL_DEBUG,
    LOG_LEVEL_TRACE
} LogLevel;

int logger_init(const char* log_path, LogLevel level);
void logger_cleanup(void);
void log_message(LogLevel level, const char* file, int line, const char* func, const char* format, ...);

#define LOG_ERROR(fmt, ...) log_message(LOG_LEVEL_ERROR, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define LOG_WARN(fmt, ...)  log_message(LOG_LEVEL_WARNING, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define LOG_INFO(fmt, ...)  log_message(LOG_LEVEL_INFO, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define LOG_DEBUG(fmt, ...) log_message(LOG_LEVEL_DEBUG, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)
#define LOG_TRACE(fmt, ...) log_message(LOG_LEVEL_TRACE, __FILE__, __LINE__, __func__, fmt, ##__VA_ARGS__)

#endif
EOF

# logger.c
cat > "$BUILDDIR/logger.c" << 'EOF'
#include "logger.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>

static FILE* g_log_file = NULL;
static LogLevel g_log_level = LOG_LEVEL_INFO;
static pthread_mutex_t g_log_mutex = PTHREAD_MUTEX_INITIALIZER;

static const char* level_strings[] = {
    "ERROR",
    "WARN",
    "INFO",
    "DEBUG",
    "TRACE"
};

int logger_init(const char* log_path, LogLevel level) {
    pthread_mutex_lock(&g_log_mutex);
    if (g_log_file) fclose(g_log_file);
    g_log_file = fopen(log_path, "a");
    if (!g_log_file) {
        pthread_mutex_unlock(&g_log_mutex);
        return -1;
    }
    g_log_level = level;
    time_t now = time(NULL);
    char time_str[64];
    strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
    fprintf(g_log_file, "\n=== HIDBOX Log started at %s ===\n", time_str);
    fflush(g_log_file);
    pthread_mutex_unlock(&g_log_mutex);
    return 0;
}

void logger_cleanup(void) {
    pthread_mutex_lock(&g_log_mutex);
    if (g_log_file) {
        time_t now = time(NULL);
        char time_str[64];
        strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", localtime(&now));
        fprintf(g_log_file, "=== HIDBOX Log ended at %s ===\n\n", time_str);
        fclose(g_log_file);
        g_log_file = NULL;
    }
    pthread_mutex_unlock(&g_log_mutex);
}

void log_message(LogLevel level, const char* file, int line, const char* func, const char* format, ...) {
    if (level > g_log_level || !g_log_file) return;
    pthread_mutex_lock(&g_log_mutex);
    time_t now = time(NULL);
    struct tm* tm_info = localtime(&now);
    char time_str[32];
    strftime(time_str, sizeof(time_str), "%H:%M:%S", tm_info);
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    int ms = ts.tv_nsec / 1000000;
    fprintf(g_log_file, "[%s.%03d] %-5s %s:%d (%s): ", time_str, ms, level_strings[level], file, line, func);
    va_list args;
    va_start(args, format);
    vfprintf(g_log_file, format, args);
    va_end(args);
    fprintf(g_log_file, "\n");
    fflush(g_log_file);
    pthread_mutex_unlock(&g_log_mutex);
}
EOF

# utils.h
cat > "$BUILDDIR/utils.h" << 'EOF'
#ifndef HIDBOX_UTILS_H
#define HIDBOX_UTILS_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#define AXIS_MAX 32767
#define AXIS_MIN -32767

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

#endif
EOF

# utils.c
cat > "$BUILDDIR/utils.c" << 'EOF'
#include "utils.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/stat.h>
#include <dirent.h>
#include <signal.h>
#include <ctype.h>
#include <math.h>

uint64_t get_timestamp_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

void sleep_ms(int ms) {
    usleep(ms * 1000);
}

char* strdup_safe(const char* s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char* new_str = malloc(len);
    if (new_str) memcpy(new_str, s, len);
    return new_str;
}

void trim_string(char* str) {
    if (!str) return;
    char* start = str;
    while (isspace(*start)) start++;
    if (start != str) memmove(str, start, strlen(start) + 1);
    char* end = str + strlen(str) - 1;
    while (end >= str && isspace(*end)) *end-- = '\0';
}

int16_t apply_deadzone(int16_t value, int16_t deadzone) {
    if (abs(value) < deadzone) return 0;
    return value;
}

int16_t map_value(int16_t value, int16_t in_min, int16_t in_max, int16_t out_min, int16_t out_max) {
    if (in_max == in_min) return out_min;
    return (int16_t)((value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min);
}

bool file_exists(const char* path) {
    struct stat st;
    return (stat(path, &st) == 0);
}

bool create_directory(const char* path) {
    struct stat st = {0};
    if (stat(path, &st) == -1) return (mkdir(path, 0755) == 0);
    return true;
}

int get_pid_of_process(const char* process_name) {
    DIR* dir = opendir("/proc");
    if (!dir) return -1;
    struct dirent* entry;
    char path[256], line[256];
    while ((entry = readdir(dir)) != NULL) {
        if (!isdigit(entry->d_name[0])) continue;
        snprintf(path, sizeof(path), "/proc/%s/comm", entry->d_name);
        FILE* comm = fopen(path, "r");
        if (!comm) continue;
        if (fgets(line, sizeof(line), comm)) {
            line[strcspn(line, "\n")] = 0;
            if (strcmp(line, process_name) == 0) {
                fclose(comm);
                closedir(dir);
                return atoi(entry->d_name);
            }
        }
        fclose(comm);
    }
    closedir(dir);
    return -1;
}

bool kill_process(int pid) {
    return (kill(pid, SIGTERM) == 0);
}
EOF

# cJSON.h (minimal)
cat > "$BUILDDIR/cJSON.h" << 'EOF'
#ifndef CJSON_H
#define CJSON_H

typedef struct cJSON {
    struct cJSON *next, *prev, *child;
    int type;
    char *valuestring;
    double valuedouble;
    char *string;
} cJSON;

#define cJSON_Object 1
#define cJSON_Array 2
#define cJSON_String 3
#define cJSON_Number 4

cJSON* cJSON_Parse(const char *value);
void cJSON_Delete(cJSON *item);
cJSON* cJSON_GetObjectItem(const cJSON * const object, const char * const string);
int cJSON_IsTrue(const cJSON * const item);
double cJSON_GetNumberValue(const cJSON * const item);
cJSON* cJSON_CreateObject(void);
cJSON* cJSON_CreateArray(void);
cJSON* cJSON_CreateString(const char *string);
cJSON* cJSON_CreateNumber(double num);
cJSON* cJSON_CreateBool(int b);
void cJSON_AddItemToArray(cJSON *array, cJSON *item);
void cJSON_AddItemToObject(cJSON *object, const char *string, cJSON *item);
void cJSON_AddStringToObject(cJSON *object, const char *name, const char *string);
void cJSON_AddNumberToObject(cJSON *object, const char *name, double number);
void cJSON_AddBoolToObject(cJSON *object, const char *name, int boolean);
int cJSON_GetArraySize(const cJSON *array);
cJSON* cJSON_GetArrayItem(const cJSON *array, int index);
char* cJSON_Print(const cJSON *item);

#endif
EOF

# cJSON.c (simplified)
cat > "$BUILDDIR/cJSON.c" << 'EOF'
#include "cJSON.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

typedef struct {
    const char* json;
    size_t position;
} parse_context;

static void skip_whitespace(parse_context* ctx) {
    while (ctx->json[ctx->position] == ' ' || ctx->json[ctx->position] == '\t' ||
           ctx->json[ctx->position] == '\n' || ctx->json[ctx->position] == '\r')
        ctx->position++;
}

static cJSON* parse_value(parse_context* ctx);
static cJSON* parse_object(parse_context* ctx);
static cJSON* parse_array(parse_context* ctx);
static char* parse_string(parse_context* ctx);
static double parse_number(parse_context* ctx);

cJSON* cJSON_Parse(const char* value) {
    if (!value) return NULL;
    parse_context ctx = {value, 0};
    skip_whitespace(&ctx);
    return parse_value(&ctx);
}

static cJSON* parse_value(parse_context* ctx) {
    skip_whitespace(ctx);
    switch (ctx->json[ctx->position]) {
        case '{': return parse_object(ctx);
        case '[': return parse_array(ctx);
        case '"': {
            cJSON* item = calloc(1, sizeof(cJSON));
            item->type = cJSON_String;
            item->valuestring = parse_string(ctx);
            if (!item->valuestring) { free(item); return NULL; }
            return item;
        }
        case 't':
            if (strncmp(ctx->json + ctx->position, "true", 4) == 0) {
                ctx->position += 4;
                cJSON* item = calloc(1, sizeof(cJSON));
                item->type = cJSON_Number;
                item->valuedouble = 1;
                return item;
            }
            break;
        case 'f':
            if (strncmp(ctx->json + ctx->position, "false", 5) == 0) {
                ctx->position += 5;
                cJSON* item = calloc(1, sizeof(cJSON));
                item->type = cJSON_Number;
                item->valuedouble = 0;
                return item;
            }
            break;
        case 'n':
            if (strncmp(ctx->json + ctx->position, "null", 4) == 0) {
                ctx->position += 4;
                return NULL;
            }
            break;
        default:
            if ((ctx->json[ctx->position] >= '0' && ctx->json[ctx->position] <= '9') || ctx->json[ctx->position] == '-') {
                cJSON* item = calloc(1, sizeof(cJSON));
                item->type = cJSON_Number;
                item->valuedouble = parse_number(ctx);
                return item;
            }
            break;
    }
    return NULL;
}

static cJSON* parse_object(parse_context* ctx) {
    if (ctx->json[ctx->position] != '{') return NULL;
    ctx->position++;
    cJSON* root = calloc(1, sizeof(cJSON));
    root->type = cJSON_Object;
    cJSON* current = NULL;
    skip_whitespace(ctx);
    if (ctx->json[ctx->position] == '}') { ctx->position++; return root; }
    while (1) {
        skip_whitespace(ctx);
        if (ctx->json[ctx->position] != '"') { cJSON_Delete(root); return NULL; }
        char* key = parse_string(ctx);
        if (!key) { cJSON_Delete(root); return NULL; }
        skip_whitespace(ctx);
        if (ctx->json[ctx->position] != ':') { free(key); cJSON_Delete(root); return NULL; }
        ctx->position++;
        cJSON* value = parse_value(ctx);
        if (!value) { free(key); cJSON_Delete(root); return NULL; }
        value->string = key;
        if (!root->child) root->child = value;
        else { current->next = value; value->prev = current; }
        current = value;
        skip_whitespace(ctx);
        if (ctx->json[ctx->position] == '}') { ctx->position++; break; }
        if (ctx->json[ctx->position] != ',') { cJSON_Delete(root); return NULL; }
        ctx->position++;
    }
    return root;
}

static cJSON* parse_array(parse_context* ctx) {
    if (ctx->json[ctx->position] != '[') return NULL;
    ctx->position++;
    cJSON* root = calloc(1, sizeof(cJSON));
    root->type = cJSON_Array;
    cJSON* current = NULL;
    skip_whitespace(ctx);
    if (ctx->json[ctx->position] == ']') { ctx->position++; return root; }
    while (1) {
        cJSON* value = parse_value(ctx);
        if (!value) { cJSON_Delete(root); return NULL; }
        if (!root->child) root->child = value;
        else { current->next = value; value->prev = current; }
        current = value;
        skip_whitespace(ctx);
        if (ctx->json[ctx->position] == ']') { ctx->position++; break; }
        if (ctx->json[ctx->position] != ',') { cJSON_Delete(root); return NULL; }
        ctx->position++;
        skip_whitespace(ctx);
    }
    return root;
}

static char* parse_string(parse_context* ctx) {
    if (ctx->json[ctx->position] != '"') return NULL;
    ctx->position++;
    size_t start = ctx->position;
    while (ctx->json[ctx->position] != '"' && ctx->json[ctx->position] != '\0') {
        if (ctx->json[ctx->position] == '\\' && ctx->json[ctx->position + 1] != '\0')
            ctx->position += 2;
        else
            ctx->position++;
    }
    if (ctx->json[ctx->position] != '"') return NULL;
    size_t len = ctx->position - start;
    char* str = malloc(len + 1);
    if (!str) return NULL;
    size_t j = 0;
    for (size_t i = start; i < ctx->position; i++) {
        if (ctx->json[i] == '\\' && i + 1 < ctx->position) {
            switch (ctx->json[i+1]) {
                case '"': str[j++] = '"'; i++; break;
                case '\\': str[j++] = '\\'; i++; break;
                case '/': str[j++] = '/'; i++; break;
                case 'b': str[j++] = '\b'; i++; break;
                case 'f': str[j++] = '\f'; i++; break;
                case 'n': str[j++] = '\n'; i++; break;
                case 'r': str[j++] = '\r'; i++; break;
                case 't': str[j++] = '\t'; i++; break;
                default: str[j++] = ctx->json[i]; break;
            }
        } else {
            str[j++] = ctx->json[i];
        }
    }
    str[j] = '\0';
    ctx->position++;
    return str;
}

static double parse_number(parse_context* ctx) {
    size_t start = ctx->position;
    while ((ctx->json[ctx->position] >= '0' && ctx->json[ctx->position] <= '9') ||
           ctx->json[ctx->position] == '.' || ctx->json[ctx->position] == 'e' ||
           ctx->json[ctx->position] == 'E' || ctx->json[ctx->position] == '+' ||
           ctx->json[ctx->position] == '-') {
        ctx->position++;
    }
    char num_str[64];
    size_t len = ctx->position - start;
    if (len >= sizeof(num_str)) len = sizeof(num_str) - 1;
    strncpy(num_str, ctx->json + start, len);
    num_str[len] = '\0';
    return strtod(num_str, NULL);
}

void cJSON_Delete(cJSON* item) {
    if (!item) return;
    cJSON* next = item->child;
    while (next) {
        cJSON* current = next;
        next = next->next;
        cJSON_Delete(current);
    }
    if (item->valuestring) free(item->valuestring);
    if (item->string) free(item->string);
    free(item);
}

cJSON* cJSON_GetObjectItem(const cJSON* const object, const char* const string) {
    if (!object || object->type != cJSON_Object || !string) return NULL;
    cJSON* child = object->child;
    while (child) {
        if (child->string && strcmp(child->string, string) == 0) return child;
        child = child->next;
    }
    return NULL;
}

int cJSON_IsTrue(const cJSON* const item) {
    return item && item->type == cJSON_Number && item->valuedouble != 0;
}

double cJSON_GetNumberValue(const cJSON* const item) {
    return (item && item->type == cJSON_Number) ? item->valuedouble : 0;
}

cJSON* cJSON_CreateObject(void) { return calloc(1, sizeof(cJSON)); }
cJSON* cJSON_CreateArray(void) { return calloc(1, sizeof(cJSON)); }
cJSON* cJSON_CreateString(const char* string) {
    cJSON* item = calloc(1, sizeof(cJSON));
    item->type = cJSON_String;
    item->valuestring = strdup_safe(string);
    if (!item->valuestring && string) { free(item); return NULL; }
    return item;
}
cJSON* cJSON_CreateNumber(double num) {
    cJSON* item = calloc(1, sizeof(cJSON));
    item->type = cJSON_Number;
    item->valuedouble = num;
    return item;
}
cJSON* cJSON_CreateBool(int b) {
    cJSON* item = calloc(1, sizeof(cJSON));
    item->type = cJSON_Number;
    item->valuedouble = b ? 1 : 0;
    return item;
}
void cJSON_AddItemToArray(cJSON* array, cJSON* item) {
    if (!array || array->type != cJSON_Array || !item) return;
    if (!array->child) array->child = item;
    else {
        cJSON* last = array->child;
        while (last->next) last = last->next;
        last->next = item;
        item->prev = last;
    }
}
void cJSON_AddItemToObject(cJSON* object, const char* string, cJSON* item) {
    if (!object || object->type != cJSON_Object || !item) return;
    item->string = strdup_safe(string);
    if (!object->child) object->child = item;
    else {
        cJSON* last = object->child;
        while (last->next) last = last->next;
        last->next = item;
        item->prev = last;
    }
}
void cJSON_AddStringToObject(cJSON* object, const char* name, const char* string) {
    cJSON_AddItemToObject(object, name, cJSON_CreateString(string));
}
void cJSON_AddNumberToObject(cJSON* object, const char* name, double number) {
    cJSON_AddItemToObject(object, name, cJSON_CreateNumber(number));
}
void cJSON_AddBoolToObject(cJSON* object, const char* name, int boolean) {
    cJSON_AddItemToObject(object, name, cJSON_CreateBool(boolean));
}
int cJSON_GetArraySize(const cJSON* array) {
    if (!array || array->type != cJSON_Array) return 0;
    int size = 0;
    cJSON* child = array->child;
    while (child) { size++; child = child->next; }
    return size;
}
cJSON* cJSON_GetArrayItem(const cJSON* array, int index) {
    if (!array || array->type != cJSON_Array || index < 0) return NULL;
    cJSON* child = array->child;
    for (int i = 0; child && i < index; i++) child = child->next;
    return child;
}
char* cJSON_Print(const cJSON* item) {
    if (!item) return NULL;
    if (item->type == cJSON_String) {
        size_t len = strlen(item->valuestring) + 3;
        char* str = malloc(len);
        snprintf(str, len, "\"%s\"", item->valuestring);
        return str;
    } else if (item->type == cJSON_Number) {
        char str[64];
        snprintf(str, sizeof(str), "%g", item->valuedouble);
        return strdup_safe(str);
    } else if (item->type == cJSON_Object || item->type == cJSON_Array) {
        return strdup_safe(item->type == cJSON_Object ? "{}" : "[]");
    }
    return NULL;
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling common library..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c logger.c utils.c cJSON.c
ar rcs libhidbox-common.a logger.o utils.o cJSON.o
ranlib libhidbox-common.a

if [ ! -f "libhidbox-common.a" ]; then
    echo "[ERROR] Library compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-common.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-common.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp logger.h utils.h cJSON.h "$INCDIR/"
chmod 644 "$INCDIR/"*.h

#===============================================================================
# Create launcher (info only)
#===============================================================================
LAUNCHER="/mnt/SDCARD/Roms/Apps/hidbox-common.sh"
mkdir -p "$(dirname "$LAUNCHER")"
cat > "$LAUNCHER" << EOF
#!/bin/sh
echo "HIDBOX common library installed."
echo "Library: $LIBDIR/libhidbox-common.a"
echo "Headers: $INCDIR/"
read -p "Press Enter to exit"
EOF
chmod 755 "$LAUNCHER"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX common library installed successfully."
echo "     Library: $LIBDIR/libhidbox-common.a"
echo "     Headers: $INCDIR/"
exit 0
EOF