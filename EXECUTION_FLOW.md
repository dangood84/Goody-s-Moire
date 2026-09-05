# Execution flow: from `main` to a drawn frame

A step-by-step trace of what happens from C `main` through library load and the SDL poll loop, down to how individual frames are calculated and drawn.

Default launch (`./run.sh`) opens settings; `--fullscreen` skips the chrome. The moiré itself is the same either way: `DrawMoire` XOR-fills a pixmap, then SDL uploads it as a streaming texture.

One thread does everything after startup:

- **main (C, then Pascal)** — flags, config, window, events, update, draw, present

There is no Swing EDT. `SDL_PollEvent` and `SDL_RenderPresent` run on the same thread that called `RunMoire`.

---

## Phase A — process entry (C, then the Pascal export)

1. The OS loads `bin/moire`. Dynamic linker loads `libmoire.dylib` (or `.so`). FPC unit `initialization` sections run (none of ours do extra work).
2. C `main` in `src/main.c` calls `RunMoire(argc, argv)`.
3. On Darwin the symbol is `_RunMoire`. That leading underscore is why `moireentry.pas` uses `public name '_RunMoire'` only in `{$ifdef DARWIN}`.
4. `RunMoire` copies the C argv into unit variables. A Pascal library does not get `ParamStr` filled the way a `program` does.

```c
int main(int argc, char **argv)
{
    RunMoire(argc, argv);
    return 0;
}
```

```pascal
procedure RunMoire(CArgc: LongInt; CArgv: PPChar); cdecl;
begin
  Argc := CArgc;
  Argv := CArgv;
  ParseArgs;
  …
end;
```

---

## Phase B — flags, then which path

5. `ParseArgs` walks argv from index 1. `StripPrefix` peels `--`, `-`, or `/` so Windows `.scr` flags and Unix flags share one parser. Last matching flag wins (`app /c /s` is full screen).
6. `/c` and `--config` use “starts with `c`” so Windows `/c:HWND` still opens preferences.
7. Mode switch:
   - `PREVIEW` (`/p`, `--preview`) → `Halt(0)`. No window.
   - `SCREENSHOT` → `DrawMoire` into a 960×540 pixmap, `WritePixmapBMP`, `Halt(0)`.
   - otherwise `Cfg := LoadConfig` then `RunMoireApp(Cfg, Mode = lmFullScreen)`.

```pascal
Stripped := StripPrefix(Raw);
if (LowerCase(Stripped) = 's') or (LowerCase(Stripped) = 'fullscreen') then
  Mode := lmFullScreen
else if (LowerCase(Copy(Stripped, 1, 1)) = 'c') or (LowerCase(Stripped) = 'config') then
  Mode := lmConfig
```

`LoadConfig` starts from `DefaultConfig` (rings, spacing 8, speed 12, mono), overlays INI integers, then clamps. A missing file still looks designed.

**Start screensaver** from the dialog does **not** create a second process. It calls `EnterFullScreen` on the same window (`SDL_WINDOW_FULLSCREEN_DESKTOP`), hides the cursor, and zeros `PixW/PixH` so the next `EnsureBuffers` rebuilds the pixmap at native resolution.

---

## Phase C — screen initialisation (`RunMoireApp`)

8. `FillChar(App, …)` then copy `Cfg` in. `LayoutWidgets` stores hit-rects in **logical** 780×640 space.
9. `Moire_VideoInit` (C): `SDL_SetMainReady` then `SDL_Init(SDL_INIT_VIDEO)`. `SetMainReady` tells SDL we did not go through `SDL_main`.
10. Window flags: `SHOWN | ALLOW_HIGHDPI`, plus `FULLSCREEN_DESKTOP` if this launch is `/s`.
11. `Moire_CreateWindow` (C) uses `SDL_WINDOWPOS_CENTERED` and the logical size. C owns the 6-argument `SDL_CreateWindow` ABI.
12. Renderer: accelerated + vsync. Full-screen path also `SDL_ShowCursor(SDL_DISABLE)`.

```pascal
if Moire_VideoInit <> 0 then
  FailSDL('SDL_Init');
Flags := SDL_WINDOW_SHOWN or SDL_WINDOW_ALLOW_HIGHDPI;
if StartFullScreen then
  Flags := Flags or SDL_WINDOW_FULLSCREEN_DESKTOP;
App.Window := Moire_CreateWindow(…, LogicalW, LogicalH, Flags);
App.Renderer := SDL_CreateRenderer(App.Window, -1,
  SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);
```

13. First loop iteration: `EnsureBuffers` asks `SDL_GetRendererOutputSize` (Retina pixels, not points). Settings chrome uses `Scale = outputW / 780` so the 8×8 font and hit-rects grow on a 2× display. Full screen uses `Scale = 1` and draws moiré at native pixels.

