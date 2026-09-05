# How this screensaver works

This note is for an automation tester who wants to see how a small Free Pascal + SDL2 application is structured: where it starts, who owns state, who paints pixels, and how the gratings move.

You do not need to be an SDL (Simple DirectMedia Layer - the cross-C platform library this app uses to open a window, read keys and this mouse, and put the XOR pixel buffer on the screen) expert or a graphics programmer. The same ideas show up in many GUI and game-like apps: an entry point, a model, a view, and a timed loop that updates an angle then redraws.

There is **no 3D engine** and **no Lazarus**. Two sets of lines or circles are drawn with XOR (Exclusive-OR, like the XOR-gate). Where they overlap, pixels flip back to black (or mix colours). That interference *is* the moiré. The only animation state is a single angle that grows each frame.

## Mental model

```
C main()                         # src/main.c — process entry (macOS Cocoa)
  → RunMoire(argc, argv)         # Pascal export in libmoire
      → parse flags
      → LoadConfig (state)
      → either screenshot (no window)
         or RunMoireApp
              → settings chrome + live preview
                 or full-screen shell
                    → DrawMoire (XOR pixels) → SDL texture
```

| Layer | Unit / file | Tester-friendly analogy |
|-------|-------------|-------------------------|
| OS entry | `src/main.c` | Thin trampoline so the process looks like a C SDL app |
| Entry / routing | `moireentry` | Test runner that picks “config” vs “run” from CLI |
| State | `moireconfig` | Test data / fixture that is saved and reloaded |
| Settings + shell | `moireapp` | Form, full-screen host, and the event loop |
| Animation view | `moirerender` | The thing that actually XOR-draws the gratings |

SDL is **event-driven**, but this app uses a **single-thread poll loop** rather than a Swing timer. `SDL_PollEvent`, `AdvanceTime`, `DrawMoire`, and `SDL_RenderPresent` all run on the same thread. That is why there is no worker thread and no `invokeLater`.

---

## 1. Entry point and execution lifecycle

### Where `main` lives

The **process** entry point is C: `src/main.c` `main(int argc, char **argv)`. It only calls `RunMoire`.

`RunMoire` is a `cdecl` export from the Free Pascal library `libmoire`. On macOS the exported symbol is `_RunMoire` so the C linker finds it (Darwin C names get a leading underscore).

A Pascal `program` `main` is **not** used as the OS entry. Homebrew’s `sdl2` is `sdl2-compat` (SDL2 API on top of SDL3). Creating a window from a Pascal-owned `main` crashed here; a C `main` that then calls into Pascal works. The screensaver logic is still Pascal.

`moire.pas` is `library moire`. Its `begin … end` is empty. Unit initialisation runs when the dylib loads.

### Lifecycle, step by step

1. **The OS** starts `bin/moire` at C `main`.
2. **`RunMoire`** stores the C `argc` / `argv` (FPC `ParamStr` would be empty inside a library).
3. **`ParseArgs`** strips `/`, `-`, `--` and maps `s`/`fullscreen`, `c`/`config`, `p`/`preview`, `screenshot`. Last match wins. No args → `CONFIG`.
4. If the mode is `PREVIEW`, `Halt(0)`. The process ends. No window. (Windows Settings preview HWND; this UI does not embed into that native window.)
5. If the mode is `SCREENSHOT`, `DrawMoire` writes a BMP and `Halt(0)`. No SDL window.
6. Otherwise **`LoadConfig`** reads `moire.ini` from the per-user config directory (or defaults).
7. **`RunMoireApp`** initialises SDL, creates one window, and enters the poll loop:
   - `--fullscreen` / `/s` → window already `SDL_WINDOW_FULLSCREEN_DESKTOP`
   - default / `--config` → 780×640 preferences chrome with a live preview well
8. The process stays alive because the `while App.Running` loop does not return until Close, Esc/Q, a click in full screen, or a ~12 px mouse move in full screen.

### Two user journeys

**Settings first** (`./run.sh` or `--config`):

