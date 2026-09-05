unit moirerender;

{$mode objfpc}{$H+}

{ Software framebuffer + classic XOR moiré gratings.
  Two overlapping layers create the interference; XOR is the old QuickDraw look. }

interface

uses
  moireconfig;

type
  TPixmap = record
    Pixels: PLongWord;
    Width, Height: Integer;
  end;

procedure PixmapAlloc(var Pm: TPixmap; W, H: Integer);
procedure PixmapFree(var Pm: TPixmap);
procedure PixmapFill(var Pm: TPixmap; Color: LongWord);
procedure PixmapFillRect(var Pm: TPixmap; X, Y, W, H: Integer; Color: LongWord);
procedure PixmapHLine(var Pm: TPixmap; X1, X2, Y: Integer; Color: LongWord);
procedure PixmapVLine(var Pm: TPixmap; X, Y1, Y2: Integer; Color: LongWord);
procedure PixmapRect(var Pm: TPixmap; X, Y, W, H: Integer; Color: LongWord);
procedure PixmapBevel(var Pm: TPixmap; X, Y, W, H: Integer; RaisedLook: Boolean; Face: LongWord);

procedure DrawMoire(var Pm: TPixmap; const Cfg: TMoireConfig; Angle: Double);
procedure WritePixmapBMP(const Pm: TPixmap; const FileName: string);

const
  ColorBlack = $FF000000;
  ColorWhite = $FFFFFFFF;
  ColorCyan = $FF00FFFF;
  ColorMagenta = $FFFF00FF;
  ColorNeon = $FF39FF14;

implementation

uses
  Math, SysUtils;

procedure PixmapAlloc(var Pm: TPixmap; W, H: Integer);
var
  Count: Integer;
begin
  PixmapFree(Pm);
  if (W <= 0) or (H <= 0) then
    Exit;
  Pm.Width := W;
  Pm.Height := H;
  Count := W * H;
  GetMem(Pm.Pixels, Count * SizeOf(LongWord));
end;

procedure PixmapFree(var Pm: TPixmap);
begin
  if Pm.Pixels <> nil then
    FreeMem(Pm.Pixels);
  Pm.Pixels := nil;
  Pm.Width := 0;
  Pm.Height := 0;
end;

procedure PixmapFill(var Pm: TPixmap; Color: LongWord);
var
  I, Count: Integer;
begin
  if Pm.Pixels = nil then
    Exit;
  Count := Pm.Width * Pm.Height;
  for I := 0 to Count - 1 do
    Pm.Pixels[I] := Color;
end;

procedure Plot(var Pm: TPixmap; X, Y: Integer; Color: LongWord);
begin
  if (X < 0) or (Y < 0) or (X >= Pm.Width) or (Y >= Pm.Height) then
    Exit;
  Pm.Pixels[Y * Pm.Width + X] := Color;
end;

procedure XorPlot(var Pm: TPixmap; X, Y: Integer; Color: LongWord);
var
  I: Integer;
begin
  if (X < 0) or (Y < 0) or (X >= Pm.Width) or (Y >= Pm.Height) then
    Exit;
  I := Y * Pm.Width + X;
  { XOR the RGB only. Forcing alpha keeps the streaming texture opaque;
    two white strokes on black cancel in the overlap — QuickDraw moiré. }
  Pm.Pixels[I] := (Pm.Pixels[I] xor (Color and $00FFFFFF)) or $FF000000;
end;

procedure PixmapFillRect(var Pm: TPixmap; X, Y, W, H: Integer; Color: LongWord);
var
  IX, IY, X2, Y2: Integer;
begin
  if (Pm.Pixels = nil) or (W <= 0) or (H <= 0) then
    Exit;
  X2 := X + W - 1;
  Y2 := Y + H - 1;
  if X < 0 then
    X := 0;
  if Y < 0 then
    Y := 0;
  if X2 >= Pm.Width then
    X2 := Pm.Width - 1;
  if Y2 >= Pm.Height then
    Y2 := Pm.Height - 1;
  for IY := Y to Y2 do
    for IX := X to X2 do
      Pm.Pixels[IY * Pm.Width + IX] := Color;
end;

procedure PixmapHLine(var Pm: TPixmap; X1, X2, Y: Integer; Color: LongWord);
var
  T: Integer;