---

## Phase D — the repeating loop

Every vsync the same thread does **events**, then **update**, then **draw**.

```
while Running
  → PollEvent / HandleEvent
  → EnsureBuffers          // recreate pixmap if the drawable size changed
  → AdvanceTime            // Angle += ω * dt
  → DrawSettings or DrawFullScreen
  → UpdateTexture + RenderPresent
```

There is no `repaint()` / `paintComponent` split. `DrawMoire` writes the pixmap immediately; `PresentFrame` uploads it.

---

## Phase E — first tick (baseline, no motion)

14. `AdvanceTime` sees `HasLastCounter = false`, stores `SDL_GetPerformanceCounter`, and **returns**. No angle change. The first delta must not be “since process start.”
15. Draw still happens: you see a static frame at `Angle = 0` (or whatever is left from a previous session in the same process — on a fresh launch it is 0).
16. Second tick computes `dt = (now - last) / freq`, caps at `0.05` seconds so a breakpoint does not fling the gratings, then:

```text
Angle = Angle + (RotationSpeed * 0.08) * dt
```

Speed 12 → `0.96` rad/s. A 16.7 ms frame → about `0.016` radians.

---

## Phase F — first draw (`DrawMoire` / settings well)

17. Settings: fill platinum gray, draw labels/buttons/sliders, bevel a well, `DrawMoire` into a temporary pixmap the size of the well, blit it into the frame.
18. Full screen: `DrawMoire` straight into the frame pixmap.
19. `DrawMoire`:
    1. Fill black (`$FF000000`).
    2. `case Cfg.Pattern` → rings / spokes / lines / polygons.
    3. Each pattern strokes **two** layers with `XorPlot`.
20. `PresentFrame`: `SDL_UpdateTexture` (pitch = width × 4), `RenderCopy` full texture, `RenderPresent`.

```pascal
procedure DrawMoire(var Pm: TPixmap; const Cfg: TMoireConfig; Angle: Double);
begin
  PixmapFill(Pm, ColorBlack);
  case Cfg.Pattern of
    mpSpokes: DrawSpokes(Pm, Cfg, Angle);
    mpParallelLines: DrawParallelLines(Pm, Cfg, Angle);
    mpPolygons: DrawPolygons(Pm, Cfg, Angle);
  else
    DrawRings(Pm, Cfg, Angle);
  end;
end;
```

XOR pixel (rings example): two wandering centres, circles every `LineSpacing` pixels, out to the diagonal plus wander amplitude so the disk always covers the corners.

```pascal
C1X := CX + Round(Cos(Angle) * Amp);
C1Y := CY + Round(Sin(Angle * 0.83) * Amp);
C2X := CX + Round(Cos(Angle * 1.17 + Pi) * Amp);
C2Y := CY + Round(Sin(Angle * 0.71) * Amp);
```

The incommensurate multipliers keep the pair from looping on a short period.

---

## Phase G — every later tick (this is “a frame”)

21. **Events.** In settings, clicks write the config and `SaveConfig` immediately (no Apply). In full screen, `1`–`4` / arrows / Space / `C` change the look; Esc, Q, click, or a 12 px move after the **first** motion sample quit. The first sample is ignored because entering exclusive mode often synthesizes a motion event.
22. **Update.** `dt` capped; `Angle` grows unless `Paused`.
23. **Draw.** Same as phase F, with the new `Angle`. Hint overlay in full screen fades after `HintSeconds`.
24. **Present.** Vsync blocks until the next refresh.

That triple (21–23) repeats until `Running` is false.

---

## Phase H — shutdown

25. Close box, Esc in settings, or full-screen dismiss → `Running := False` after `SaveConfig` so the last keyboard tweak is still there on the next launch.
26. `finally`: destroy texture and pixmap, destroy renderer and window, `SDL_Quit`.
27. `RunMoire` returns to C `main`, which returns 0. `Halt` is used only for `--preview`, `--screenshot`, `--help`, and fatal SDL errors.

```pascal
if (Key = SDLK_ESCAPE) or (Key = SDLK_q) then
begin
  Persist(App);
  App.Running := False;
end
```

---

## One-line map

`C main` → `RunMoire` → load INI → `RunMoireApp` → poll loop → **`AdvanceTime` grows `Angle`** → **`DrawMoire` XOR-draws two gratings** → **upload texture**.

Debugger: `main` in `src/main.c`, `RunMoire`, `AdvanceTime`, `DrawMoire` / `XorPlot`. First `AdvanceTime` only stamps time; motion starts on the second tick.

See also `WORKINGS.md` for unit responsibilities and the pattern math in more detail.
