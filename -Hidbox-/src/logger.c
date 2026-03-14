#include "hidbox.h"
#include <stdio.h>
#include <time.h>
#include <pthread.h>

static FILE *log_file = NULL;
static LogLevel current_level = LOG_LEVEL_INFO;
static pthread_mutex_t log_mutex = PTHREAD_MUTEX_INITIALIZER;

static const char *level_str[] = {
    "ERROR", "WARN", "INFO", "DEBUG", "TRACE"
};

int logger_init(const char *log_path, LogLevel level) {
    pthread_mutex_lock(&log_mutex);
    if (log_file) fclose(log_file);
    log_file = fopen(log_path, "a");
    if (!log_file) {
        pthread_mutex_unlock(&log_mutex);
        return -1;
    }
    current_level = level;
    time_t t = time(NULL);
    char buf[64];
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", localtime(&t));
    fprintf(log_file, "\n=== HIDBOX log started at %s ===\n", buf);
    fflush(log_file);
    pthread_mutex_unlock(&log_mutex);
    return 0;
}

void logger_cleanup(void) {
    pthread_mutex_lock(&log_mutex);
    if (log_file) {
        time_t t = time(NULL);
        char buf[64];
        strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S", localtime(&t));
        fprintf(log_file, "=== HIDBOX log ended at %s ===\n", buf);
        fclose(log_file);
        log_file = NULL;
    }
    pthread_mutex_unlock(&log_mutex);
}

void log_message(LogLevel level, const char *file, int line, const char *func,
                 const char *fmt, ...) {
    if (level > current_level) return;
    pthread_mutex_lock(&log_mutex);
    if (!log_file) {
        pthread_mutex_unlock(&log_mutex);
        return;
    }
    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    char timebuf[32];
    strftime(timebuf, sizeof(timebuf), "%H:%M:%S", tm_info);

    fprintf(log_file, "[%s] %-5s %s:%d (%s): ", timebuf, level_str[level], file, line, func);
    va_list args;
    va_start(args, fmt);
    vfprintf(log_file, fmt, args);
    va_end(args);
    fprintf(log_file, "\n");
    fflush(log_file);
    pthread_mutex_unlock(&log_mutex);
}