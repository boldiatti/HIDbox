#include "hidbox.h"
#include <SDL2/SDL_image.h>
#include <string.h>
#include <stdio.h>

#ifdef USE_SDL2

bool skin_load(Skin *skin, SDL_Renderer *renderer, const char *base_path, const char *skin_name) {
    memset(skin, 0, sizeof(Skin));
    strncpy(skin->name, skin_name, 63);
    char path[256];

    // Load background
    snprintf(path, sizeof(path), "%s/%s/bg.png", base_path, skin_name);
    SDL_Surface *surf = IMG_Load(path);
    if (surf) {
        skin->bg = SDL_CreateTextureFromSurface(renderer, surf);
        SDL_FreeSurface(surf);
    }

    // Load button images
    const char *btn_files[] = {
        "a", "b", "x", "y", "l1", "r1", "l2", "r2",
        "select", "start", "home", "l3", "r3",
        "dpad_up", "dpad_down", "dpad_left", "dpad_right"
    };
    for (int i = 0; i < 16 && i < 16; i++) {
        snprintf(path, sizeof(path), "%s/%s/btn_%s.png", base_path, skin_name, btn_files[i]);
        surf = IMG_Load(path);
        if (surf) {
            skin->buttons[i] = SDL_CreateTextureFromSurface(renderer, surf);
            SDL_FreeSurface(surf);
        }
    }
    return true;
}

void skin_free(Skin *skin) {
    if (skin->bg) SDL_DestroyTexture(skin->bg);
    for (int i = 0; i < 16; i++) {
        if (skin->buttons[i]) SDL_DestroyTexture(skin->buttons[i]);
    }
    memset(skin, 0, sizeof(Skin));
}

#endif