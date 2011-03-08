#!/bin/sh

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

TOP="$(dirname "$0")"

SDL_VERSION="1.2.14"
SDL_SOURCE_DIR="sdl-$SDL_VERSION"

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
    ;;
    *)
        exit -1
    ;;
esac

# cp -r "$TOP/$SDL_SOURCE_DIR/include" "$stage"

# mkdir -p "$stage/LICENSES"
# cp "$TOP/$OPENAL_SOURCE_DIR/COPYING" "$stage/LICENSES/openal.txt"

pass

