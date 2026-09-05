unit moireapp;

{$mode objfpc}{$H+}

{ Settings window and full-screen shell. Both share one XOR renderer. }

interface

uses
  moireconfig;

procedure RunMoireApp(var Cfg: TMoireConfig; StartFullScreen: Boolean);

implementation

uses
  SysUtils, bitmapfont, moirerender, sdl2min;

const
  LogicalW = 780;
  LogicalH = 640;
  MouseExitPixels = 12;
  HintSeconds = 5.0;

  FaceGray = $FFD4D4D4;
  WindowGray = $FFC8C8C8;
  TextBlack = $FF111111;
  TextDim = $FF555555;
  WellBlack = $FF000000;
  Accent = $FF2222AA;

type
  TRectI = record
    X, Y, W, H: Integer;
  end;

  TDragKind = (dkNone, dkSpacing, dkSpeed);

  TApp = record
    Cfg: TMoireConfig;
    Window: PSDL_Window;
    Renderer: PSDL_Renderer;
    Texture: PSDL_Texture;
    Frame: TPixmap;
    WinW, WinH, PixW, PixH: Integer;
    Scale: Integer;
    FullScreen: Boolean;
    Running: Boolean;
    Angle: Double;
    Paused: Boolean;
    LastCounter: QWord;
    HasLastCounter: Boolean;
    FirstMouse: Boolean;
    FirstMX, FirstMY: Integer;
    Drag: TDragKind;
    HintLeft: Double;
    BtnRings, BtnSpokes, BtnLines, BtnPolygons: TRectI;
    SliderSpacing, SliderSpeed: TRectI;
    BtnMono, BtnCyan, BtnNeon: TRectI;
    Preview: TRectI;
    BtnClose, BtnStart: TRectI;
  end;

function RectI(X, Y, W, H: Integer): TRectI;
begin
  Result.X := X;
  Result.Y := Y;
  Result.W := W;
  Result.H := H;
end;

function Hit(const R: TRectI; X, Y: Integer): Boolean;
begin
  Result := (X >= R.X) and (Y >= R.Y) and (X < R.X + R.W) and (Y < R.Y + R.H);
end;

function Sx(const App: TApp; Logical: Integer): Integer;
begin
  Result := Logical * App.Scale;
end;

procedure LayoutWidgets(var App: TApp);
var
  Y: Integer;
begin
  Y := 20;
  App.BtnRings := RectI(160, Y + 44, 88, 26);
  App.BtnSpokes := RectI(256, Y + 44, 88, 26);
  App.BtnLines := RectI(352, Y + 44, 88, 26);
  App.BtnPolygons := RectI(448, Y + 44, 100, 26);
  App.SliderSpacing := RectI(160, Y + 86, 420, 22);
  App.SliderSpeed := RectI(160, Y + 126, 420, 22);
  App.BtnMono := RectI(160, Y + 166, 72, 26);
  App.BtnCyan := RectI(240, Y + 166, 120, 26);
  App.BtnNeon := RectI(368, Y + 166, 110, 26);
  App.Preview := RectI(20, Y + 208, 740, 250);
  App.BtnClose := RectI(496, 596, 88, 28);
  App.BtnStart := RectI(592, 596, 168, 28);
end;

procedure Persist(var App: TApp);
begin
  SaveConfig(App.Cfg);
end;

procedure HandleHotKey(var App: TApp; Key: LongInt);
begin
  case Key of
    SDLK_1:
      SetPattern(App.Cfg, mpRings);
    SDLK_2:
      SetPattern(App.Cfg, mpSpokes);
    SDLK_3:
      SetPattern(App.Cfg, mpParallelLines);
    SDLK_4:
      SetPattern(App.Cfg, mpPolygons);
    SDLK_UP:
      SetLineSpacing(App.Cfg, App.Cfg.LineSpacing - 1);
    SDLK_DOWN:
      SetLineSpacing(App.Cfg, App.Cfg.LineSpacing + 1);
    SDLK_LEFT:
      SetRotationSpeed(App.Cfg, App.Cfg.RotationSpeed - 1);
    SDLK_RIGHT:
      SetRotationSpeed(App.Cfg, App.Cfg.RotationSpeed + 1);
    SDLK_SPACE:
      App.Paused := not App.Paused;
    SDLK_c:
      CycleColorMode(App.Cfg);
  else
    Exit;
  end;
  Persist(App);
end;

