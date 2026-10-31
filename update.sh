#!/usr/bin/env bash
# Music: build and install, or update to the newest release.
#
#   ./update.sh --here        Build THIS folder and install it for your user (into ~/.local).
#                             Run it once; after that the player's own "Update now" button works.
#   ./update.sh               Download the newest release from GitHub, build it here and install it.
#   ./update.sh --tag v0.6.1  Same, for one particular release.
#
# The player is built on your own computer (not downloaded as a binary), so it always matches the
# Qt, mpv and TagLib versions your system has. Lines starting "STEP:" are what the player shows.
#
# Settings (environment):  MUSICPLAYER_REPO=owner/repo   MUSICPLAYER_PREFIX=~/.local

REPO="${MUSICPLAYER_REPO:-whozdgt/Paraplay}"
PREFIX="${MUSICPLAYER_PREFIX:-$HOME/.local}"

WORK=""; LOG=""
step() { echo "STEP: $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
cleanup() { [ -z "$WORK" ] || rm -rf "$WORK"; [ -z "$LOG" ] || rm -f "$LOG"; }

main() {
    set -euo pipefail
    local here=0 tag="" src jobs build
    trap cleanup EXIT
    LOG="$(mktemp)"

    while [ $# -gt 0 ]; do
        case "$1" in
            --here) here=1 ;;
            --tag) shift; tag="${1:-}"; [ -n "$tag" ] || die "--tag needs a version, e.g. --tag v0.6.1" ;;
            -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; return 0 ;;
            *) die "Unknown option: $1 (try --help)" ;;
        esac
        shift
    done

    step "Checking the build tools"
    local missing=()
    for c in cmake pkg-config install; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
    command -v g++ >/dev/null 2>&1 || command -v c++ >/dev/null 2>&1 || missing+=("a C++ compiler")
    if [ "$here" = 0 ]; then
        for c in curl tar; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
    fi
    if [ ${#missing[@]} -gt 0 ]; then
        die "Missing: ${missing[*]}. On CachyOS/Arch: sudo pacman -S --needed base-devel cmake qt6-base qt6-declarative qt6-wayland mpv taglib curl"
    fi
    pkg-config --exists mpv taglib || die "mpv or taglib development files not found. On CachyOS/Arch: sudo pacman -S --needed mpv taglib"

    jobs=$(( $(nproc) / 2 )); [ "$jobs" -ge 1 ] || jobs=1

    if [ "$here" = 1 ]; then
        src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
        [ -f "$src/CMakeLists.txt" ] || die "--here must be run from the project folder (the one with CMakeLists.txt)."
        build="$src/build"
        tag="this folder"
    else
        case "$REPO" in OWNER/*|"") die "This copy doesn't know which GitHub repository to update from. Run with MUSICPLAYER_REPO=owner/repo." ;; esac
        if [ -z "$tag" ]; then
            step "Looking for the newest version"
            tag=$(curl -fsSL --max-time 20 -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/$REPO/releases/latest" \
                | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1) || true
            [ -n "$tag" ] || die "Couldn't find a published release for $REPO."
        fi
        case "$tag" in *[!A-Za-z0-9._-]*|"") die "That doesn't look like a version tag: $tag" ;; esac
        local cache="${XDG_CACHE_HOME:-$HOME/.cache}/musicplayer-update"
        mkdir -p "$cache"
        WORK="$(mktemp -d "$cache/work.XXXXXX")"
        step "Downloading $tag"
        curl -fsSL --max-time 300 -o "$WORK/src.tar.gz" "https://github.com/$REPO/archive/refs/tags/$tag.tar.gz" \
            || die "Couldn't download $tag from GitHub."
        mkdir -p "$WORK/src"
        tar xzf "$WORK/src.tar.gz" --strip-components=1 -m -C "$WORK/src"
        src="$WORK/src"
        build="$WORK/build"
        [ -f "$src/CMakeLists.txt" ] || die "The download didn't contain the player's source."
    fi

    step "Building $tag (a few minutes; the music keeps playing)"
    cmake -S "$src" -B "$build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" >"$LOG" 2>&1 \
        || { tail -n 15 "$LOG"; die "CMake could not configure the project (see above)."; }
    cmake --build "$build" -j"$jobs" >>"$LOG" 2>&1 \
        || { tail -n 25 "$LOG"; die "The build failed (see above)."; }

    step "Installing into $PREFIX"
    # `install` replaces the file instead of writing into it, so a running copy is never disturbed.
    install -Dm755 "$build/musicplayer" "$PREFIX/bin/musicplayer"
    install -Dm755 "$src/update.sh" "$PREFIX/share/musicplayer/musicplayer-update"
    if [ -f "$src/packaging/musicplayer.desktop" ]; then
        local desk; desk="$(mktemp)"
        sed "s|^Exec=.*|Exec=$PREFIX/bin/musicplayer|" "$src/packaging/musicplayer.desktop" >"$desk"
        install -Dm644 "$desk" "$PREFIX/share/applications/musicplayer.desktop"
        rm -f "$desk"
        command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$PREFIX/share/applications" >/dev/null 2>&1 || true
    fi

    step "Checking the new version"
    QT_QPA_PLATFORM=offscreen "$PREFIX/bin/musicplayer" --version 2>/dev/null | tail -n 1 || true

    step "Done"
    case ":$PATH:" in
        *":$PREFIX/bin:"*) ;;
        *) echo "Note: $PREFIX/bin is not on your PATH. Start the player from the app launcher, or run $PREFIX/bin/musicplayer" ;;
    esac
    return 0
}

# The whole script is read before it runs, so replacing this file while it is running is safe.
main "$@"
exit $?
