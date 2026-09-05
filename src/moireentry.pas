unit moireentry;

{$mode objfpc}{$H+}

{ Process logic. A tiny C main starts the process so macOS Cocoa is happy;
  this unit is the Free Pascal program. Lazarus is not used. }

interface

procedure RunMoire(CArgc: LongInt; CArgv: PPChar); cdecl;

implementation

uses
  SysUtils, moireconfig, moirerender, moireapp;

type
  TLaunchMode = (lmConfig, lmFullScreen, lmPreview, lmScreenshot);

var
  Argc: LongInt;
  Argv: PPChar;
  Mode: TLaunchMode;
  ShotPath: string;
  ShotAll: Boolean;
  Cfg: TMoireConfig;
  Shot: TPixmap;

function ArgStr(Index: Integer): string;
begin
  if (Index < 0) or (Index >= Argc) or (Argv = nil) then
    Result := ''
  else
    Result := string(Argv[Index]);
end;

function ArgCount: Integer;
begin
  if Argc > 0 then
    Result := Argc - 1
  else
    Result := 0;
end;

function StripPrefix(const Raw: string): string;
begin
  if Copy(Raw, 1, 2) = '--' then
    Result := Copy(Raw, 3, MaxInt)
  else if (Length(Raw) > 0) and ((Raw[1] = '-') or (Raw[1] = '/')) then
    Result := Copy(Raw, 2, MaxInt)
  else
    Result := Raw;
end;

procedure WriteHelp;
begin
  WriteLn('Goody''s Moire — classic Mac OS Moire tribute (Free Pascal + SDL2)');
  WriteLn;
  WriteLn('Usage: moire [options]');
  WriteLn;
  WriteLn('  (none), /c, --config       Preferences window with live preview');
  WriteLn('  /s, --fullscreen           Start the full-screen saver immediately');
  WriteLn('  /p, --preview              Windows-style preview hook; exit, no window');
  WriteLn('  --screenshot FILE.bmp      Draw one frame of the saved look and exit');
  WriteLn('  --help                     This text');
  WriteLn;
  WriteLn('Keys in the preview and full screen:');
  WriteLn('  1 rings   2 spokes   3 parallel lines   4 nested polygons');
  WriteLn('  Up/Down line density     Left/Right rotation speed');
  WriteLn('  Space pause     C colour cycle     Esc/Q quit full screen');
end;

procedure ParseArgs;
var
  I: Integer;
  Raw, Stripped: string;
begin
  Mode := lmConfig;
  ShotPath := '';
  ShotAll := False;
  I := 1;
  while I <= ArgCount do
  begin
    Raw := ArgStr(I);
    if Raw = '' then
    begin
      Inc(I);
      Continue;
    end;
    if (Raw = '--help') or (Raw = '-h') or (Raw = '/?') then
    begin
      WriteHelp;
      Halt(0);
    end;
    Stripped := StripPrefix(Raw);
    if (LowerCase(Stripped) = 's') or (LowerCase(Stripped) = 'fullscreen') then
      Mode := lmFullScreen
    else if (LowerCase(Copy(Stripped, 1, 1)) = 'c') or (LowerCase(Stripped) = 'config') then
      Mode := lmConfig
    else if (LowerCase(Copy(Stripped, 1, 1)) = 'p') or (LowerCase(Stripped) = 'preview') then
      Mode := lmPreview
    else if LowerCase(Stripped) = 'screenshot' then
    begin
      Mode := lmScreenshot;
      if I < ArgCount then
      begin
        Inc(I);
        ShotPath := ArgStr(I);
      end;
    end
    else if LowerCase(Stripped) = 'screenshot-all' then
    begin
      Mode := lmScreenshot;
      ShotAll := True;
      if I < ArgCount then
      begin
        Inc(I);
        ShotPath := ArgStr(I);
      end;
    end
    else
    begin
      WriteLn(StdErr, 'Unknown option: ', Raw);
      WriteLn(StdErr, 'Try --help');
      Halt(1);
    end;
    Inc(I);
  end;
end;

procedure DumpScreenshot(const Path: string; const UseCfg: TMoireConfig);
begin
  Shot.Pixels := nil;
  PixmapAlloc(Shot, 960, 540);
  try
    DrawMoire(Shot, UseCfg, 0.7);
    WritePixmapBMP(Shot, Path);
    WriteLn('Wrote ', Path);
  finally
    PixmapFree(Shot);
  end;
end;

procedure RunMoire(CArgc: LongInt; CArgv: PPChar); cdecl;
{$ifdef DARWIN}
  public name '_RunMoire';
{$else}
  public name 'RunMoire';
{$endif}
begin
  Argc := CArgc;
  Argv := CArgv;
  ParseArgs;
  if Mode = lmPreview then
    Halt(0);

  Cfg := LoadConfig;

  if Mode = lmScreenshot then
  begin
    if ShotAll then
    begin
      if ShotPath = '' then
        ShotPath := 'bin';
      ForceDirectories(ShotPath);
      ShotPath := IncludeTrailingPathDelimiter(ShotPath);
      Cfg.Pattern := mpRings;
      DumpScreenshot(ShotPath + 'rings.bmp', Cfg);
      Cfg.Pattern := mpSpokes;
      DumpScreenshot(ShotPath + 'spokes.bmp', Cfg);
      Cfg.Pattern := mpParallelLines;
      DumpScreenshot(ShotPath + 'lines.bmp', Cfg);
      Cfg.Pattern := mpPolygons;
      DumpScreenshot(ShotPath + 'polygons.bmp', Cfg);
      Cfg.Pattern := mpRings;
      Cfg.ColorMode := cmCyanMagenta;
      DumpScreenshot(ShotPath + 'rings-cyan.bmp', Cfg);
      Cfg.ColorMode := cmNeon;
      DumpScreenshot(ShotPath + 'rings-neon.bmp', Cfg);
    end
    else
    begin
      if ShotPath = '' then
        ShotPath := 'moire.bmp';
      DumpScreenshot(ShotPath, Cfg);
    end;
    Halt(0);
  end;

  try
    RunMoireApp(Cfg, Mode = lmFullScreen);
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      Halt(1);
    end;
  end;
end;

end.