procedure FailSDL(const Step: string);
begin
  raise Exception.Create(Step + ': ' + string(SDL_GetError));
end;

procedure DestroyTexture(var App: TApp);
begin
  if App.Texture <> nil then
  begin
    SDL_DestroyTexture(App.Texture);
    App.Texture := nil;
  end;
  PixmapFree(App.Frame);
end;

procedure EnsureBuffers(var App: TApp);
var
  OutW, OutH: LongInt;
begin
  if SDL_GetRendererOutputSize(App.Renderer, @OutW, @OutH) <> 0 then
    FailSDL('SDL_GetRendererOutputSize');
  SDL_GetWindowSize(App.Window, @App.WinW, @App.WinH);
  if App.WinW < 1 then
    App.WinW := 1;
  if App.WinH < 1 then
    App.WinH := 1;
  if OutW < 1 then
    OutW := App.WinW;
  if OutH < 1 then
    OutH := App.WinH;
  if (OutW = App.PixW) and (OutH = App.PixH) and (App.Frame.Pixels <> nil) then
    Exit;
  DestroyTexture(App);
  App.PixW := OutW;
  App.PixH := OutH;
  if App.FullScreen then
    App.Scale := 1
  else
  begin
    App.Scale := OutW div LogicalW;
    if App.Scale < 1 then
      App.Scale := 1;
  end;
  PixmapAlloc(App.Frame, OutW, OutH);
  App.Texture := SDL_CreateTexture(App.Renderer, SDL_PIXELFORMAT_ARGB8888,
    SDL_TEXTUREACCESS_STREAMING, OutW, OutH);
  if App.Texture = nil then
    FailSDL('SDL_CreateTexture');
end;

procedure EnterFullScreen(var App: TApp);
begin
  if SDL_SetWindowFullscreen(App.Window, SDL_WINDOW_FULLSCREEN_DESKTOP) <> 0 then
    FailSDL('SDL_SetWindowFullscreen');
  SDL_ShowCursor(SDL_DISABLE);
  App.FullScreen := True;
  App.FirstMouse := False;
  App.HintLeft := HintSeconds;
  App.PixW := 0;
  App.PixH := 0;
end;

procedure DrawButton(var App: TApp; const R: TRectI; const Caption: string; Selected: Boolean);
var
  X, Y, W, H, TX, TY: Integer;
  Face: LongWord;
begin
  X := Sx(App, R.X);
  Y := Sx(App, R.Y);
  W := Sx(App, R.W);
  H := Sx(App, R.H);
  if Selected then
    Face := $FFB8B8E0
  else
    Face := FaceGray;
  PixmapBevel(App.Frame, X, Y, W, H, not Selected, Face);
  TX := X + (W - TextWidth(Caption, App.Scale)) div 2;
  TY := Y + (H - TextHeight(App.Scale)) div 2;
  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height, TX, TY, Caption, TextBlack, App.Scale);
end;

procedure DrawSlider(var App: TApp; const R: TRectI; Value, Lo, Hi: Integer; const LabelText, ValueText: string);
var
  X, Y, W, H, TrackY, ThumbX, Span: Integer;
begin
  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
    Sx(App, 20), Sx(App, R.Y + 6), LabelText, TextBlack, App.Scale);
  X := Sx(App, R.X);
  Y := Sx(App, R.Y);
  W := Sx(App, R.W);
  H := Sx(App, R.H);
  TrackY := Y + H div 2;
  PixmapFillRect(App.Frame, X, TrackY - App.Scale, W, App.Scale * 3, $FF888888);
  Span := Hi - Lo;
  if Span < 1 then
    Span := 1;
  ThumbX := X + ((Value - Lo) * (W - Sx(App, 10))) div Span;
  PixmapBevel(App.Frame, ThumbX, Y, Sx(App, 10), H, True, FaceGray);
  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
    X + W + Sx(App, 12), Sx(App, R.Y + 6), ValueText, TextDim, App.Scale);
end;

function SliderValueAt(const R: TRectI; X, Lo, Hi: Integer): Integer;
var
  Span, Rel, Width: Integer;
begin
  Span := Hi - Lo;
  Rel := X - R.X;
  if Rel < 0 then
    Rel := 0;
  if Rel > R.W then
    Rel := R.W;
  Width := R.W;
  if Width < 1 then
    Width := 1;
  Result := Lo + (Rel * Span) div Width;
  if Result < Lo then
    Result := Lo;
  if Result > Hi then
    Result := Hi;
