#include "hidbox.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>

int ipc_server_init(IPCContext *ctx) {
    unlink(HIDBOX_SOCKET_PATH);
    ctx->socket_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (ctx->socket_fd < 0) return -1;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, HIDBOX_SOCKET_PATH, sizeof(addr.sun_path)-1);

    if (bind(ctx->socket_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(ctx->socket_fd);
        return -1;
    }

    if (listen(ctx->socket_fd, 1) < 0) {
        close(ctx->socket_fd);
        return -1;
    }

    int flags = fcntl(ctx->socket_fd, F_GETFL, 0);
    fcntl(ctx->socket_fd, F_SETFL, flags | O_NONBLOCK);
    ctx->client_fd = -1;
    return 0;
}

void ipc_server_cleanup(IPCContext *ctx) {
    if (ctx->client_fd >= 0) close(ctx->client_fd);
    if (ctx->socket_fd >= 0) close(ctx->socket_fd);
    unlink(HIDBOX_SOCKET_PATH);
    ctx->socket_fd = -1;
    ctx->client_fd = -1;
}

int ipc_server_accept(IPCContext *ctx) {
    if (ctx->client_fd >= 0) return ctx->client_fd;
    struct sockaddr_un client_addr;
    socklen_t len = sizeof(client_addr);
    ctx->client_fd = accept(ctx->socket_fd, (struct sockaddr*)&client_addr, &len);
    if (ctx->client_fd >= 0) {
        int flags = fcntl(ctx->client_fd, F_GETFL, 0);
        fcntl(ctx->client_fd, F_SETFL, flags | O_NONBLOCK);
    }
    return ctx->client_fd;
}

int ipc_server_recv(IPCContext *ctx, char *buf, size_t size) {
    if (ctx->client_fd < 0) return -1;
    int n = recv(ctx->client_fd, buf, size, 0);
    if (n <= 0) {
        close(ctx->client_fd);
        ctx->client_fd = -1;
    }
    return n;
}

int ipc_server_send(IPCContext *ctx, const char *buf, size_t len) {
    if (ctx->client_fd < 0) return -1;
    return send(ctx->client_fd, buf, len, MSG_NOSIGNAL);
}

int ipc_client_connect(void) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, HIDBOX_SOCKET_PATH);

    if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

int ipc_client_send(int fd, const char *cmd) {
    return write(fd, cmd, strlen(cmd));
}

int ipc_client_recv(int fd, char *buf, size_t size) {
    return read(fd, buf, size);
}