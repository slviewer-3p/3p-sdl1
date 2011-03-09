#!/bin/sh

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

TOP="$(dirname "$0")"

SDL_VERSION="1.2.14"
SDL_SOURCE_DIR="SDL-$SDL_VERSION"

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
        pushd "$TOP/$SDL_SOURCE_DIR"
            LDFLAGS="-m32  -L"$stage/lib"" CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$stage" --target=i686-linux-gnu
            make
            make install
        popd
    ;;
    *)
        exit -1
    ;;
esac

# cp -r "$TOP/$SDL_SOURCE_DIR/include" "$stage"

# mkdir -p "$stage/LICENSES"
# cp "$TOP/$OPENAL_SOURCE_DIR/COPYING" "$stage/LICENSES/openal.txt"

pass