begin
  if X2 < X1 then
  begin
    T := X1;
    X1 := X2;
    X2 := T;
  end;
  if (Y < 0) or (Y >= Pm.Height) then
    Exit;
  if X1 < 0 then
    X1 := 0;
  if X2 >= Pm.Width then
    X2 := Pm.Width - 1;
  while X1 <= X2 do
  begin
    Pm.Pixels[Y * Pm.Width + X1] := Color;
    Inc(X1);
  end;
end;

procedure PixmapVLine(var Pm: TPixmap; X, Y1, Y2: Integer; Color: LongWord);
var
  T: Integer;
begin
  if Y2 < Y1 then
  begin
    T := Y1;
    Y1 := Y2;
    Y2 := T;
  end;
  if (X < 0) or (X >= Pm.Width) then
    Exit;
  if Y1 < 0 then
    Y1 := 0;
  if Y2 >= Pm.Height then
    Y2 := Pm.Height - 1;
  while Y1 <= Y2 do
  begin
    Pm.Pixels[Y1 * Pm.Width + X] := Color;
    Inc(Y1);
  end;
end;

procedure PixmapRect(var Pm: TPixmap; X, Y, W, H: Integer; Color: LongWord);
begin
  if (W <= 0) or (H <= 0) then
    Exit;
  PixmapHLine(Pm, X, X + W - 1, Y, Color);
  PixmapHLine(Pm, X, X + W - 1, Y + H - 1, Color);
  PixmapVLine(Pm, X, Y, Y + H - 1, Color);
  PixmapVLine(Pm, X + W - 1, Y, Y + H - 1, Color);
end;

procedure PixmapBevel(var Pm: TPixmap; X, Y, W, H: Integer; RaisedLook: Boolean; Face: LongWord);
var
  Light, Dark: LongWord;
begin
  PixmapFillRect(Pm, X, Y, W, H, Face);
  if RaisedLook then
  begin
    Light := $FFFFFFFF;
    Dark := $FF666666;
  end
  else
  begin
    Light := $FF666666;
    Dark := $FFFFFFFF;
  end;
  PixmapHLine(Pm, X, X + W - 2, Y, Light);
  PixmapVLine(Pm, X, Y, Y + H - 2, Light);
  PixmapHLine(Pm, X, X + W - 1, Y + H - 1, Dark);
  PixmapVLine(Pm, X + W - 1, Y, Y + H - 1, Dark);
end;

procedure XorLine(var Pm: TPixmap; X0, Y0, X1, Y1: Integer; Color: LongWord);
var
  DX, DY, SX, SY, Err, E2: Integer;
begin
  DX := Abs(X1 - X0);
  DY := Abs(Y1 - Y0);
  if X0 < X1 then
    SX := 1
  else
    SX := -1;
  if Y0 < Y1 then
    SY := 1
  else
    SY := -1;
  Err := DX - DY;
  while True do
  begin
    XorPlot(Pm, X0, Y0, Color);
    if (X0 = X1) and (Y0 = Y1) then
      Break;
    E2 := Err * 2;
    if E2 > -DY then
    begin
      Err := Err - DY;
      X0 := X0 + SX;
    end;
    if E2 < DX then
    begin
      Err := Err + DX;
      Y0 := Y0 + SY;
    end;
  end;
end;

procedure XorCircle(var Pm: TPixmap; CX, CY, Radius: Integer; Color: LongWord);
var
  X, Y, D: Integer;
begin
  if Radius < 1 then
    Exit;
  X := 0;
  Y := Radius;
  D := 3 - 2 * Radius;
  while X <= Y do
  begin
    XorPlot(Pm, CX + X, CY + Y, Color);
    XorPlot(Pm, CX - X, CY + Y, Color);
    XorPlot(Pm, CX + X, CY - Y, Color);
    XorPlot(Pm, CX - X, CY - Y, Color);
    XorPlot(Pm, CX + Y, CY + X, Color);
    XorPlot(Pm, CX - Y, CY + X, Color);
    XorPlot(Pm, CX + Y, CY - X, Color);
    XorPlot(Pm, CX - Y, CY - X, Color);
    if D < 0 then
      D := D + 4 * X + 6
    else
    begin
      D := D + 4 * (X - Y) + 10;
      Dec(Y);
    end;
    Inc(X);
  end;
end;

procedure XorPolygon(var Pm: TPixmap; CX, CY, Radius, Sides: Integer; Rotation: Double; Color: LongWord);
var
  I: Integer;
  A0, A1: Double;
  X0, Y0, X1, Y1: Integer;
