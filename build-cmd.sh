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

        # DirectFB first.  There's a potential circular dependency in that
        # DirectFB can use SDL but that doesn't arise in our case.
        # Prevent .sos from re-exporting libz or libpng (which they
        # have done in the past).  Boost the various *FLAGS settings
        # so package includes are found and probed, not system libraries.
        # Similarly, pick up packages libraries.

        pushd "$TOP/$DIRECTFB_SOURCE_DIR"
            # Debug build of directfb    
            CFLAGS="-I"$ZLIB_INCLUDE" $opts -g" \
                CXXFLAGS="-I"$ZLIB_INCLUDE" $opts -g" \
                CPPFLAGS="$CPPFLAGS -I"$PNG_INCLUDE" -I"$ZLIB_INCLUDE"" \
                LDFLAGS="-Wl,--exclude-libs,libz:libpng16 -L"$stage/packages/lib/debug" $opts" \
                LIBPNG_CFLAGS="-I"$PNG_INCLUDE"" \
                LIBPNG_LIBS="-lpng16 -lz -lm" \
                ./configure --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include" \
                --with-pic --enable-static --enable-shared --enable-zlib --disable-freetype
            make V=1
            make install

            # clean the build tree
            # Would like to do this but this deletes files that are generated
            # by 'fluxcomp' and we don't have that installed anywhere so don't
            # scrub between builds.
            # make distclean

            # do release build of directfb  
            CFLAGS="-I"$ZLIB_INCLUDE" $opts -O3" \
                CXXFLAGS="-I"$ZLIB_INCLUDE" $opts -O3" \
                CPPFLAGS="$CPPFLAGS -I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE"" \
                LDFLAGS="-Wl,--exclude-libs,libz:libpng16 -L"$stage/packages/lib/release" $opts" \
                LIBPNG_CFLAGS="-I"$PNG_INCLUDE"" \
                LIBPNG_LIBS="-lpng16 -lz -lm" \
                ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include" \
                --with-pic --enable-static --enable-shared --enable-zlib --disable-freetype
            make V=1
            make install

            # clean the build tree
            # make distclean
        popd

        # SDL built last and using DirectFB as a 'package'.
        # With 1.2.15, configure needs to find the directfb-config program built
        # above.  If it doesn't find it, it will disable directfb support (though
        # this may be okay in practice).  We achieve that with PATH setting.
        # Otherwise, *FLAGS boosted to find package includes including directfb,
        # same for libraries though directfb-config will send the debug SDL build
        # into the release DirectFB staging area.

        pushd "$TOP/$SDL_SOURCE_DIR"
            # do debug build of sdl
            PATH="$stage"/bin/:"$PATH" \
                CFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" -I"$stage"/include/directfb/ $opts -O1 -g" \
                CXXFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" -I"$stage"/include/directfb/ $opts -O1 -g" \
                CPPFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" -I"$stage"/include/directfb/ $opts" \
                LDFLAGS="-L"$stage/packages/lib/debug" -L"$stage/lib/debug" $opts" \
                ./configure --target=i686-linux-gnu --with-pic --with-video-directfb \
                --prefix="$stage" --libdir="$stage/lib/debug" --includedir="$stage/include"
            make
            make install

            # clean the build tree
            make distclean

            # do release build of sdl
            PATH="$stage"/bin/:"$PATH" \
                CFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" -I"$stage"/include/directfb/ $opts -O3" \
                CXXFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" -I"$stage"/include/directfb/ $opts -O2" \
                CPPFLAGS="-I"$ZLIB_INCLUDE" -I"$PNG_INCLUDE" -I"$stage"/include/directfb/ $opts" \
                LDFLAGS="-L"$stage/packages/lib/release" -L"$stage/lib/release" $opts" \
                ./configure --target=i686-linux-gnu --with-pic --with-video-directfb \
                --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include"
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
mkdir -p "$stage"/docs/SDL/
cp -a "$TOP"/README.Linden "$stage"/docs/SDL/

pass

