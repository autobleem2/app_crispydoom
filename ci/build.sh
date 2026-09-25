#!/usr/bin/env bash
# Builds Crispy Doom in the autobleem-build image (ghcr.io/autobleem2/autobleem-build) and packages it as three
# AutoBleem Apps, one per game, each with the same program:
#
#   Apps/doom/       Doom - the shareware DOOM1.WAD (id Software, freely distributable unmodified)
#   Apps/freedoom1/  Freedoom: Phase 1 (freedoom1.wad, BSD)
#   Apps/freedoom2/  Freedoom: Phase 2 (freedoom2.wad, BSD)
#
#   ci/build.sh native                    a host build (build_native/)
#   ci/build.sh psc|rpi|rpi64|pcusb|win   a target -> dist/<app>-<key>-<version>.zip for each of the three
#   ci/build.sh all                       every one of them
#
# upstream/crispy-doom and upstream/SDL_net are pinned submodules, never edited: each build copies them into
# build_<key>/ and applies patches/<name>/*.patch there (CLAUDE.md). SDL2 and SDL2_mixer are the launcher's
# (the console, Windows) or the system's (the Pis, the PC stick); SDL2_net is built here and carried in each
# package's lib/<key>/. The game data comes from our mirror, pinned by sha256.
#
# On the build server: docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src \
#                          ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD

APPS=(doom freedoom1 freedoom2)
VERSION="${AB_VERSION:-$(tr -d '\r' < VERSION)}"
JOBS="${JOBS:-$(nproc)}"
PSC=${AB_PSC_TOOLCHAIN:-/opt/psc}
MINGW_SDL2=${AB_MINGW_SDL2:-/opt/mingw-sdl2}
MIRROR="${AB_MIRROR_URL:-https://autobleem.retromenele.pl/mirror}"

banner() { printf '\n==== %s ====\n' "$*"; }

# ---------------------------------------------------------------------------------------------------------
# The game data, once, into build_data/
# ---------------------------------------------------------------------------------------------------------
fetch() { # fetch <url> <file> <sha256>
    [ -f "$2" ] && echo "$3  $2" | sha256sum -c --quiet - 2>/dev/null && return
    curl -fsSL -o "$2" "$1"
    echo "$3  $2" | sha256sum -c -
}

fetch_data() {
    mkdir -p build_data
    [ -f build_data/doom1.wad ] && [ -f build_data/freedoom1.wad ] && [ -f build_data/freedoom2.wad ] && return
    banner "data (our mirror)"
    fetch "$MIRROR/doom/doom1.wad" build_data/doom1.wad \
        1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771
    fetch "$MIRROR/freedoom/freedoom-0.13.0.zip" build_data/freedoom-0.13.0.zip \
        3f9b264f3e3ce503b4fb7f6bdcb1f419d93c7b546f4df3e874dd878db9688f59
    python3 - build_data <<'EOF'
import os, sys, zipfile
out = sys.argv[1]
with zipfile.ZipFile(os.path.join(out, "freedoom-0.13.0.zip")) as z:
    for name in ("freedoom1.wad", "freedoom2.wad", "COPYING.txt", "CREDITS.txt"):
        with open(os.path.join(out, name if name.endswith(".wad") else "freedoom-" + name), "wb") as f:
            f.write(z.read("freedoom-0.13.0/" + name))
EOF
}

