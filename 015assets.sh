#!/bin/sh
#===============================================================================
# HIDBOX IPC Library Installer for RG35XX H
# Builds and installs libhidbox-ipc.a for inter-process communication.
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
LIBNAME="hidbox-ipc"
LIBDIR="/mnt/SDCARD/hidbox/lib"
INCDIR="/mnt/SDCARD/hidbox/include"
BUILDDIR="/tmp/${LIBNAME}-build"

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
# Write source files
#===============================================================================
echo "[INFO] Writing source files..."

# ipc.h
cat > "$BUILDDIR/ipc.h" << 'EOF'
#ifndef HIDBOX_IPC_H
#define HIDBOX_IPC_H

#include <stdbool.h>
#include <stddef.h>

#define HIDBOX_SOCKET_PATH "/tmp/hidbox.sock"
#define IPC_BUFFER_SIZE 4096

typedef struct {
    int socket_fd;
    int client_fd;
} IPCContext;

int ipc_server_init(IPCContext* ctx);
void ipc_server_cleanup(IPCContext* ctx);
int ipc_server_accept(IPCContext* ctx);
int ipc_server_recv(IPCContext* ctx, char* buf, size_t size);
int ipc_server_send(IPCContext* ctx, const char* buf, size_t len);

int ipc_client_connect(void);
int ipc_client_send(int fd, const char* cmd);
int ipc_client_recv(int fd, char* buf, size_t size);

#endif
EOF

# ipc.c
cat > "$BUILDDIR/ipc.c" << 'EOF'
#include "ipc.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>
#include <fcntl.h>

int ipc_server_init(IPCContext* ctx) {
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
    
    if (listen(ctx->socket_fd, 5) < 0) {
        close(ctx->socket_fd);
        return -1;
    }
    
    int flags = fcntl(ctx->socket_fd, F_GETFL, 0);
    fcntl(ctx->socket_fd, F_SETFL, flags | O_NONBLOCK);
    ctx->client_fd = -1;
    return 0;
}

void ipc_server_cleanup(IPCContext* ctx) {
    if (ctx->client_fd >= 0) close(ctx->client_fd);
    if (ctx->socket_fd >= 0) close(ctx->socket_fd);
    unlink(HIDBOX_SOCKET_PATH);
    ctx->socket_fd = -1;
    ctx->client_fd = -1;
}

int ipc_server_accept(IPCContext* ctx) {
    if (ctx->client_fd >= 0) return ctx->client_fd;
    struct sockaddr_un client_addr;
    socklen_t client_len = sizeof(client_addr);
    ctx->client_fd = accept(ctx->socket_fd, (struct sockaddr*)&client_addr, &client_len);
    if (ctx->client_fd >= 0) {
        int flags = fcntl(ctx->client_fd, F_GETFL, 0);
        fcntl(ctx->client_fd, F_SETFL, flags | O_NONBLOCK);
    }
    return ctx->client_fd;
}

int ipc_server_recv(IPCContext* ctx, char* buf, size_t size) {
    if (ctx->client_fd < 0) return -1;
    int n = recv(ctx->client_fd, buf, size, 0);
    if (n <= 0) {
        close(ctx->client_fd);
        ctx->client_fd = -1;
    }
    return n;
}

int ipc_server_send(IPCContext* ctx, const char* buf, size_t len) {
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

int ipc_client_send(int fd, const char* cmd) {
    return write(fd, cmd, strlen(cmd));
}

int ipc_client_recv(int fd, char* buf, size_t size) {
    return read(fd, buf, size);
}
EOF

#===============================================================================
# Compile static library
#===============================================================================
echo "[INFO] Compiling $LIBNAME..."
cd "$BUILDDIR"
gcc -O2 -march=armv8-a -mtune=cortex-a53 -c ipc.c
ar rcs libhidbox-ipc.a ipc.o
ranlib libhidbox-ipc.a

if [ ! -f "libhidbox-ipc.a" ]; then
    echo "[ERROR] Compilation failed." >&2
    exit 1
fi

#===============================================================================
# Install library and headers
#===============================================================================
echo "[INFO] Installing library to $LIBDIR"
mkdir -p "$LIBDIR"
cp libhidbox-ipc.a "$LIBDIR/"
chmod 644 "$LIBDIR/libhidbox-ipc.a"

echo "[INFO] Installing headers to $INCDIR"
mkdir -p "$INCDIR"
cp ipc.h "$INCDIR/"
chmod 644 "$INCDIR/ipc.h"

#===============================================================================
# Clean up
#===============================================================================
echo "[INFO] Cleaning up temporary build directory"
rm -rf "$BUILDDIR"

#===============================================================================
# Success
#===============================================================================
echo "[OK] HIDBOX IPC library installed successfully."
echo "     Library: $LIBDIR/libhidbox-ipc.a"
echo "     Header: $INCDIR/ipc.h"
exit 0
EOF