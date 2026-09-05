/*
 * Process entry. A C main lets macOS / sdl2-compat start Cocoa the same
 * way a plain C SDL program does. The screensaver itself is Free Pascal.
 */

void RunMoire(int argc, char **argv);

int main(int argc, char **argv)
{
    /* Pascal must not own main on this Homebrew SDL: CreateWindow crashed
       from a Free Pascal program entry, but works when C starts the process. */
    RunMoire(argc, argv);
    return 0;
}
