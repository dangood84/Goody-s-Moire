/*
 * Process entry. A C main lets macOS / sdl2-compat start Cocoa the same
 * way a plain C SDL program does. The screensaver itself is Free Pascal.
 */

void RunMoire(int argc, char **argv);

int main(int argc, char **argv)
{
    RunMoire(argc, argv);
    return 0;
}
