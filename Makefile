FPC ?= fpc
CC ?= cc
SRC_DIR := src
OUT_DIR := bin
PROG := moire

SDL_PREFIX := $(shell sdl2-config --prefix 2>/dev/null)
ifeq ($(SDL_PREFIX),)
  SDL_LIBDIR := /usr/local/lib
else
  SDL_LIBDIR := $(SDL_PREFIX)/lib
endif

SDL_CFLAGS := $(shell sdl2-config --cflags 2>/dev/null)
SDL_LIBS := $(shell sdl2-config --libs 2>/dev/null)
ifeq ($(SDL_LIBS),)
  SDL_LIBS := -L$(SDL_LIBDIR) -lSDL2
endif

UNAME := $(shell uname)
WRAP_OBJ :=
ifeq ($(UNAME),Darwin)
  LIBFILE := libmoire.dylib
  RPATH := -Wl,-rpath,@loader_path -Wl,-rpath,$(SDL_LIBDIR)
  WRAP_OBJ := $(OUT_DIR)/sdlwrap.o
else ifeq ($(UNAME),Linux)
  LIBFILE := libmoire.so
  RPATH := -Wl,-rpath,'$$ORIGIN' -Wl,-rpath,$(SDL_LIBDIR)
else
  LIBFILE := libmoire.dll
  RPATH :=
endif

# Debian / Raspberry Pi OS keep libSDL2.so in a multiarch folder, not /usr/lib.
MULTIARCH := $(shell gcc -print-multiarch 2>/dev/null)

FPCFLAGS := -Mobjfpc -Sh -O2 -fPIC -FE$(OUT_DIR) -FU$(OUT_DIR) -Fu$(SRC_DIR)
FPCFLAGS += -Fl$(SDL_LIBDIR) -k-L$(SDL_LIBDIR) -k-lSDL2
ifneq ($(WRAP_OBJ),)
  FPCFLAGS += -k$(WRAP_OBJ)
endif
ifneq ($(MULTIARCH),)
  FPCFLAGS += -Fl/usr/lib/$(MULTIARCH) -k-L/usr/lib/$(MULTIARCH)
endif

.PHONY: all compile run config screensaver screenshot clean

all: compile

$(OUT_DIR)/sdlwrap.o: $(SRC_DIR)/sdlwrap.c
	mkdir -p $(OUT_DIR)
	$(CC) -c -o $@ $< $(SDL_CFLAGS)

$(OUT_DIR)/$(LIBFILE): $(SRC_DIR)/moire.pas $(SRC_DIR)/moireentry.pas $(WRAP_OBJ)
	mkdir -p $(OUT_DIR)
	$(FPC) $(FPCFLAGS) -o$(OUT_DIR)/$(LIBFILE) $(SRC_DIR)/moire.pas

compile: $(OUT_DIR)/$(LIBFILE)
	$(CC) -o $(OUT_DIR)/$(PROG) $(SRC_DIR)/main.c -L$(OUT_DIR) -lmoire $(SDL_LIBS) $(RPATH)

run: config

config: compile
	$(OUT_DIR)/$(PROG) --config

screensaver: compile
	$(OUT_DIR)/$(PROG) --fullscreen

screenshot: compile
	$(OUT_DIR)/$(PROG) --screenshot $(OUT_DIR)/moire.bmp

clean:
	rm -rf $(OUT_DIR)