```
RunMoireApp opens a windowed settings view
  → user edits controls or presses 1–4 / arrows / C
  → each change writes TMoireConfig and SaveConfig
  → live preview well already animates (same DrawMoire as full screen)
  → Close / Esc → save → SDL_Quit → process ends
  → Start screensaver / Return → save, same window goes exclusive desktop-full-screen
       → Esc/Q, click, or ~12px mouse move → save → SDL_Quit → process ends
```

**Saver first** (`--fullscreen` / `/s`):

```
RunMoireApp creates the window already full screen
  → cursor hidden, hint overlay for a few seconds
  → pattern keys still work (they do not quit)
  → Esc/Q / click / large mouse move → save → process ends
```

### Why testers care

- **CLI is the feature flag.** Automating “open settings” vs “open saver” is `./bin/moire --config` vs `--fullscreen`.
- **Preferences survive process restarts.** A test that changes density and relaunches should see the same spacing. Storage is `moire.ini` under `GetAppConfigDir(False)`, not a file in the repo.
- **Exit is process-level** (`Halt` / return from `RunMoire` / C `main` returns). There is no “navigate back to a page.”
- **The settings preview is the real renderer.** If rings move in the well, `DrawMoire` will move them full screen. You are not testing a fake stub.
- **`--screenshot FILE.bmp` needs no window.** Useful in CI: the XOR canvas does not depend on SDL.

---

## 2. Main units and responsibilities

This is a **separation of UI vs state**, not a full MVC framework. There is no database and no service layer.

### `src/main.c` — OS composition root

- Owns `main`
- Does **not** parse flags, draw pixels, or touch the INI file

### `moireentry` — Pascal composition root

- Parses argv
- Chooses screenshot vs settings vs full screen
- Does **not** draw gratings or store the current angle

### `moireconfig` — state management

Holds the moiré *look and speed*, not the current rotation angle:

- pattern (`mpRings` … `mpPolygons`)
- line spacing (2–50 px)
- rotation speed (1–40; converted to radians/second by `* 0.08`)
- colour mode (mono, cyan/magenta, neon)

**Load / save:** `TIniFile` on `GetAppConfigDir(False) + 'moire.ini'`. Keys are `pattern`, `spacing`, `speed`, `color` under `[display]`.

**Clamping:** setters and `LoadConfig` run values through `ClampInt` so a hand-edited INI cannot inject out-of-range spacing/speed.

This record is the closest thing to a **model**. It has no SDL handles and no per-frame angle.

### `moireapp` — settings chrome + full-screen shell + loop

- One `TApp` record: window, renderer, pixel buffer, widget hit-rects, `Angle`, `Paused`
- Draws System 7-ish buttons and sliders into the **same** software pixmap as the preview
- Hosts a small `DrawMoire` well as a **live preview** (same procedure as full screen)
- Full screen: hide cursor; Esc/Q / click / 12 px mouse move exit; keys `1`–`4`, arrows, Space, `C` do **not** exit
- Mouse “wake”: first motion is recorded; later motion of 12 pixels or more exits (so the initial cursor warp does not instantly quit)

`moireapp` does **not** implement Bresenham or XOR. It calls `DrawMoire`.

### `moirerender` — XOR canvas + four patterns

- Owns a 32-bit ARGB pixmap (`TPixmap`)
- `XorPlot` / `XorLine` / `XorCircle` / `XorPolygon` — QuickDraw-style XOR
- Four gratings, each two layers
- `DrawMoire` fills black, then dispatches on `Cfg.Pattern`
- Reads config every draw, so a slider change is visible on the next frame

### `bitmapfont` / `sdl2min` / `sdlwrap.c`

- 8×8 VGA glyphs so the UI needs no `SDL_ttf`
- Minimal `cdecl` SDL2 imports (`SDL_QUIT` is named `SDL_EVENT_QUIT` because Pascal is case-insensitive and would clash with `SDL_Quit`)
- C shims for `SDL_Init` + `SDL_CreateWindow` (6-integer ABI stays on the C side)

### What is *not* a unit

There is no `Camera`, `Scene`, or `Mesh`. The “objects” on screen are 1-pixel lines and circles. The only animated number is `App.Angle`.

---

