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

Debian / Raspberry Pi OS: see the Linux section below.

### Windows 10

You need **two** things next to each other: `moire.exe` (you compile this with `fpc`) and **`SDL2.dll`** (you download this; you do not build it).

**1. See whether your FPC is 32- or 64-bit**

```bat
fpc -iTP
```

- `x86_64` → 64-bit compiler → `SDL2-…-win32-x64.zip`
- `i386` → 32-bit compiler → `SDL2-…-win32-x86.zip`

A 2014 Intel MacBook Pro on Boot Camp is a 64-bit PC. The official Windows Free Pascal installer still often ships the **32-bit (`i386`) compiler**. That is normal. Match the DLL to `fpc -iTP`, not to the Mac.

In the SDL zip name, **`win32` means “Windows”**, not “32-bit”:

| Zip name | What it actually is |
|----------|---------------------|
| `SDL2-…-win32-x64.zip` | 64-bit DLL (for `x86_64` FPC) |
| `SDL2-…-win32-x86.zip` | 32-bit DLL (for `i386` FPC) |

If `fpc -iTP` printed `i386` and you already downloaded the **x64** zip, download the **x86** one instead. Easier than installing a 64-bit compiler.

**2. Download `SDL2.dll`**

1. Open the [SDL2 releases](https://github.com/libsdl-org/SDL/releases) page.
2. Download the **runtime** zip (not “Source code”) that matches the table above.
3. Unzip it. Inside is `SDL2.dll`.

**3. Compile the exe**

From the project folder in Command Prompt:

```bat
build-win.bat
```

That runs `fpc` on `src\winmain.pas` and writes `bin\moire.exe`. Then copy `SDL2.dll` into `bin\` (same folder as the exe).

Manual compile if you prefer:

```bat
mkdir bin
fpc -Mobjfpc -Sh -O2 -FEbin -FUbin -Fusrc -obin\moire.exe src\winmain.pas
```

**4. Run**

```bat
bin\moire.exe
bin\moire.exe --fullscreen
```

If Windows says it cannot find `SDL2.dll`, the DLL is missing from `bin\` or it is the wrong bitness (32-bit DLL with a 64-bit exe, or the other way around).

### Linux / Raspberry Pi OS

On Debian, Ubuntu, and Raspberry Pi OS you install **Free Pascal** and **SDL2** from `apt`. The package supplies the matching ARM or x86 library, so there is no separate `SDL2.dll` to download.

**1. Packages**

```bash
sudo apt update
sudo apt install fpc libsdl2-dev build-essential
```

`build-essential` gives you `gcc` and `make`, which the Makefile uses. You want the **desktop** Pi image (or any machine already running X11/Wayland). A Lite/SSH-only session has no window to open.

**2. Compile**

From the project folder:

```bash
make compile
```

or:

```bash
./run.sh
```

That writes `bin/moire` and links it against the system `libSDL2`.

**3. Run**

```bash
./bin/moire
./bin/moire --fullscreen
```

Same keys as on the Mac. If the window never appears over SSH, you are not on a graphical session — run it on the Pi’s desktop, or set `DISPLAY` if you are forwarding X.

32-bit Pi OS (`armhf`) and 64-bit Pi OS (`aarch64`) both work: `apt` installs the SDL2 that matches that OS. Check with `fpc -iTP` if you are curious (`arm` / `aarch64`); you do not pick a zip.

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
  winmain.pas        # Windows / Linux process entry (fpc emits the exe)
  moire.pas          # Free Pascal library exporting RunMoire
  moireentry.pas     # flag parsing and launch
  moireapp.pas       # preferences chrome, full-screen shell, event loop
  moirerender.pas    # XOR pixel canvas + four patterns
  moireconfig.pas    # model + INI load/save
  bitmapfont.pas     # 8×8 UI text (no SDL_ttf)
  sdl2min.pas        # small SDL2 cdecl import set
  sdlwrap.c          # SDL_Init / CreateWindow shims
```
