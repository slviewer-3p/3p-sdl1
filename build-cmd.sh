#!/bin/bash

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

TOP="$(dirname "$0")"

SDL_VERSION="1.2.15"
SDL_SOURCE_DIR="SDL"
DIRECTFB_VERSION="1.7.1"
DIRECTFB_SOURCE_DIR="DirectFB"


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
ZLIB_INCLUDE="${stage}"/packages/include/zlib
PNG_INCLUDE="${stage}"/packages/include/libpng16

[ -f "$ZLIB_INCLUDE"/zlib.h ] || fail "You haven't installed the zlib package yet."
[ -f "$PNG_INCLUDE"/png.h ] || fail "You haven't installed the libpng package yet."

# Restore all .sos
restore_sos ()
{
    for solib in "${stage}"/packages/lib/{debug,release}/lib*.so*.disable; do 
        if [ -f "$solib" ]; then
            mv -f "$solib" "${solib%.disable}"
        fi
    done
}

case "$AUTOBUILD_PLATFORM" in

    "linux")
        # Linux build environment at Linden comes pre-polluted with stuff that can
        # seriously damage 3rd-party builds.  Environmental garbage you can expect
        # includes:
        #
        #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
        #    DISTCC_LOCATION            top            branch      CC
        #    DISTCC_HOSTS               build_name     suffix      CXX
        #    LSDISTCC_ARGS              repo           prefix      CFLAGS
        #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
        #
        # So, clear out bits that shouldn't affect our configure-directed build
        # but which do nonetheless.
        #
        # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

        # Prefer gcc-4.6 if available.
        if [[ -x /usr/bin/gcc-4.6 && -x /usr/bin/g++-4.6 ]]; then
            export CC=/usr/bin/gcc-4.6
            export CXX=/usr/bin/g++-4.6
        fi

        # Default target to 32-bit
        opts="${TARGET_OPTS:--m32}"

        # Handle any deliberate platform targeting
        if [ -z "$TARGET_CPPFLAGS" ]; then
            # Remove sysroot contamination from build environment
            unset CPPFLAGS
        else
            # Incorporate special pre-processing flags
            export CPPFLAGS="$TARGET_CPPFLAGS"
        fi
            
        # Force static linkage to libz by moving .sos out of the way
        # (Libz is only packaging statics right now but keep this working.)
        trap restore_sos EXIT
        for solib in "${stage}"/packages/lib/{debug,release}/libz.so*; do
            if [ -f "$solib" ]; then
                mv -f "$solib" "$solib".disable
            fi
        done

        pushd "$TOP/$DIRECTFB_SOURCE_DIR"
            # do debug build of directfb    
            LDFLAGS="-L"$stage/packages/lib/debug" $opts" \
                CFLAGS="-I"$ZLIB_INCLUDE" $opts -g" \
                CXXFLAGS="-I"$ZLIB_INCLUDE" $opts -g" \
                LIBPNG_CFLAGS="-I"$PNG_INCLUDE"" LIBPNG_LIBS="-lpng -lz -lm" \
                ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include" \
                --enable-static --enable-shared --enable-zlib --disable-freetype
            make V=1
            make install

            # clean the build tree
            # Would like to do this but this deletes files that are generated
            # by 'fluxcomp' and we don't have that installed anywhere so don't
            # scrub between builds.
            # make distclean

            # do release build of directfb  
            LDFLAGS="-L"$stage/packages/lib/release" $opts" \
                CFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" $opts -O3" \
                CXXFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" $opts -O3" \
                LIBPNG_CFLAGS="-I"$PNG_INCLUDE"" LIBPNG_LIBS="-lpng -lz -lm" \
                ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include" \
                --enable-static --enable-shared --enable-zlib --disable-freetype
            make V=1
            make install

            # clean the build tree
            # make distclean
        popd
        pushd "$TOP/$SDL_SOURCE_DIR"
            # do debug build of sdl
            LDFLAGS="-L"$stage/packages/lib/debug" -L"$stage/lib/debug" $opts" \
                CFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" $opts -O1 -g" \
                CXXFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" $opts -O1 -g" \
                ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include" \
                --target=i686-linux-gnu
            make
            make install

            # clean the build tree
            make distclean

            # do release build of sdl
            LDFLAGS="-L"$stage/packages/lib/release" -L"$stage/lib/release" $opts" \
                CFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" $opts -O3" \
                CXXFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" $opts -O2" \
                ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include" \
                --target=i686-linux-gnu
            make
            make install

            # clean the build tree
            make distclean
        popd
    ;;

    *)
        exit -1
    ;;
esac


mkdir -p "$stage/LICENSES"
cp "$TOP/$SDL_SOURCE_DIR/COPYING" "$stage/LICENSES/SDL.txt"

pass

