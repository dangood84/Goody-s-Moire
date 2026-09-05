#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p bin
if [ ! -x bin/moire ]; then
  make compile
fi
# Rebuild when a source file is newer than the binary.
if [ -n "$(find src -name '*.pas' -newer bin/moire 2>/dev/null)" ]; then
  make compile
fi
exec ./bin/moire "$@"
