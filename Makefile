# Makefile for compiling web build of the Zig Raylib WASM game
#
# Using `bash -c` anywhere is janky, but the alternative is to source the env
# in your shell before calling `make`?? I haven't seen anyone with a resonable
# setup that just allows you to call `make`. Everything assumes that you manually
# activate the environment. That seems very much against the spirit of Makefiles.
#
# ===== Please Note =====
#
# This makefile is _intentionally_ dumb. It works. It's simple and stupid. So
# many makefiles for WASM/emscripten don't work because they try to be too fancy.
# Who cares that the Makefile is super generic if it doesn't work in the first
# place? Instead, the Makefile is an example the distills everything to the bone.
# If you can't get this working you _for sure_ can't get those more complicated
# examples working.
#
# Take this, use it, learn from it, then make it what you actually want.
#
# Yes, it forces you to take a bunch of steps on your own, but _it at least gives
# you the chance of taking that first step_.


# Update this to your actual emscripten path
EMSDK_PATH := /home/stephen/src/emsdk

EM_SYSROOT := $(EMSDK_PATH)/upstream/emscripten/cache/sysroot

dev: web

release: release/game.zip

release/game.zip: web
	mkdir -p release
	zip release/game.zip build/index.html build/index.js build/index.wasm build/index.data

web: build/index.html

build/index.html: build/libraylib.a src/main.zig raylib/src/minshell.html
	zig build-obj src/main.zig -target wasm32-freestanding -O ReleaseSmall -I. -Iraylib/src -Iraylib/src/external -I$(EM_SYSROOT)/include -lc -femit-bin=build/main.o
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o build/index.html build/main.o build/libraylib.a -L. -Lraylib/src -Lraylib/src -lidbfs.js -sUSE_GLFW=3 -sASYNCIFY -sEXPORTED_RUNTIME_METHODS=ccall --shell-file raylib/src/minshell.html -DPLATFORM_WEB -sFORCE_FILESYSTEM=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 --preload-file assets'

# # Here's the sort of approach you'd want to take to make this generic
#
# RAYLIB_SOURCES = $(wildcard raylib/src/*.c)
# RAYLIB_OBJECTS = $(RAYLIB_SOURCES:raylib/src/%.c=build/%.o)
# 
# build/libraylib.a: $(RAYLIB_OBJECTS)
# 	mkdir -p build
# 	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emar rcs $@ $(RAYLIB_OBJECTS)'
# 
# build/%.o: raylib/src/%.c
# 	mkdir -p build
# 	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o $@ -c $< -Os -Wall -DPLATFORM_WEB -DGRAPHICS_API_OPENGL_ES2'

build/libraylib.a:
	mkdir -p build
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o build/rcore.o -c raylib/src/rcore.c -Os -Wall -DPLATFORM_WEB -DGRAPHICS_API_OPENGL_ES2'
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o build/rshapes.o -c raylib/src/rshapes.c -Os -Wall -DPLATFORM_WEB -DGRAPHICS_API_OPENGL_ES2'
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o build/rtextures.o -c raylib/src/rtextures.c -Os -Wall -DPLATFORM_WEB -DGRAPHICS_API_OPENGL_ES2'
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o build/rtext.o -c raylib/src/rtext.c -Os -Wall -DPLATFORM_WEB -DGRAPHICS_API_OPENGL_ES2'
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o build/rmodels.o -c raylib/src/rmodels.c -Os -Wall -DPLATFORM_WEB -DGRAPHICS_API_OPENGL_ES2'
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o build/utils.o -c raylib/src/utils.c -Os -Wall -DPLATFORM_WEB'
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emcc -o build/raudio.o -c raylib/src/raudio.c -Os -Wall -DPLATFORM_WEB'
	bash -c 'source $(EMSDK_PATH)/emsdk_env.sh && emar rcs build/libraylib.a build/rcore.o build/rshapes.o build/rtextures.o build/rtext.o build/rmodels.o build/utils.o build/raudio.o'

clean:
	rm -rf build

.PHONY: dev release clean
