#!/usr/bin/env bash

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# bleat on references to undefined shell variables
set -u

TOP="$(dirname "$0")"

DIRECTFB_SOURCE_DIR="DirectFB"
DIRECTFB_VERSION="$(sed -n -E '/%define version ([0-9.]+)/s//\1/p' "$TOP/$DIRECTFB_SOURCE_DIR/directfb.spec")"
SDL_SOURCE_DIR="SDL"
SDL_VERSION=$(sed -n -e 's/^Version: //p' "$TOP/$SDL_SOURCE_DIR/SDL.spec")

if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

stage="$(pwd)"
ZLIB_INCLUDE="${stage}"/packages/include/zlib
PNG_INCLUDE="${stage}"/packages/include/libpng16

[ -f "$ZLIB_INCLUDE"/zlib.h ] || fail "You haven't installed the zlib package yet."
[ -f "$PNG_INCLUDE"/png.h ] || fail "You haven't installed the libpng package yet."

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$AUTOBUILD" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

# Restore all .sos
restore_sos ()
{
    for solib in "${stage}"/packages/lib/release/lib*.so*.disable; do 
        if [ -f "$solib" ]; then
            mv -f "$solib" "${solib%.disable}"
        fi
    done
}

case "$AUTOBUILD_PLATFORM" in

    linux*)
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

        # Default target per autobuild --address-size
        opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE}"

        # Handle any deliberate platform targeting
        if [ -z "${TARGET_CPPFLAGS:-}" ]; then
            # Remove sysroot contamination from build environment
            unset CPPFLAGS
        else
            # Incorporate special pre-processing flags
            export CPPFLAGS="$TARGET_CPPFLAGS"
        fi
            
        # Force static linkage to libz by moving .sos out of the way
        # (Libz is only packaging statics right now but keep this working.)
        trap restore_sos EXIT
        for solib in "${stage}"/packages/lib/release/libz.so*; do
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
            # do release build of directfb  
            CFLAGS="-I$ZLIB_INCLUDE $opts" \
                CXXFLAGS="-I$ZLIB_INCLUDE $opts" \
                CPPFLAGS="${CPPFLAGS:-} -I$ZLIB_INCLUDE -I$PNG_INCLUDE" \
                LDFLAGS="-Wl,--exclude-libs,libz:libpng16 -L$stage/packages/lib/release -Wl,--build-id -Wl,-rpath,'\$\$ORIGIN:\$\$ORIGIN/../lib' $opts" \
                LIBPNG_CFLAGS="-I$PNG_INCLUDE" \
                LIBPNG_LIBS="-lpng16 -lz -lm" \
                ./configure --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include" \
                --with-pic --enable-static --enable-shared --enable-zlib --disable-freetype
            make -j `nproc` V=1
            make install

            # clean the build tree
            # Would like to do this but this deletes files that are generated
            # by 'fluxcomp' and we don't have that installed anywhere so don't
            # scrub between builds.
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
            # do release build of sdl
            PATH="$stage/bin/:$PATH" \
                CFLAGS="-I$ZLIB_INCLUDE -I$PNG_INCLUDE -I$stage/include/directfb/ $opts" \
                CXXFLAGS="-I$ZLIB_INCLUDE -I$PNG_INCLUDE -I$stage/include/directfb/ $opts" \
                CPPFLAGS="-I$ZLIB_INCLUDE -I$PNG_INCLUDE -I$stage/include/directfb/ $opts" \
                LDFLAGS="-L$stage/packages/lib/release -L$stage/lib/release -Wl,--build-id -Wl,-rpath,'\$\$ORIGIN:\$\$ORIGIN/../lib' $opts" \
                ./configure --target=i686-linux-gnu --with-pic --with-video-directfb \
                --prefix="$stage" --libdir="$stage/lib/release" --includedir="$stage/include"
            make -j `nproc`
            make install

            # clean the build tree
            make distclean
        popd
    ;;

    *)
        echo "Unrecognized platform $AUTOBUILD_PLATFORM" 1>&2
        exit -1
    ;;
esac


mkdir -p "$stage/LICENSES"
cp "$TOP/$SDL_SOURCE_DIR/COPYING" "$stage/LICENSES/SDL.txt"
mkdir -p "$stage"/docs/SDL/
cp -a "$TOP"/README.Linden "$stage"/docs/SDL/
echo "$SDL_VERSION" > "$stage/VERSION.txt"
