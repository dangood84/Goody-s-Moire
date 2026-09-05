unit moireconfig;

{$mode objfpc}{$H+}

{ Appearance model only. Animation angle lives on the canvas, not here,
  so a saved INI cannot freeze the pattern mid-spin. }

interface

type
  TMoirePattern = (
    mpRings,
    mpSpokes,
    mpParallelLines,
    mpPolygons
  );

  TColorMode = (
    cmMono,
    cmCyanMagenta,
    cmNeon
  );

  TMoireConfig = record
    Pattern: TMoirePattern;
    LineSpacing: Integer;
    RotationSpeed: Integer;
    ColorMode: TColorMode;
  end;

const
  MinSpacing = 2;
  MaxSpacing = 50;
  MinSpeed = 1;
  MaxSpeed = 40;
  DefaultSpacing = 8;
  DefaultSpeed = 12;

function DefaultConfig: TMoireConfig;
function LoadConfig: TMoireConfig;
procedure SaveConfig(const Cfg: TMoireConfig);
function CopyConfig(const Cfg: TMoireConfig): TMoireConfig;

procedure SetPattern(var Cfg: TMoireConfig; Value: TMoirePattern);
procedure SetLineSpacing(var Cfg: TMoireConfig; Value: Integer);
procedure SetRotationSpeed(var Cfg: TMoireConfig; Value: Integer);
procedure SetColorMode(var Cfg: TMoireConfig; Value: TColorMode);
procedure CycleColorMode(var Cfg: TMoireConfig);

function PatternName(Pattern: TMoirePattern): string;
function ColorModeName(Mode: TColorMode): string;
function RadiansPerSecond(Speed: Integer): Double;

implementation

uses
  Classes, IniFiles, SysUtils;

const
  Section = 'display';

function ClampInt(Value, Lo, Hi: Integer): Integer;
begin
  if Value < Lo then
    Result := Lo
  else if Value > Hi then
    Result := Hi
  else
    Result := Value;
end;

function ConfigPath: string;
var
  Dir: string;
begin
  { Per-user OS config dir, not the repo, so relaunch keeps the last look. }
  Dir := GetAppConfigDir(False);
  ForceDirectories(Dir);
  Result := IncludeTrailingPathDelimiter(Dir) + 'moire.ini';
end;

function DefaultConfig: TMoireConfig;
begin
  Result.Pattern := mpRings;
  Result.LineSpacing := DefaultSpacing;
  Result.RotationSpeed := DefaultSpeed;
  Result.ColorMode := cmMono;
end;

function LoadConfig: TMoireConfig;
var
  Ini: TIniFile;
begin
  Result := DefaultConfig;
  Ini := TIniFile.Create(ConfigPath);
  try
    { Clamp after read so a hand-edited INI cannot inject a bogus enum. }
    Result.Pattern := TMoirePattern(ClampInt(Ini.ReadInteger(Section, 'pattern', Ord(Result.Pattern)), 0, 3));
    Result.LineSpacing := ClampInt(Ini.ReadInteger(Section, 'spacing', Result.LineSpacing), MinSpacing, MaxSpacing);
    Result.RotationSpeed := ClampInt(Ini.ReadInteger(Section, 'speed', Result.RotationSpeed), MinSpeed, MaxSpeed);
    Result.ColorMode := TColorMode(ClampInt(Ini.ReadInteger(Section, 'color', Ord(Result.ColorMode)), 0, 2));
  finally
    Ini.Free;
  end;
end;

procedure SaveConfig(const Cfg: TMoireConfig);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ConfigPath);
  try
    Ini.WriteInteger(Section, 'pattern', Ord(Cfg.Pattern));
    Ini.WriteInteger(Section, 'spacing', Cfg.LineSpacing);
    Ini.WriteInteger(Section, 'speed', Cfg.RotationSpeed);
    Ini.WriteInteger(Section, 'color', Ord(Cfg.ColorMode));
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function CopyConfig(const Cfg: TMoireConfig): TMoireConfig;
begin
  Result := Cfg;
end;

procedure SetPattern(var Cfg: TMoireConfig; Value: TMoirePattern);
begin
  Cfg.Pattern := Value;
end;

procedure SetLineSpacing(var Cfg: TMoireConfig; Value: Integer);
begin
  Cfg.LineSpacing := ClampInt(Value, MinSpacing, MaxSpacing);
end;

procedure SetRotationSpeed(var Cfg: TMoireConfig; Value: Integer);
begin
  Cfg.RotationSpeed := ClampInt(Value, MinSpeed, MaxSpeed);
end;

procedure SetColorMode(var Cfg: TMoireConfig; Value: TColorMode);
begin
  Cfg.ColorMode := Value;
end;

procedure CycleColorMode(var Cfg: TMoireConfig);
begin
  if Cfg.ColorMode = High(TColorMode) then
    Cfg.ColorMode := Low(TColorMode)
  else
    Cfg.ColorMode := Succ(Cfg.ColorMode);
end;

function PatternName(Pattern: TMoirePattern): string;
begin
  case Pattern of
    mpRings: Result := 'Rings';
    mpSpokes: Result := 'Spokes';
    mpParallelLines: Result := 'Lines';
    mpPolygons: Result := 'Polygons';
  else
    Result := 'Rings';
  end;
end;

function ColorModeName(Mode: TColorMode): string;
begin
  case Mode of
    cmMono: Result := 'Mono';
    cmCyanMagenta: Result := 'Cyan/Magenta';
    cmNeon: Result := 'Neon Green';
  else
    Result := 'Mono';
  end;
end;

function RadiansPerSecond(Speed: Integer): Double;
begin
  { Integer slider 1..40 → angular velocity. 12 * 0.08 = 0.96 rad/s. }
  Result := ClampInt(Speed, MinSpeed, MaxSpeed) * 0.08;
end;

end.
