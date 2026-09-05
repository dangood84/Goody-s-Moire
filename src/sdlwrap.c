/*
 * Thin C shims around SDL2. Window creation stays on the SDL2 ABI;
 * macOS app startup is handled separately by sdlrun.c (SDL3 SDL_RunApp).
 */

#include <SDL.h>

int Moire_VideoInit(void)
{
    SDL_SetMainReady();
    return SDL_Init(SDL_INIT_VIDEO);
}

void *Moire_CreateWindow(const char *title, int width, int height, unsigned flags)
{
    return SDL_CreateWindow(title,
        (int)SDL_WINDOWPOS_CENTERED,
        (int)SDL_WINDOWPOS_CENTERED,
        width,
        height,
        (Uint32)flags);
}