# ---------------------------------------------------------------------------------------------------------
# One target. Each target_* sets:
#   CC, STRIP, CFLAGS_T           the compiler, its strip, the target's CPU flags
#   SYSTEM                        CMake's system name for a cross build ("" = a host build)
#   SDL_INC, SDL_LIB, SDL_MAIN    SDL2's headers, library and SDL2main
#   MIX_LIB                       SDL2_mixer's library (its header is next to SDL's)
#   SDL_CFLAGS, SDL_LIBS          the same for compiling SDL2_net by hand
# ---------------------------------------------------------------------------------------------------------
debian() { # debian <triplet>: the multiarch SDL2 of the image
    SDL_INC=/usr/include/SDL2
    SDL_LIB=/usr/lib/$1/libSDL2.so
    SDL_MAIN=/usr/lib/$1/libSDL2main.a
    MIX_LIB=/usr/lib/$1/libSDL2_mixer.so
    SDL_CFLAGS="-I$SDL_INC -D_REENTRANT"
    SDL_LIBS="-L/usr/lib/$1 -lSDL2"
}
target_native() {
    CC=gcc; STRIP=strip; CFLAGS_T="-O2"; SYSTEM=""; EXE=crispy-doom
    debian x86_64-linux-gnu
}
target_psc() {
    # the console's gcc-6 against a Debian Stretch sysroot, and the launcher's SDL2 2.0.14 family
    # (/opt/psc/sdl2), which is what /tmp/lib holds on the console
    CC="$PSC/bin/armv8-sony-linux-gnueabihf-gcc"; STRIP="$PSC/bin/armv8-sony-linux-gnueabihf-strip"
    CFLAGS_T="-mfloat-abi=hard -march=armv8-a -mfpu=neon-vfpv4 -O2"; SYSTEM=Linux; EXE=crispy-doom
    SDL_INC=$PSC/sdl2/include/SDL2
    SDL_LIB=$PSC/sdl2/lib/libSDL2.so
    SDL_MAIN=$PSC/sdl2/lib/libSDL2main.a
    MIX_LIB=$PSC/sdl2/lib/libSDL2_mixer.so
    SDL_CFLAGS="-I$SDL_INC -D_REENTRANT"
    SDL_LIBS="-L$PSC/sdl2/lib -lSDL2"
}
target_rpi() {
    CC=arm-linux-gnueabihf-gcc; STRIP=arm-linux-gnueabihf-strip
    CFLAGS_T="-mfloat-abi=hard -mfpu=neon-vfpv4 -march=armv7-a -O2"; SYSTEM=Linux; EXE=crispy-doom
    debian arm-linux-gnueabihf
}
target_rpi64() {
    CC=aarch64-linux-gnu-gcc; STRIP=aarch64-linux-gnu-strip
    CFLAGS_T="-march=armv8-a -O2"; SYSTEM=Linux; EXE=crispy-doom
    debian aarch64-linux-gnu
}
target_pcusb() {
    CC=i686-linux-gnu-gcc; STRIP=i686-linux-gnu-strip
    CFLAGS_T="-march=i686 -mtune=generic -D_FILE_OFFSET_BITS=64 -O2"; SYSTEM=Linux; EXE=crispy-doom
    debian i386-linux-gnu
}
target_win() {
    # the official SDL2 mingw development packages (/opt/mingw-sdl2): the DLLs the Windows product ships next
    # to the launcher, which puts its folder on an App's PATH
    CC=x86_64-w64-mingw32-gcc; STRIP=x86_64-w64-mingw32-strip
    CFLAGS_T="-O2"; SYSTEM=Windows; EXE=crispy-doom.exe
    SDL_INC=$MINGW_SDL2/include/SDL2
    SDL_LIB=$MINGW_SDL2/lib/libSDL2.dll.a
    SDL_MAIN=$MINGW_SDL2/lib/libSDL2main.a
    MIX_LIB=$MINGW_SDL2/lib/libSDL2_mixer.dll.a
    SDL_CFLAGS="-I$SDL_INC"
    SDL_LIBS="-L$MINGW_SDL2/lib -lSDL2"
}

build_sdlnet() { # build_sdlnet <dir>: SDL2_net by hand - four C files, the same way on every target
    local dir="$1" net=upstream/SDL_net flags=() libs=""
    mkdir -p "$dir/sdlnet/include"
    if [ "$SYSTEM" = Windows ]; then
        NETLIB=SDL2_net.dll
        flags=(-Wl,--out-implib,"$dir/sdlnet/libSDL2_net.dll.a")
        libs="-lws2_32 -liphlpapi"
        NET_LINK="$ROOT/$dir/sdlnet/libSDL2_net.dll.a"
    else
        NETLIB=libSDL2_net-2.0.so.0
        flags=(-fPIC -Wl,-soname,"$NETLIB")
        NET_LINK="$ROOT/$dir/sdlnet/$NETLIB"
    fi
    # shellcheck disable=SC2086
    "$CC" $CFLAGS_T -shared "${flags[@]}" -DBUILD_SDL -DDLL_EXPORT $SDL_CFLAGS -I"$net/include" -I"$net/src" \
        "$net/src/SDLnet.c" "$net/src/SDLnetTCP.c" "$net/src/SDLnetUDP.c" "$net/src/SDLnetselect.c" \
        -o "$dir/sdlnet/$NETLIB" $SDL_LIBS $libs
    cp "$net/include/SDL_net.h" "$dir/sdlnet/include/"
}

