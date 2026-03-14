#include "hidbox.h"
#include <unistd.h>

void reconnect_init(ReconnectContext *ctx) {
    ctx->attempts = 0;
    ctx->in_progress = false;
    ctx->enabled = true;
}

bool reconnect_start(ReconnectContext *ctx) {
    if (!ctx->enabled || ctx->in_progress) return false;
    ctx->in_progress = true;
    ctx->attempts = 0;
    return true;
}

void reconnect_stop(ReconnectContext *ctx) {
    ctx->in_progress = false;
    ctx->attempts = 0;
}

bool reconnect_attempt(ReconnectContext *ctx, bool (*connect_func)(void)) {
    if (!ctx->in_progress) return false;
    while (ctx->attempts < 10) {
        ctx->attempts++;
        if (connect_func()) {
            ctx->in_progress = false;
            return true;
        }
        sleep(2);
    }
    ctx->in_progress = false;
    return false;
}