## 3. How the render / animation loop works

This is a **classic game loop on the main thread**, not a Swing timer:

```
while Running do
  PollEvent          // keys, mouse, close
  AdvanceTime        // Angle += speed * dt   (unless paused)
  DrawMoire / DrawSettings
  UpdateTexture + RenderPresent
```

`SDL_RENDERER_PRESENTVSYNC` aims at the display refresh. Movement is **not** “add 0.01 to angle every tick.” It uses **elapsed real time** (`SDL_GetPerformanceCounter`) so rotation stays close to the chosen speed even if a frame is late.

### Update vs draw

| Procedure | Mutates | Draws |
|-----------|---------|-------|
| `AdvanceTime` | `Angle`, `HintLeft` | no |
| `DrawMoire` | nothing in config; pixmap pixels only | yes |
| `HandleHotKey` / sliders | config fields, then `SaveConfig` | no |

A tester debugging “it jumps after a breakpoint” should look at the `0.05` second cap in `AdvanceTime`. A tester debugging “wrong pattern / colour” should look at `DrawMoire`.

### Why not `Thread.sleep` on another thread?

A second thread would have to lock the pixmap and the SDL renderer. The poll loop already waits on vsync. One thread keeps keys and pixels in lockstep.

---

## 4. Pattern math on each frame

`Angle` is radians. Layer A and layer B use **different** functions of `Angle` so they drift. XOR of two similar gratings produces the large-scale bands the eye reads as moiré.

### XOR (the classic Mac look)

```text
pixel = (pixel xor (rgb & 0x00FFFFFF)) | 0xFF000000
```

RGB flips; alpha is forced opaque so the SDL texture stays solid. Two white strokes on black: first stroke → white, overlap → black again. Cyan XOR magenta → yellow in the overlap (CMY-ish).

### Rings (`1`)

Two circle families. Centres wander on ellipses with incommensurate frequencies (`1.0` vs `0.83`, `1.17+π` vs `0.71`) so the pair never quite repeats. Radius walks from `LineSpacing` out past the diagonal.

### Spokes (`2`)

Layer A rotates with `+Angle` from the window centre. Layer B rotates the other way (`-Angle * 1.15`) from a slightly offset origin, and is shifted by half a spoke (`π / Count`) so the two stars do not sit on top of each other.

### Parallel lines (`3`)

One grating at `Angle`, the other at `-Angle * 0.85 + π/2`. Spacing is `LineSpacing`. Lines are longer than the diagonal so the screen stays covered while they rotate.

### Polygons (`4`)

Concentric squares (4 sides) rotating one way, hexagons (6 sides) the other (`-Angle * 1.1 + π/6`). Size steps inward by `LineSpacing`.

### Who updates what

| Value | Updated when | Role |
|-------|----------------|------|
| `Angle` | every frame unless paused | shared phase for both layers |
| `LineSpacing` | Up/Down or density slider | how tight the grating is |
| `RotationSpeed` | Left/Right or speed slider | radians/second = speed × 0.08 |
| `Pattern` / `ColorMode` | keys 1–4 / C or buttons | which `Draw*` and which XOR colours |
| pixmap pixels | every draw | thrown away next frame |

Speed tests: change the Speed slider and the same `Angle += RadiansPerSecond * dt` formula makes both layers drift faster. You are not changing a “step size” constant; you are changing the velocity term on `Angle`.

---

## Quick map of files

```
src/
  main.c             # C main, calls RunMoire
  moire.pas          # library that exports RunMoire
  moireentry.pas     # flags, screenshot, RunMoireApp
  moireconfig.pas    # model + INI
  moireapp.pas       # settings, full screen, poll loop
  moirerender.pas    # XOR pixmap + four patterns
  bitmapfont.pas     # 8×8 UI text
  sdl2min.pas        # SDL2 cdecl imports
  sdlwrap.c          # SDL_Init / CreateWindow shims
```

If you are tracing in a debugger, put breakpoints on `main`, `RunMoire`, `AdvanceTime`, and `DrawMoire`. You will see: **tick grows `Angle` → draw XOR gratings → upload texture**.