begin
  if (Sides < 3) or (Radius < 2) then
    Exit;
  for I := 0 to Sides - 1 do
  begin
    A0 := Rotation + I * (2 * Pi / Sides);
    A1 := Rotation + (I + 1) * (2 * Pi / Sides);
    X0 := CX + Round(Cos(A0) * Radius);
    Y0 := CY + Round(Sin(A0) * Radius);
    X1 := CX + Round(Cos(A1) * Radius);
    Y1 := CY + Round(Sin(A1) * Radius);
    XorLine(Pm, X0, Y0, X1, Y1, Color);
  end;
end;

procedure LayerColors(Mode: TColorMode; out A, B: LongWord);
begin
  case Mode of
    cmCyanMagenta:
    begin
      A := ColorCyan;
      B := ColorMagenta;
    end;
    cmNeon:
    begin
      A := ColorNeon;
      B := ColorNeon;
    end;
  else
    A := ColorWhite;
    B := ColorWhite;
  end;
end;

procedure DrawRings(var Pm: TPixmap; const Cfg: TMoireConfig; Angle: Double);
var
  CX, CY, Amp, R, MaxR, Step: Integer;
  C1X, C1Y, C2X, C2Y: Integer;
  ColA, ColB: LongWord;
begin
  LayerColors(Cfg.ColorMode, ColA, ColB);
  CX := Pm.Width div 2;
  CY := Pm.Height div 2;
  Amp := Max(8, Min(Pm.Width, Pm.Height) div 8);
  { Incommensurate frequencies so the two origins never lock in step. }
  C1X := CX + Round(Cos(Angle) * Amp);
  C1Y := CY + Round(Sin(Angle * 0.83) * Amp);
  C2X := CX + Round(Cos(Angle * 1.17 + Pi) * Amp);
  C2Y := CY + Round(Sin(Angle * 0.71) * Amp);
  Step := Cfg.LineSpacing;
  { Past the diagonal so wandering centres still cover the corners. }
  MaxR := Round(Hypot(Pm.Width, Pm.Height)) + Amp;
  R := Step;
  while R <= MaxR do
  begin
    XorCircle(Pm, C1X, C1Y, R, ColA);
    XorCircle(Pm, C2X, C2Y, R, ColB);
    Inc(R, Step);
  end;
end;

procedure DrawSpokes(var Pm: TPixmap; const Cfg: TMoireConfig; Angle: Double);
var
  CX, CY, C2X, C2Y, I, Count, Len, Amp: Integer;
  A: Double;
  ColA, ColB: LongWord;
begin
  LayerColors(Cfg.ColorMode, ColA, ColB);
  CX := Pm.Width div 2;
  CY := Pm.Height div 2;
  Amp := Max(6, Min(Pm.Width, Pm.Height) div 10);
  C2X := CX + Round(Cos(Angle * 0.65) * Amp);
  C2Y := CY + Round(Sin(Angle * 0.92) * Amp);
  Len := Round(Hypot(Pm.Width, Pm.Height)) + 4;
  Count := Max(16, (360 div Max(Cfg.LineSpacing, 1)));
  if Count > 240 then
    Count := 240;
  for I := 0 to Count - 1 do
  begin
    A := Angle + I * (2 * Pi / Count);
    XorLine(Pm, CX, CY, CX + Round(Cos(A) * Len), CY + Round(Sin(A) * Len), ColA);
    { Opposite spin, half-spoke offset, slightly different origin: a single
      shared centre would look like one star, not interference. }
    A := -Angle * 1.15 + I * (2 * Pi / Count) + Pi / Count;
    XorLine(Pm, C2X, C2Y, C2X + Round(Cos(A) * Len), C2Y + Round(Sin(A) * Len), ColB);
  end;
end;

procedure DrawParallelSet(var Pm: TPixmap; CX, CY, Half: Integer; Angle: Double; Step: Integer; Color: LongWord);
var
  I, Limit, OX, OY, DX, DY: Integer;
  NX, NY: Double;
begin
  NX := Cos(Angle + Pi / 2);
  NY := Sin(Angle + Pi / 2);
  DX := Round(Cos(Angle) * (Half + 8));
  DY := Round(Sin(Angle) * (Half + 8));
  Limit := (Half * 2) div Max(Step, 1) + 2;
  for I := -Limit to Limit do
  begin
    OX := CX + Round(NX * I * Step);
    OY := CY + Round(NY * I * Step);
    XorLine(Pm, OX - DX, OY - DY, OX + DX, OY + DY, Color);
  end;
end;

