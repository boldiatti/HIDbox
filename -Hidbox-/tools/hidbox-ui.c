#include "hidbox.h"
#include <SDL2/SDL.h>
#include <stdio.h>
#include <unistd.h>

#define WINDOW_WIDTH 640
#define WINDOW_HEIGHT 480

int main(int argc, char **argv) {
    (void)argc; (void)argv;

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        fprintf(stderr, "SDL init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window *win = SDL_CreateWindow("HIDBOX Controller",
                                       SDL_WINDOWPOS_UNDEFINED,
                                       SDL_WINDOWPOS_UNDEFINED,
                                       WINDOW_WIDTH, WINDOW_HEIGHT,
                                       SDL_WINDOW_SHOWN);
    if (!win) {
        fprintf(stderr, "Window creation failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!ren) {
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    // Connect to daemon IPC
    int ipc_fd = ipc_client_connect();
    if (ipc_fd < 0) {
        fprintf(stderr, "Warning: Could not connect to hidboxd IPC.\n");
    }

    SDL_Event e;
    int running = 1;
    while (running) {
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT)
                running = 0;
        }

        // Request state from daemon (optional)
        if (ipc_fd >= 0) {
            ipc_client_send(ipc_fd, "{\"command\":\"get_info\"}");
            char buf[512];
            int n = ipc_client_recv(ipc_fd, buf, sizeof(buf)-1);
            if (n > 0) {
                buf[n] = 0;
                // Parse and update display (simplified – ignore)
            }
        }

        // Clear screen
        SDL_SetRenderDrawColor(ren, 26, 26, 46, 255);
        SDL_RenderClear(ren);

        // Draw a simple representation (e.g., a rectangle for each button)
        SDL_SetRenderDrawColor(ren, 255, 255, 255, 255);
        SDL_Rect rect = {100, 100, 50, 50};
        SDL_RenderFillRect(ren, &rect);

        SDL_RenderPresent(ren);
        SDL_Delay(16);
    }

    if (ipc_fd >= 0) close(ipc_fd);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}