end;

procedure DrawSettings(var App: TApp);
var
  PreviewBuf: TPixmap;
  Row, Col, SrcX, SrcY, DestX, DestY, PW, PH: Integer;
  Hint1, Hint2: string;
begin
  PixmapFill(App.Frame, WindowGray);
  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
    Sx(App, 20), Sx(App, 18), 'Preferences & Settings', TextBlack, App.Scale * 2);
  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
    Sx(App, 20), Sx(App, 42), 'Saved automatically  /c config  /s fullscreen  Free Pascal', TextDim, App.Scale);

  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
    Sx(App, 20), Sx(App, App.BtnRings.Y + 8), 'Pattern', TextBlack, App.Scale);
  DrawButton(App, App.BtnRings, 'Rings', App.Cfg.Pattern = mpRings);
  DrawButton(App, App.BtnSpokes, 'Spokes', App.Cfg.Pattern = mpSpokes);
  DrawButton(App, App.BtnLines, 'Lines', App.Cfg.Pattern = mpParallelLines);
  DrawButton(App, App.BtnPolygons, 'Polygons', App.Cfg.Pattern = mpPolygons);

  DrawSlider(App, App.SliderSpacing, App.Cfg.LineSpacing, MinSpacing, MaxSpacing,
    'Density', IntToStr(App.Cfg.LineSpacing) + ' px');
  DrawSlider(App, App.SliderSpeed, App.Cfg.RotationSpeed, MinSpeed, MaxSpeed,
    'Speed', IntToStr(App.Cfg.RotationSpeed));

  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
    Sx(App, 20), Sx(App, App.BtnMono.Y + 8), 'Color', TextBlack, App.Scale);
  DrawButton(App, App.BtnMono, 'Mono', App.Cfg.ColorMode = cmMono);
  DrawButton(App, App.BtnCyan, 'Cyan/Magenta', App.Cfg.ColorMode = cmCyanMagenta);
  DrawButton(App, App.BtnNeon, 'Neon Green', App.Cfg.ColorMode = cmNeon);

  DestX := Sx(App, App.Preview.X);
  DestY := Sx(App, App.Preview.Y);
  PW := Sx(App, App.Preview.W);
  PH := Sx(App, App.Preview.H);
  PixmapBevel(App.Frame, DestX, DestY, PW, PH, False, $FF888888);
  Inc(DestX, App.Scale * 4);
  Inc(DestY, App.Scale * 4);
  Dec(PW, App.Scale * 8);
  Dec(PH, App.Scale * 8);
  PreviewBuf.Pixels := nil;
  PixmapAlloc(PreviewBuf, PW, PH);
  try
    DrawMoire(PreviewBuf, App.Cfg, App.Angle);
    for Row := 0 to PH - 1 do
      for Col := 0 to PW - 1 do
      begin
        SrcX := Col;
        SrcY := Row;
        App.Frame.Pixels[(DestY + SrcY) * App.Frame.Width + (DestX + SrcX)] :=
          PreviewBuf.Pixels[SrcY * PW + SrcX];
      end;
  finally
    PixmapFree(PreviewBuf);
  end;

  Hint1 := '1-4 patterns   arrows density/speed   space pause   C color';
  Hint2 := 'In full screen, Esc/Q or a significant mouse move exits.';
  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
    Sx(App, 20), Sx(App, 486), Hint1, TextDim, App.Scale);
  DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
    Sx(App, 20), Sx(App, 504), Hint2, TextDim, App.Scale);
  if App.Paused then
    DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
      Sx(App, 20), Sx(App, 522), 'PAUSED', Accent, App.Scale);

  DrawButton(App, App.BtnClose, 'Close', False);
  DrawButton(App, App.BtnStart, 'Start screensaver', False);
end;

procedure DrawFullScreen(var App: TApp);
var
  Overlay: string;
  Alpha: Integer;
  Color: LongWord;
begin
  DrawMoire(App.Frame, App.Cfg, App.Angle);
  if App.Paused then
    DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
      16, 16, 'PAUSED', ColorWhite, 2);
  if App.HintLeft > 0 then
  begin
    if App.HintLeft > 1 then
      Alpha := 255
    else
      Alpha := Round(255 * App.HintLeft);
    Color := $FF000000 or (LongWord(Alpha) shl 16) or (LongWord(Alpha) shl 8) or LongWord(Alpha);
    Overlay := '1-4 patterns  arrows density/speed  space pause  C color  Esc quit';
    DrawText(App.Frame.Pixels, App.Frame.Width, App.Frame.Height,
      16, App.Frame.Height - 28, Overlay, Color, 1);
  end;
