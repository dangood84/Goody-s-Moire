unit sdl2min;

{$mode objfpc}{$H+}
{$PACKRECORDS C}

{ Minimal SDL2 declarations for a software-canvas window. No Lazarus.
  SDL_QUIT is named SDL_EVENT_QUIT: Pascal is case-insensitive and would
  treat SDL_Quit (the procedure) as the same identifier. }

interface

const
  SDL_INIT_VIDEO = $00000020;

  SDL_WINDOWPOS_CENTERED = $2FFF0000;

  SDL_WINDOW_SHOWN = $00000004;
  SDL_WINDOW_RESIZABLE = $00000020;
  SDL_WINDOW_FULLSCREEN_DESKTOP = $00001001;
  SDL_WINDOW_ALLOW_HIGHDPI = $00002000;

  SDL_RENDERER_ACCELERATED = $00000002;
  SDL_RENDERER_PRESENTVSYNC = $00000004;

  SDL_PIXELFORMAT_ARGB8888 = $16362004;
  SDL_TEXTUREACCESS_STREAMING = 1;

  SDL_EVENT_QUIT = $100;
  SDL_WINDOWEVENT = $200;
  SDL_WINDOWEVENT_CLOSE = 14;
  SDL_KEYDOWN = $300;
  SDL_MOUSEMOTION = $400;
  SDL_MOUSEBUTTONDOWN = $401;
  SDL_MOUSEBUTTONUP = $402;

  SDL_BUTTON_LEFT = 1;

  SDL_DISABLE = 0;
  SDL_ENABLE = 1;

  SDLK_ESCAPE = 27;
  SDLK_SPACE = 32;
  SDLK_1 = Ord('1');
  SDLK_2 = Ord('2');
  SDLK_3 = Ord('3');
  SDLK_4 = Ord('4');
  SDLK_c = Ord('c');
  SDLK_q = Ord('q');
  SDLK_RETURN = 13;
  SDLK_RIGHT = $4000004F;
  SDLK_LEFT = $40000050;
  SDLK_DOWN = $40000051;
  SDLK_UP = $40000052;

type
  PSDL_Window = Pointer;
  PSDL_Renderer = Pointer;
  PSDL_Texture = Pointer;
  PSDL_Rect = ^TSDL_Rect;

  TSDL_Rect = record
    x, y, w, h: LongInt;
  end;

  TSDL_Keysym = record
    scancode: LongInt;
    sym: LongInt;
    keymod: Word;
    unused: LongWord;
  end;

  TSDL_KeyboardEvent = record
    eventtype: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    state: Byte;
    repeat_: Byte;
    padding2: Byte;
    padding3: Byte;
    keysym: TSDL_Keysym;
  end;

  TSDL_MouseMotionEvent = record
    eventtype: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    which: LongWord;
    state: LongWord;
    x, y: LongInt;
    xrel, yrel: LongInt;
  end;

  TSDL_MouseButtonEvent = record
    eventtype: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    which: LongWord;
    button: Byte;
    state: Byte;
    clicks: Byte;
    padding1: Byte;
    x, y: LongInt;
  end;

  TSDL_WindowEvent = record
    eventtype: LongWord;
    timestamp: LongWord;
    windowID: LongWord;
    event: Byte;
    padding1: Byte;
    padding2: Byte;
    padding3: Byte;
    data1, data2: LongInt;
  end;

  TSDL_Event = record
    case Integer of
      0: (eventtype: LongWord);
      1: (key: TSDL_KeyboardEvent);
      2: (motion: TSDL_MouseMotionEvent);
      3: (button: TSDL_MouseButtonEvent);
      4: (window: TSDL_WindowEvent);
      5: (padding: array[0..63] of Byte);
  end;
  PSDL_Event = ^TSDL_Event;

function Moire_VideoInit: LongInt; cdecl; external name 'Moire_VideoInit';
function Moire_CreateWindow(title: PAnsiChar; width, height: LongInt; flags: LongWord): PSDL_Window; cdecl; external name 'Moire_CreateWindow';

procedure SDL_SetMainReady; cdecl; external 'SDL2';
function SDL_Init(flags: LongWord): LongInt; cdecl; external 'SDL2';
procedure SDL_Quit; cdecl; external 'SDL2';
function SDL_GetError: PChar; cdecl; external 'SDL2';

function SDL_CreateWindow(title: PChar; x, y, w, h: LongInt; flags: LongWord): PSDL_Window; cdecl; external 'SDL2';
procedure SDL_DestroyWindow(window: PSDL_Window); cdecl; external 'SDL2';
function SDL_SetWindowFullscreen(window: PSDL_Window; flags: LongWord): LongInt; cdecl; external 'SDL2';
procedure SDL_SetWindowTitle(window: PSDL_Window; title: PChar); cdecl; external 'SDL2';
procedure SDL_GetWindowSize(window: PSDL_Window; w, h: PLongInt); cdecl; external 'SDL2';
procedure SDL_ShowWindow(window: PSDL_Window); cdecl; external 'SDL2';

function SDL_CreateRenderer(window: PSDL_Window; index: LongInt; flags: LongWord): PSDL_Renderer; cdecl; external 'SDL2';
procedure SDL_DestroyRenderer(renderer: PSDL_Renderer); cdecl; external 'SDL2';
function SDL_GetRendererOutputSize(renderer: PSDL_Renderer; w, h: PLongInt): LongInt; cdecl; external 'SDL2';
function SDL_RenderClear(renderer: PSDL_Renderer): LongInt; cdecl; external 'SDL2';
function SDL_RenderCopy(renderer: PSDL_Renderer; texture: PSDL_Texture; src, dst: PSDL_Rect): LongInt; cdecl; external 'SDL2';
procedure SDL_RenderPresent(renderer: PSDL_Renderer); cdecl; external 'SDL2';

function SDL_CreateTexture(renderer: PSDL_Renderer; format: LongWord; access: LongInt; w, h: LongInt): PSDL_Texture; cdecl; external 'SDL2';
procedure SDL_DestroyTexture(texture: PSDL_Texture); cdecl; external 'SDL2';
function SDL_UpdateTexture(texture: PSDL_Texture; rect: PSDL_Rect; pixels: Pointer; pitch: LongInt): LongInt; cdecl; external 'SDL2';

function SDL_PollEvent(event: PSDL_Event): LongInt; cdecl; external 'SDL2';
function SDL_ShowCursor(toggle: LongInt): LongInt; cdecl; external 'SDL2';
function SDL_GetPerformanceCounter: QWord; cdecl; external 'SDL2';
function SDL_GetPerformanceFrequency: QWord; cdecl; external 'SDL2';
procedure SDL_Delay(ms: LongWord); cdecl; external 'SDL2';

implementation

end.
