/*
 * Thin C shims around SDL2. Window creation stays on the C ABI so FPC
 * does not have to pass six integers through cdecl on aarch64 Darwin.
 */

#include <SDL.h>

int Moire_VideoInit(void)
{
    /* We did not go through SDL_main; without this, some SDL builds
       refuse SDL_Init or create a window that never maps. */
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