end;

procedure PresentFrame(var App: TApp);
begin
  if SDL_UpdateTexture(App.Texture, nil, App.Frame.Pixels, App.Frame.Width * SizeOf(LongWord)) <> 0 then
    FailSDL('SDL_UpdateTexture');
  SDL_RenderClear(App.Renderer);
  SDL_RenderCopy(App.Renderer, App.Texture, nil, nil);
  SDL_RenderPresent(App.Renderer);
end;

procedure LogicalMouse(const App: TApp; WinX, WinY: Integer; out LX, LY: Integer);
begin
  if App.WinW <= 0 then
    LX := WinX
  else
    LX := (WinX * LogicalW) div App.WinW;
  if App.WinH <= 0 then
    LY := WinY
  else
    LY := (WinY * LogicalH) div App.WinH;
end;

procedure ClickSettings(var App: TApp; LX, LY: Integer);
begin
  if Hit(App.BtnRings, LX, LY) then
    SetPattern(App.Cfg, mpRings)
  else if Hit(App.BtnSpokes, LX, LY) then
    SetPattern(App.Cfg, mpSpokes)
  else if Hit(App.BtnLines, LX, LY) then
    SetPattern(App.Cfg, mpParallelLines)
  else if Hit(App.BtnPolygons, LX, LY) then
    SetPattern(App.Cfg, mpPolygons)
  else if Hit(App.BtnMono, LX, LY) then
    SetColorMode(App.Cfg, cmMono)
  else if Hit(App.BtnCyan, LX, LY) then
    SetColorMode(App.Cfg, cmCyanMagenta)
  else if Hit(App.BtnNeon, LX, LY) then
    SetColorMode(App.Cfg, cmNeon)
  else if Hit(App.SliderSpacing, LX, LY) then
  begin
    App.Drag := dkSpacing;
    SetLineSpacing(App.Cfg, SliderValueAt(App.SliderSpacing, LX, MinSpacing, MaxSpacing));
  end
  else if Hit(App.SliderSpeed, LX, LY) then
  begin
    App.Drag := dkSpeed;
    SetRotationSpeed(App.Cfg, SliderValueAt(App.SliderSpeed, LX, MinSpeed, MaxSpeed));
  end
  else if Hit(App.BtnClose, LX, LY) then
  begin
    Persist(App);
    App.Running := False;
    Exit;
  end
  else if Hit(App.BtnStart, LX, LY) then
  begin
    Persist(App);
    EnterFullScreen(App);
    Exit;
  end
  else
    Exit;
  Persist(App);
end;

procedure DragSettings(var App: TApp; LX, LY: Integer);
begin
  case App.Drag of
    dkSpacing:
    begin
      SetLineSpacing(App.Cfg, SliderValueAt(App.SliderSpacing, LX, MinSpacing, MaxSpacing));
      Persist(App);
    end;
    dkSpeed:
    begin
      SetRotationSpeed(App.Cfg, SliderValueAt(App.SliderSpeed, LX, MinSpeed, MaxSpeed));
      Persist(App);
    end;
  end;
end;

function IsPatternKey(Key: LongInt): Boolean;
begin
  case Key of
    SDLK_1, SDLK_2, SDLK_3, SDLK_4,
    SDLK_UP, SDLK_DOWN, SDLK_LEFT, SDLK_RIGHT,
    SDLK_SPACE, SDLK_c:
      Result := True;
  else
    Result := False;
  end;
end;

procedure HandleEvent(var App: TApp; const Ev: TSDL_Event);
var
  LX, LY: Integer;
  Key: LongInt;