procedure DrawParallelLines(var Pm: TPixmap; const Cfg: TMoireConfig; Angle: Double);
var
  CX, CY, Half: Integer;
  ColA, ColB: LongWord;
begin
  LayerColors(Cfg.ColorMode, ColA, ColB);
  CX := Pm.Width div 2;
  CY := Pm.Height div 2;
  Half := Round(Hypot(Pm.Width, Pm.Height));
  DrawParallelSet(Pm, CX, CY, Half, Angle, Cfg.LineSpacing, ColA);
  { Near-orthogonal second grating is what turns stripes into ripples. }
  DrawParallelSet(Pm, CX, CY, Half, -Angle * 0.85 + Pi / 2, Cfg.LineSpacing, ColB);
end;

procedure DrawPolygons(var Pm: TPixmap; const Cfg: TMoireConfig; Angle: Double);
var
  CX, CY, R, MaxR, Step: Integer;
  ColA, ColB: LongWord;
begin
  LayerColors(Cfg.ColorMode, ColA, ColB);
  CX := Pm.Width div 2;
  CY := Pm.Height div 2;
  Step := Cfg.LineSpacing;
  MaxR := Round(Hypot(Pm.Width, Pm.Height) / 2) + 8;
  R := MaxR;
  while R >= Step do
  begin
    XorPolygon(Pm, CX, CY, R, 4, Angle, ColA);
    { Squares against hexagons: different side counts beat more visibly. }
    XorPolygon(Pm, CX, CY, R, 6, -Angle * 1.1 + Pi / 6, ColB);
    Dec(R, Step);
  end;
end;

procedure DrawMoire(var Pm: TPixmap; const Cfg: TMoireConfig; Angle: Double);
begin
  if Pm.Pixels = nil then
    Exit;
  PixmapFill(Pm, ColorBlack);
  case Cfg.Pattern of
    mpSpokes: DrawSpokes(Pm, Cfg, Angle);
    mpParallelLines: DrawParallelLines(Pm, Cfg, Angle);
    mpPolygons: DrawPolygons(Pm, Cfg, Angle);
  else
    DrawRings(Pm, Cfg, Angle);
  end;
end;

procedure WritePixmapBMP(const Pm: TPixmap; const FileName: string);
var
  F: File of Byte;
  Row, Col, Pad, I: Integer;
  Pixel: LongWord;
  B, G, R: Byte;
  Header: array[0..53] of Byte;
  Padding: array[0..3] of Byte;
  FileSize, PixelBytes: LongWord;
begin
  if Pm.Pixels = nil then
    raise Exception.Create('No pixmap to write');
  Pad := (4 - ((Pm.Width * 3) mod 4)) mod 4;
  PixelBytes := LongWord((Pm.Width * 3 + Pad) * Pm.Height);
  FileSize := 54 + PixelBytes;
  FillChar(Header, SizeOf(Header), 0);
  Header[0] := Ord('B');
  Header[1] := Ord('M');
  Header[2] := Byte(FileSize);
  Header[3] := Byte(FileSize shr 8);
  Header[4] := Byte(FileSize shr 16);
  Header[5] := Byte(FileSize shr 24);
  Header[10] := 54;
  Header[14] := 40;
  Header[18] := Byte(Pm.Width);
  Header[19] := Byte(Pm.Width shr 8);
  Header[20] := Byte(Pm.Width shr 16);
  Header[21] := Byte(Pm.Width shr 24);
  Header[22] := Byte(Pm.Height);
  Header[23] := Byte(Pm.Height shr 8);
  Header[24] := Byte(Pm.Height shr 16);
  Header[25] := Byte(Pm.Height shr 24);
  Header[26] := 1;
  Header[28] := 24;
  AssignFile(F, FileName);
  Rewrite(F);
  try
    for I := 0 to 53 do
      Write(F, Header[I]);
    FillChar(Padding, SizeOf(Padding), 0);
    { BMP rows are bottom-up; we store the pixmap top-down. }
    for Row := Pm.Height - 1 downto 0 do
    begin
      for Col := 0 to Pm.Width - 1 do
      begin
        Pixel := Pm.Pixels[Row * Pm.Width + Col];
        B := Byte(Pixel);
        G := Byte(Pixel shr 8);
        R := Byte(Pixel shr 16);
        Write(F, B);
        Write(F, G);
        Write(F, R);
      end;
      for I := 1 to Pad do
        Write(F, Padding[0]);
    end;
  finally
    CloseFile(F);
  end;
end;

end.
