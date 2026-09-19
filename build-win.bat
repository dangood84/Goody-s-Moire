@echo off
setlocal
cd /d "%~dp0"

where fpc >nul 2>&1
if errorlevel 1 (
  echo fpc is not on PATH. Open a new Command Prompt after installing Free Pascal.
  exit /b 1
)

echo Free Pascal:
fpc -iV
echo Target CPU:
fpc -iTP
echo.

if not exist bin mkdir bin

echo Compiling src\winmain.pas -^> bin\moire.exe
fpc -Mobjfpc -Sh -O2 -FEbin -FUbin -Fusrc -obin\moire.exe src\winmain.pas
if errorlevel 1 (
  echo Compile failed.
  exit /b 1
)

echo.
if exist bin\SDL2.dll (
  echo SDL2.dll is already in bin\
  echo Run:  bin\moire.exe
) else (
  echo Built bin\moire.exe
  echo.
  echo You still need SDL2.dll next to that exe. You do not compile it.
  echo.
  echo 1. Look at "Target CPU" above:
  echo      x86_64  -^> 64-bit zip
  echo      i386    -^> 32-bit zip
  echo 2. Open:  https://github.com/libsdl-org/SDL/releases
  echo    Download the latest SDL2 runtime zip, not the Source one:
  echo      SDL2-*-win32-x64.zip     ^(for x86_64^)
  echo      SDL2-*-win32-x86.zip     ^(for i386^)
  echo 3. Unzip it and copy SDL2.dll into this project's bin folder.
  echo 4. Run:  bin\moire.exe
)
exit /b 0
