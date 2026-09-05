# Goody's Moiré

A standalone tribute to the classic Mac OS **Moiré** cdev / After Dark-style screensaver: two overlapping gratings, XOR’d together so the interference ripples as they rotate.

Written in **Free Pascal** and drawn into a software canvas presented with **SDL2**. Lazarus and Delphi are not used — `fpc` plus an SDL2 library is enough (the same setup you already use in Cursor / VS Code). `make` also runs the C compiler for a 10-line `main` so macOS Cocoa starts; the screensaver itself is Pascal.

Preferences (pattern, line density, rotation speed, colour) are saved to an INI file in the usual per-user config directory and restored on the next launch.

## Requirements

- **Free Pascal** 3.2+ (`fpc` on your `PATH`)
- **SDL2** development library (`sdl2-config` is used by the Makefile)

macOS (Homebrew):

```bash
brew install fpc sdl2
```

Debian / Raspberry Pi OS:

```bash
sudo apt install fpc libsdl2-dev
```

Windows: install FPC and place `SDL2.dll` next to the built `moire.exe` (or on `PATH`).

## Run

From the project root:

```bash
./run.sh
```

That compiles to `bin/` if needed and opens the preferences window. You can also pass flags through:

```bash
./run.sh --config
./run.sh --fullscreen
./run.sh /s
```

Or with Make:

```bash
make config        # preferences window
make screensaver   # full-screen saver
make screenshot    # one 960×540 BMP of the saved look
make clean         # remove bin/
```

Manual compile:

```bash
make compile
./bin/moire --config
```

## Command-line flags

| Flag | Action |
|------|--------|
| *(none)*, `/c`, `--config` | Open the preferences window |
| `/s`, `--fullscreen` | Start the full-screen screensaver immediately |
| `/p`, `--preview` | No-op (Windows-style preview hook); exits without a window |
| `--screenshot FILE.bmp` | Draw one frame with the saved settings and exit (no SDL window) |

Settings from the window are persisted, so `--fullscreen` uses the last saved look.

## Using it

1. Pick a pattern, density, speed, and colour. The well is the same XOR renderer as full screen.
2. Click **Start screensaver** (or launch with `--fullscreen`). Return also starts it from preferences.
3. In full screen, **Esc** or **Q**, a click, or a mouse move of about 12 pixels exits.

The original Mac module let you play with the gratings from the keyboard. Those keys work in both the preview and full screen:

| Key | Action |
|-----|--------|
| `1` | Concentric rings (two wandering origins) |
| `2` | Radial spokes (two layers, opposite rotation) |
| `3` | Parallel line grids (set B rotated against set A) |
| `4` | Nested squares and hexagons |
| Up / Down | Denser or looser line spacing |
| Left / Right | Slower or faster rotation |
| Space | Pause / freeze |
| `C` | Cycle Mono, Cyan/Magenta, Neon Green |

How the pieces fit together (same style as the Java savers): `WORKINGS.md` for responsibilities and XOR math, `EXECUTION_FLOW.md` for a frame-by-frame trace.

## Project layout

```
src/
  main.c             # process entry (so macOS windowing starts cleanly)
  moire.pas          # Free Pascal library exporting RunMoire
  moireentry.pas     # flag parsing and launch
  moireapp.pas       # preferences chrome, full-screen shell, event loop
  moirerender.pas    # XOR pixel canvas + four patterns
  moireconfig.pas    # model + INI load/save
  bitmapfont.pas     # 8×8 UI text (no SDL_ttf)
  sdl2min.pas        # small SDL2 cdecl import set
  sdlwrap.c          # SDL_Init / CreateWindow shims
```