begin
  case Ev.eventtype of
    SDL_EVENT_QUIT:
      App.Running := False;
    SDL_WINDOWEVENT:
      if Ev.window.event = SDL_WINDOWEVENT_CLOSE then
        App.Running := False;
    SDL_KEYDOWN:
    begin
      Key := Ev.key.keysym.sym;
      if App.FullScreen then
      begin
        if (Key = SDLK_ESCAPE) or (Key = SDLK_q) then
        begin
          Persist(App);
          App.Running := False;
        end
        else if IsPatternKey(Key) then
        begin
          HandleHotKey(App, Key);
          App.HintLeft := HintSeconds;
        end
        else
          App.HintLeft := HintSeconds;
      end
      else
      begin
        if Key = SDLK_ESCAPE then
        begin
          Persist(App);
          App.Running := False;
        end
        else if (Key = SDLK_RETURN) then
        begin
          Persist(App);
          EnterFullScreen(App);
        end
        else
          HandleHotKey(App, Key);
      end;
    end;
    SDL_MOUSEBUTTONDOWN:
      if Ev.button.button = SDL_BUTTON_LEFT then
      begin
        if App.FullScreen then
        begin
          Persist(App);
          App.Running := False;
        end
        else
        begin
          LogicalMouse(App, Ev.button.x, Ev.button.y, LX, LY);
          ClickSettings(App, LX, LY);
        end;
      end;
    SDL_MOUSEBUTTONUP:
      App.Drag := dkNone;
    SDL_MOUSEMOTION:
      if App.FullScreen then
      begin
        if not App.FirstMouse then
        begin
          App.FirstMouse := True;
          App.FirstMX := Ev.motion.x;
          App.FirstMY := Ev.motion.y;
        end
        else if (Abs(Ev.motion.x - App.FirstMX) >= MouseExitPixels) or
          (Abs(Ev.motion.y - App.FirstMY) >= MouseExitPixels) then
        begin
          Persist(App);
          App.Running := False;
        end;
      end
      else if App.Drag <> dkNone then
      begin
        LogicalMouse(App, Ev.motion.x, Ev.motion.y, LX, LY);
        DragSettings(App, LX, LY);
      end;
  end;
end;

procedure AdvanceTime(var App: TApp);
var
  Now: QWord;
  Freq: QWord;
  Dt: Double;
begin
  Now := SDL_GetPerformanceCounter;
  Freq := SDL_GetPerformanceFrequency;
  if (not App.HasLastCounter) or (Freq = 0) then
  begin
    App.LastCounter := Now;
    App.HasLastCounter := True;
    Exit;
  end;
  Dt := (Now - App.LastCounter) / Freq;
  App.LastCounter := Now;
  if Dt > 0.05 then
    Dt := 0.05;
  if not App.Paused then
    App.Angle := App.Angle + RadiansPerSecond(App.Cfg.RotationSpeed) * Dt;
  if App.HintLeft > 0 then
  begin
    App.HintLeft := App.HintLeft - Dt;
    if App.HintLeft < 0 then
      App.HintLeft := 0;
  end;
end;

procedure RunMoireApp(var Cfg: TMoireConfig; StartFullScreen: Boolean);
var
  App: TApp;
  Ev: TSDL_Event;
  Flags: LongWord;
begin
  FillChar(App, SizeOf(App), 0);
  App.Cfg := Cfg;
  App.Running := True;
  App.FullScreen := StartFullScreen;
  App.HintLeft := HintSeconds;
  LayoutWidgets(App);

  if Moire_VideoInit <> 0 then
    FailSDL('SDL_Init');
  try
    Flags := SDL_WINDOW_SHOWN or SDL_WINDOW_ALLOW_HIGHDPI;
    if StartFullScreen then
      Flags := Flags or SDL_WINDOW_FULLSCREEN_DESKTOP;
    App.Window := Moire_CreateWindow(PAnsiChar('Goody''s Moire'), LogicalW, LogicalH, Flags);
    if App.Window = nil then
      FailSDL('SDL_CreateWindow');
    App.Renderer := SDL_CreateRenderer(App.Window, -1,
      SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);
    if App.Renderer = nil then
      FailSDL('SDL_CreateRenderer');
    if StartFullScreen then
      SDL_ShowCursor(SDL_DISABLE);

    while App.Running do
    begin
      while SDL_PollEvent(@Ev) <> 0 do
        HandleEvent(App, Ev);
      if not App.Running then
        Break;
      EnsureBuffers(App);
      if App.Frame.Pixels = nil then
      begin
        SDL_Delay(16);
        Continue;
      end;
      AdvanceTime(App);
      if App.FullScreen then
        DrawFullScreen(App)
      else
        DrawSettings(App);
      PresentFrame(App);
    end;
    Cfg := App.Cfg;
    Persist(App);
  finally
    DestroyTexture(App);
    if App.Renderer <> nil then
      SDL_DestroyRenderer(App.Renderer);
    if App.Window <> nil then
      SDL_DestroyWindow(App.Window);
    SDL_Quit;
  end;
end;

end.