build_target() { # build_target <key>
    local key="$1" dir="build_$1"
    banner "$key ($dir)"
    "target_$key"

    rm -rf "$dir"
    mkdir -p "$dir"
    cp -r upstream/crispy-doom "$dir/src"
    rm -rf "$dir/src/.git"
    for p in patches/crispy-doom/*.patch; do
        [ -f "$p" ] || continue
        echo "patch: $p"
        patch -d "$dir/src" -p1 --no-backup-if-mismatch < "$p"
    done
    build_sdlnet "$dir"

    # Crispy's own find modules make the SDL targets from these cache variables, so nothing is searched
    # for (a cross build must never find the host's SDL); PNG, libsamplerate and FluidSynth stay off, so
    # the program needs nothing beyond the SDL2 family and SDL2_net
    local cross=()
    if [ -n "$SYSTEM" ]; then
        cross=(-DCMAKE_SYSTEM_NAME="$SYSTEM" -DCMAKE_C_COMPILER="$CC")
        [ "$SYSTEM" = Windows ] && cross+=(-DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres)
    fi
    cmake -S "$dir/src" -B "$dir/cmake" -G Ninja -DCMAKE_BUILD_TYPE=Release "${cross[@]}" \
        -DCMAKE_C_FLAGS="$CFLAGS_T" -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=OFF -DCMAKE_SKIP_RPATH=ON \
        -DSDL2_INCLUDE_DIR="$SDL_INC" -DSDL2_LIBRARY="$SDL_LIB" -DSDL2_MAIN_LIBRARY="$SDL_MAIN" \
        -DSDL2_MIXER_INCLUDE_DIR="$SDL_INC" -DSDL2_MIXER_LIBRARY="$MIX_LIB" \
        -DSDL2_NET_INCLUDE_DIR="$ROOT/$dir/sdlnet/include" -DSDL2_NET_LIBRARY="$NET_LINK" \
        -DCMAKE_DISABLE_FIND_PACKAGE_PNG=ON -DCMAKE_DISABLE_FIND_PACKAGE_SampleRate=ON \
        -DCMAKE_DISABLE_FIND_PACKAGE_FluidSynth=ON >/dev/null
    cmake --build "$dir/cmake" --target crispy-doom -j "$JOBS"

    local program="$dir/cmake/src/$EXE"
    "$STRIP" "$program"
    for app in "${APPS[@]}"; do
        stage_app "$dir" "$key" "$app" "$program"
    done
}

stage_app() { # stage_app <build dir> <key> <app> <program>
    local dir="$1" key="$2" app="$3" program="$4"
    local stage="$dir/Apps/$app"
    mkdir -p "$stage/bin/$key" "$stage/lib/$key" "$stage/savegames"
    cp "$program" "$stage/bin/$key/"
    cp "$dir/sdlnet/$NETLIB" "$stage/lib/$key/"
    "$STRIP" --strip-unneeded "$stage/lib/$key/$NETLIB"
    cp resources/common/default.cfg resources/common/crispy-doom.cfg "$stage/"
    cp resources/$app/app.ini resources/$app/readme.txt resources/$app/icon.png "$stage/"
    cp "$dir/src/COPYING.md" "$stage/COPYING-crispy-doom.md"
    touch "$stage/savegames/.keep"
    case "$app" in
        doom) cp build_data/doom1.wad "$stage/DOOM1.WAD" ;;
        freedoom1 | freedoom2)
            cp "build_data/$app.wad" "$stage/"
            cp build_data/freedoom-COPYING.txt "$stage/COPYING-freedoom.txt"
            cp build_data/freedoom-CREDITS.txt "$stage/CREDITS-freedoom.txt" ;;
    esac
    sed -i "s/^Version=.*/Version=$VERSION/" "$stage/app.ini"
}

package() { # package <key>
    local key="$1" dir="build_$1"
    mkdir -p dist
    for app in "${APPS[@]}"; do
        local zip="dist/$app-$key-$VERSION.zip"
        rm -f "$zip"
        (cd "$dir" && python3 - "$ROOT/$zip" "$app" <<'EOF'
import os, sys, zipfile
# every file under Apps/<app>, with its mode (the program stays executable where the filesystem keeps it)
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(os.path.join("Apps", sys.argv[2])):
        dirs.sort()
        for name in sorted(files):
            z.write(os.path.join(root, name))
EOF
        )
        ls -l "$zip"
    done
}

check() { # check <key>: the program is the platform's, and needs nothing we do not ship
    local key="$1" stage="build_$1/Apps/doom"
    case "$key" in
        psc)
            file "$stage/bin/psc/crispy-doom" | grep -q 'ELF 32-bit LSB.*ARM'
            bash tools/check_psc_binary.sh "$stage/bin/psc/crispy-doom" "$PSC"
            bash tools/check_psc_binary.sh "$stage/lib/psc/libSDL2_net-2.0.so.0" "$PSC" ;;
        rpi) file "$stage/bin/rpi/crispy-doom" | grep -q 'ELF 32-bit LSB.*ARM' ;;
        rpi64) file "$stage/bin/rpi64/crispy-doom" | grep -q 'ELF 64-bit LSB.*aarch64' ;;
        pcusb) file "$stage/bin/pcusb/crispy-doom" | grep -q 'ELF 32-bit LSB.*Intel 80386' ;;
        win) file "$stage/bin/win/crispy-doom.exe" | grep -q 'PE32+ executable.*x86-64' ;;
    esac
    bash tools/check_needed.sh "$key" "$stage"
}

build_native() {
    fetch_data
    build_target native
    "build_native/Apps/doom/bin/native/crispy-doom" -version | head -2 || true
}

build_one() { # build_one <key>
    fetch_data
    build_target "$1"
    check "$1"
    package "$1"
}

[ $# -gt 0 ] || { echo "usage: $0 native|psc|rpi|rpi64|pcusb|win|all" >&2; exit 2; }
for target in "$@"; do
    case "$target" in
        native) build_native ;;
        psc | rpi | rpi64 | pcusb | win) build_one "$target" ;;
        all) build_native; for k in psc rpi rpi64 pcusb win; do build_one "$k"; done ;;
        *) echo "unknown target: $target" >&2; exit 2 ;;
    esac
done
