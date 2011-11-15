#!/bin/bash

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

TOP="$(dirname "$0")"

SDL_VERSION="1.2.14"
SDL_SOURCE_DIR="SDL-$SDL_VERSION"
DIRECTFB_VERSION="1.4.9"
DIRECTFB_SOURCE_DIR="DirectFB-$DIRECTFB_VERSION"


if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autbuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

stage="$(pwd)"
case "$AUTOBUILD_PLATFORM" in
    "linux")
        pushd "$TOP/$DIRECTFB_SOURCE_DIR"
			# do release build of directfb	
            LDFLAGS="-m32 -L"$stage/packages/lib/release"" CFLAGS="-I"$stage/packages/include" -m32 -O3" CXXFLAGS="-I"$stage/packages/include" -m32 -O3" LIBPNG_CFLAGS="$CFLAGS" LIBPNG_LIBS="-lpng -lz -lm" ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include" --enable-static --enable-zlib --disable-freetype
            make
            make install

			# clean the build tree
			make distclean

			# do release debug of directfb	
            LDFLAGS="-m32 -L"$stage/packages/lib/debug"" CFLAGS="-I"$stage/packages/include" -m32 -gstabs+" CXXFLAGS="-I"$stage/packages/include" -m32 -gstabs+" LIBPNG_CFLAGS="$CFLAGS" LIBPNG_LIBS="-lpng -lz -lm" ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include" --enable-static --enable-zlib --disable-freetype
            make
            make install
        popd
        pushd "$TOP/$SDL_SOURCE_DIR"
			# do release build of sdl
            LDFLAGS="-m32  -L"$stage/packages/lib/release"" CFLAGS="-I"$stage/packages/include" -m32 -O3" CXXFLAGS="-I"$stage/packages/include" -m32 -O2" ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include" --target=i686-linux-gnu
            make
            make install

			# clean the build tree
			make distclean

			# do debug build of sdl
            LDFLAGS="-m32  -L"$stage/packages/lib/debug"" CFLAGS="-I"$stage/packages/include" -m32 -O0 -gstabs+" CXXFLAGS="-I"$stage/packages/include" -m32 -O0 -gstabs+" ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include" --target=i686-linux-gnu
            make
            make install
        popd
    ;;
    *)
        exit -1
    ;;
esac


mkdir -p "$stage/LICENSES"
cp "$TOP/$SDL_SOURCE_DIR/COPYING" "$stage/LICENSES/SDL.txt"

pass

