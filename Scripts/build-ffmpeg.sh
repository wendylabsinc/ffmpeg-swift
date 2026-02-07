#!/usr/bin/env bash
#
# build-ffmpeg.sh — Build FFmpeg static libraries and assemble an SE-0482 artifact bundle.
#
# Usage:
#   ./Scripts/build-ffmpeg.sh [--version 7.1] [--platforms macos-arm64,macos-x86_64,linux-x86_64,linux-aarch64,android-arm64] [--zip]
#
# The script will:
#   1. Download FFmpeg source (if not cached)
#   2. Build for each requested platform
#   3. Merge per-library .a files into a single libcffmpeg.a
#   4. Copy headers preserving directory structure
#   5. Generate per-platform module.modulemap
#   6. Write info.json
#   7. Optionally zip for release
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/ffmpeg-build"
BUNDLE_DIR="$ROOT_DIR/CFFmpeg.artifactbundle"

FFMPEG_VERSION="7.1"
LAME_VERSION="3.100"
PLATFORMS=""
DO_ZIP=false

# ---------- CLI args ----------
while [[ $# -gt 0 ]]; do
    case $1 in
        --version) FFMPEG_VERSION="$2"; shift 2 ;;
        --platforms) PLATFORMS="$2"; shift 2 ;;
        --zip) DO_ZIP=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Default platforms: detect current host
if [[ -z "$PLATFORMS" ]]; then
    ARCH="$(uname -m)"
    OS="$(uname -s)"
    if [[ "$OS" == "Darwin" ]]; then
        if [[ "$ARCH" == "arm64" ]]; then
            PLATFORMS="macos-arm64"
        else
            PLATFORMS="macos-x86_64"
        fi
    elif [[ "$OS" == "Linux" ]]; then
        if [[ "$ARCH" == "aarch64" ]]; then
            PLATFORMS="linux-aarch64"
        else
            PLATFORMS="linux-x86_64"
        fi
    else
        echo "Unsupported OS: $OS"
        exit 1
    fi
fi

IFS=',' read -ra PLATFORM_ARRAY <<< "$PLATFORMS"

FFMPEG_LIBS=(libavutil libavcodec libavformat libavfilter libswscale libswresample libpostproc)
EXTRA_STATIC_LIBS=(libmp3lame)

# ---------- Helpers ----------

download_ffmpeg() {
    local tarball="ffmpeg-${FFMPEG_VERSION}.tar.xz"
    local url="https://ffmpeg.org/releases/${tarball}"
    local src_dir="$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"

    if [[ -d "$src_dir" ]]; then
        echo "==> FFmpeg source already exists at $src_dir"
        return
    fi

    mkdir -p "$BUILD_DIR"
    echo "==> Downloading FFmpeg $FFMPEG_VERSION ..."
    curl -L -o "$BUILD_DIR/$tarball" "$url"
    echo "==> Extracting ..."
    tar xf "$BUILD_DIR/$tarball" -C "$BUILD_DIR"
}

download_lame() {
    local tarball="lame-${LAME_VERSION}.tar.gz"
    local url="https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/${tarball}"
    local src_dir="$BUILD_DIR/lame-${LAME_VERSION}"

    if [[ -d "$src_dir" ]]; then
        echo "==> LAME source already exists at $src_dir"
        return
    fi

    mkdir -p "$BUILD_DIR"
    echo "==> Downloading LAME ${LAME_VERSION} ..."
    curl -L -o "$BUILD_DIR/$tarball" "$url"
    echo "==> Extracting ..."
    tar xf "$BUILD_DIR/$tarball" -C "$BUILD_DIR"
}

write_lame_pkgconfig() {
    local prefix="$1"
    local pc_dir="$prefix/lib/pkgconfig"
    mkdir -p "$pc_dir"
    cat > "$pc_dir/libmp3lame.pc" <<EOF
prefix=$prefix
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libmp3lame
Description: LAME MP3 encoder
Version: ${LAME_VERSION}
Libs: -L\${libdir} -lmp3lame
Cflags: -I\${includedir}
EOF
}

common_configure_flags() {
    echo "\
        --enable-static \
        --disable-shared \
        --enable-pic \
        --disable-programs \
        --disable-doc \
        --disable-autodetect \
        --disable-debug \
        --enable-gpl \
        --enable-version3 \
        --enable-libmp3lame \
        --pkg-config-flags=--static \
        --disable-network \
        --disable-iconv \
        --disable-securetransport \
        --disable-xlib \
        --disable-libxcb \
        --disable-sdl2 \
        --disable-vulkan \
        --disable-vaapi \
        --disable-vdpau \
        --disable-d3d11va \
        --disable-dxva2 \
        --disable-cuda \
        --disable-cuvid \
        --disable-nvenc \
        --disable-nvdec"
}

build_lame_macos() {
    local arch="$1"  # arm64 or x86_64
    local platform_tag="macos-${arch}"
    local src_dir="$BUILD_DIR/lame-${LAME_VERSION}"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"
    local build_work="$BUILD_DIR/build-${platform_tag}-lame"

    if [[ -f "$build_prefix/lib/libmp3lame.a" ]]; then
        echo "==> $platform_tag libmp3lame already built, skipping"
        return
    fi

    echo "==> Building LAME for $platform_tag ..."
    mkdir -p "$build_work"

    local host="x86_64-apple-darwin"
    if [[ "$arch" == "arm64" ]]; then
        host="aarch64-apple-darwin"
    fi

    cd "$build_work"
    CC="clang -arch $arch" \
    CFLAGS="-arch $arch -mmacosx-version-min=14.0 -fPIC" \
    LDFLAGS="-arch $arch -mmacosx-version-min=14.0" \
    "$src_dir/configure" \
        --prefix="$build_prefix" \
        --disable-shared \
        --enable-static \
        --disable-frontend \
        --host="$host"

    make -j"$(sysctl -n hw.ncpu)"
    make install
    write_lame_pkgconfig "$build_prefix"
    cd "$ROOT_DIR"
}

build_lame_linux_native() {
    local arch="$1"  # x86_64 or aarch64
    local platform_tag="linux-${arch}"
    local src_dir="$BUILD_DIR/lame-${LAME_VERSION}"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"
    local build_work="$BUILD_DIR/build-${platform_tag}-lame"

    if [[ -f "$build_prefix/lib/libmp3lame.a" ]]; then
        echo "==> $platform_tag libmp3lame already built, skipping"
        return
    fi

    echo "==> Building LAME for $platform_tag ..."
    mkdir -p "$build_work"

    local host="x86_64-linux-gnu"
    if [[ "$arch" == "aarch64" ]]; then
        host="aarch64-linux-gnu"
    fi

    cd "$build_work"
    CFLAGS="-fPIC" \
    "$src_dir/configure" \
        --prefix="$build_prefix" \
        --disable-shared \
        --enable-static \
        --disable-frontend \
        --host="$host"

    local jobs="1"
    if command -v nproc >/dev/null 2>&1; then
        jobs="$(nproc)"
    else
        jobs="$(sysctl -n hw.ncpu)"
    fi
    make -j"$jobs"
    make install
    write_lame_pkgconfig "$build_prefix"
    cd "$ROOT_DIR"
}

build_lame_android_arm64() {
    local platform_tag="android-arm64"
    local src_dir="$BUILD_DIR/lame-${LAME_VERSION}"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"
    local build_work="$BUILD_DIR/build-${platform_tag}-lame"

    if [[ -f "$build_prefix/lib/libmp3lame.a" ]]; then
        echo "==> $platform_tag libmp3lame already built, skipping"
        return
    fi

    if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
        if [[ -n "${ANDROID_SDK_ROOT:-}" && -d "${ANDROID_SDK_ROOT}/ndk" ]]; then
            ANDROID_NDK_HOME="$(ls -d "${ANDROID_SDK_ROOT}"/ndk/* | sort -V | tail -n1)"
        else
            echo "ANDROID_NDK_HOME not set. Please set it to your NDK path."
            exit 1
        fi
    fi

    local host_os="$(uname -s)"
    local host_arch="$(uname -m)"
    local prebuilt="linux-x86_64"
    if [[ "$host_os" == "Darwin" ]]; then
        if [[ "$host_arch" == "arm64" ]]; then
            prebuilt="darwin-arm64"
        else
            prebuilt="darwin-x86_64"
        fi
    fi
    if [[ ! -d "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${prebuilt}" && -d "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64" ]]; then
        prebuilt="darwin-x86_64"
    fi

    local toolchain="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${prebuilt}"
    if [[ ! -d "$toolchain" ]]; then
        echo "NDK toolchain not found: $toolchain"
        exit 1
    fi

    local api_level="${ANDROID_API_LEVEL:-21}"
    local sysroot="${toolchain}/sysroot"
    local cc="${toolchain}/bin/aarch64-linux-android${api_level}-clang"
    local ar="${toolchain}/bin/llvm-ar"
    local ranlib="${toolchain}/bin/llvm-ranlib"

    echo "==> Building LAME for $platform_tag ..."
    mkdir -p "$build_work"

    cd "$build_work"
    CC="$cc" \
    AR="$ar" \
    RANLIB="$ranlib" \
    CFLAGS="--sysroot=${sysroot} -fPIC" \
    LDFLAGS="--sysroot=${sysroot}" \
    "$src_dir/configure" \
        --prefix="$build_prefix" \
        --disable-shared \
        --enable-static \
        --disable-frontend \
        --host="aarch64-linux-android"

    local jobs="1"
    if command -v nproc >/dev/null 2>&1; then
        jobs="$(nproc)"
    else
        jobs="$(sysctl -n hw.ncpu)"
    fi
    make -j"$jobs"
    make install
    write_lame_pkgconfig "$build_prefix"
    cd "$ROOT_DIR"
}

build_macos() {
    local arch="$1"  # arm64 or x86_64
    local platform_tag="macos-${arch}"
    local src_dir="$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"
    local build_work="$BUILD_DIR/build-${platform_tag}"

    if [[ -d "$build_prefix/lib" ]]; then
        echo "==> $platform_tag already built, skipping"
        return
    fi

    echo "==> Building FFmpeg for $platform_tag ..."
    mkdir -p "$build_work"
    build_lame_macos "$arch"

    local extra_flags=""
    if [[ "$arch" == "arm64" ]]; then
        extra_flags="--enable-neon"
    else
        extra_flags="--disable-x86asm"
    fi

    # macOS: enable VideoToolbox + CoreMedia + AudioToolbox
    local macos_flags="\
        --enable-videotoolbox \
        --enable-audiotoolbox"

    cd "$build_work"
    PKG_CONFIG_PATH="$build_prefix/lib/pkgconfig" \
    "$src_dir/configure" \
        --prefix="$build_prefix" \
        --arch="$arch" \
        --target-os=darwin \
        --cc="clang -arch $arch" \
        --extra-cflags="-arch $arch -mmacosx-version-min=14.0 -I${build_prefix}/include" \
        --extra-ldflags="-arch $arch -mmacosx-version-min=14.0 -L${build_prefix}/lib" \
        $(common_configure_flags) \
        $macos_flags \
        $extra_flags

    make -j"$(sysctl -n hw.ncpu)"
    make install
    cd "$ROOT_DIR"
}

build_linux_native() {
    local arch="$1"  # x86_64 or aarch64
    local platform_tag="linux-${arch}"
    local src_dir="$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"
    local build_work="$BUILD_DIR/build-${platform_tag}"

    if [[ -d "$build_prefix/lib" ]]; then
        echo "==> $platform_tag already built, skipping"
        return
    fi

    echo "==> Building FFmpeg for $platform_tag (native) ..."
    mkdir -p "$build_work"
    build_lame_linux_native "$arch"

    local extra_flags=""
    if [[ "$arch" == "aarch64" ]]; then
        extra_flags="--enable-neon"
    fi

    cd "$build_work"
    PKG_CONFIG_PATH="$build_prefix/lib/pkgconfig" \
    "$src_dir/configure" \
        --prefix="$build_prefix" \
        --arch="$arch" \
        --target-os=linux \
        --extra-cflags="-I${build_prefix}/include" \
        --extra-ldflags="-L${build_prefix}/lib" \
        $(common_configure_flags) \
        $extra_flags

    make -j"$(nproc)"
    make install
    cd "$ROOT_DIR"
}

build_linux_docker() {
    local arch="$1"  # x86_64 or aarch64
    local platform_tag="linux-${arch}"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"

    if [[ -d "$build_prefix/lib" ]]; then
        echo "==> $platform_tag already built, skipping"
        return
    fi

    echo "==> Building FFmpeg for $platform_tag (via Docker) ..."

    local docker_arch="$arch"
    local docker_platform="linux/amd64"
    if [[ "$arch" == "aarch64" ]]; then
        docker_platform="linux/arm64"
    fi

    # Create a temporary Dockerfile
    local dockerfile="$BUILD_DIR/Dockerfile.${platform_tag}"
    cat > "$dockerfile" <<'DOCKERFILE'
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y build-essential yasm nasm pkg-config curl xz-utils
ARG FFMPEG_VERSION=7.1
ARG LAME_VERSION=3.100
ARG TARGET_ARCH=x86_64
WORKDIR /build
RUN curl -L "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" | tar xJ
RUN curl -L "https://downloads.sourceforge.net/project/lame/lame/${LAME_VERSION}/lame-${LAME_VERSION}.tar.gz" | tar xz
WORKDIR /build/lame-${LAME_VERSION}
RUN ./configure \
    --prefix=/install \
    --disable-shared \
    --enable-static \
    --disable-frontend \
    --host=${TARGET_ARCH}-linux-gnu && \
    make -j$(nproc) && \
    make install && \
    mkdir -p /install/lib/pkgconfig && \
    cat > /install/lib/pkgconfig/libmp3lame.pc <<EOF
prefix=/install
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libmp3lame
Description: LAME MP3 encoder
Version: ${LAME_VERSION}
Libs: -L\${libdir} -lmp3lame
Cflags: -I\${includedir}
EOF
WORKDIR /build/ffmpeg-${FFMPEG_VERSION}
ENV PKG_CONFIG_PATH=/install/lib/pkgconfig
RUN ./configure \
    --prefix=/install \
    --arch=${TARGET_ARCH} \
    --target-os=linux \
    --enable-static \
    --disable-shared \
    --enable-pic \
    --disable-programs \
    --disable-doc \
    --disable-autodetect \
    --disable-debug \
    --enable-gpl \
    --enable-version3 \
    --enable-libmp3lame \
    --pkg-config-flags=--static \
    --extra-cflags=-I/install/include \
    --extra-ldflags=-L/install/lib \
    --disable-network \
    --disable-iconv \
    --disable-xlib \
    --disable-libxcb \
    --disable-sdl2 \
    --disable-vulkan \
    --disable-vaapi \
    --disable-vdpau \
    --disable-d3d11va \
    --disable-dxva2 \
    --disable-cuda \
    --disable-cuvid \
    --disable-nvenc \
    --disable-nvdec && \
    make -j$(nproc) && \
    make install
DOCKERFILE

    docker build \
        --platform "$docker_platform" \
        --build-arg "FFMPEG_VERSION=$FFMPEG_VERSION" \
        --build-arg "LAME_VERSION=$LAME_VERSION" \
        --build-arg "TARGET_ARCH=$arch" \
        -t "ffmpeg-build-${platform_tag}" \
        -f "$dockerfile" \
        "$BUILD_DIR"

    mkdir -p "$build_prefix"
    local container_id
    container_id=$(docker create --platform "$docker_platform" "ffmpeg-build-${platform_tag}")
    docker cp "$container_id:/install/." "$build_prefix/"
    docker rm "$container_id"
}

build_android_arm64() {
    local platform_tag="android-arm64"
    local src_dir="$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"
    local build_work="$BUILD_DIR/build-${platform_tag}"

    if [[ -d "$build_prefix/lib" ]]; then
        echo "==> $platform_tag already built, skipping"
        return
    fi

    if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
        if [[ -n "${ANDROID_SDK_ROOT:-}" && -d "${ANDROID_SDK_ROOT}/ndk" ]]; then
            ANDROID_NDK_HOME="$(ls -d "${ANDROID_SDK_ROOT}"/ndk/* | sort -V | tail -n1)"
        else
            echo "ANDROID_NDK_HOME not set. Please set it to your NDK path."
            exit 1
        fi
    fi

    local host_os="$(uname -s)"
    local host_arch="$(uname -m)"
    local prebuilt="linux-x86_64"
    if [[ "$host_os" == "Darwin" ]]; then
        if [[ "$host_arch" == "arm64" ]]; then
            prebuilt="darwin-arm64"
        else
            prebuilt="darwin-x86_64"
        fi
    fi
    if [[ ! -d "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${prebuilt}" && -d "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64" ]]; then
        prebuilt="darwin-x86_64"
    fi

    local toolchain="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${prebuilt}"
    if [[ ! -d "$toolchain" ]]; then
        echo "NDK toolchain not found: $toolchain"
        exit 1
    fi

    local api_level="${ANDROID_API_LEVEL:-21}"
    local sysroot="${toolchain}/sysroot"
    local cc="${toolchain}/bin/aarch64-linux-android${api_level}-clang"
    local cxx="${toolchain}/bin/aarch64-linux-android${api_level}-clang++"
    local ar="${toolchain}/bin/llvm-ar"
    local ranlib="${toolchain}/bin/llvm-ranlib"
    local strip="${toolchain}/bin/llvm-strip"

    echo "==> Building FFmpeg for $platform_tag ..."
    mkdir -p "$build_work"
    build_lame_android_arm64

    cd "$build_work"
    PATH="${toolchain}/bin:${PATH}" \
    PKG_CONFIG_PATH="$build_prefix/lib/pkgconfig" \
    "$src_dir/configure" \
        --prefix="$build_prefix" \
        --arch=aarch64 \
        --target-os=android \
        --enable-cross-compile \
        --cc="$cc" \
        --cxx="$cxx" \
        --ar="$ar" \
        --ranlib="$ranlib" \
        --strip="$strip" \
        --sysroot="$sysroot" \
        --extra-cflags="--sysroot=${sysroot} -fPIC -I${build_prefix}/include" \
        --extra-ldflags="--sysroot=${sysroot} -L${build_prefix}/lib" \
        $(common_configure_flags) \
        --enable-neon

    make -j"$(nproc)"
    make install
    cd "$ROOT_DIR"
}

merge_static_libs() {
    local platform_tag="$1"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"
    local out_dir="$BUNDLE_DIR/${platform_tag}"
    local merged_lib="$out_dir/libcffmpeg.a"

    mkdir -p "$out_dir"

    local lib_paths=()
    for lib in "${FFMPEG_LIBS[@]}"; do
        local lib_file="$build_prefix/lib/${lib}.a"
        if [[ -f "$lib_file" ]]; then
            lib_paths+=("$lib_file")
        else
            echo "WARNING: $lib_file not found, skipping"
        fi
    done

    for lib in "${EXTRA_STATIC_LIBS[@]}"; do
        local lib_file="$build_prefix/lib/${lib}.a"
        if [[ -f "$lib_file" ]]; then
            lib_paths+=("$lib_file")
        fi
    done

    if [[ "${#lib_paths[@]}" -eq 0 ]]; then
        echo "ERROR: No libraries found for $platform_tag"
        exit 1
    fi

    echo "==> Merging ${#lib_paths[@]} libraries into $merged_lib ..."

    if [[ "$platform_tag" == macos-* ]]; then
        libtool -static -o "$merged_lib" "${lib_paths[@]}"
    else
        # Use MRI script with llvm-ar/gnu-ar for non-macOS archives (ELF/Android).
        local ar_tool
        ar_tool="$(xcrun --find llvm-ar 2>/dev/null || command -v llvm-ar || command -v ar)"
        local mri_script="$BUILD_DIR/merge-${platform_tag}.mri"
        echo "CREATE $merged_lib" > "$mri_script"
        for lib in "${lib_paths[@]}"; do
            echo "ADDLIB $lib" >> "$mri_script"
        done
        echo "SAVE" >> "$mri_script"
        echo "END" >> "$mri_script"
        "$ar_tool" -M < "$mri_script"
    fi
}

copy_headers() {
    local platform_tag="$1"
    local build_prefix="$BUILD_DIR/install-${platform_tag}"
    local include_dir="$BUNDLE_DIR/${platform_tag}/include"

    echo "==> Copying headers for $platform_tag ..."
    mkdir -p "$include_dir"

    for lib in "${FFMPEG_LIBS[@]}"; do
        local src_hdr="$build_prefix/include/${lib}"
        if [[ -d "$src_hdr" ]]; then
            cp -R "$src_hdr" "$include_dir/"
        fi
    done
}

generate_modulemap() {
    local platform_tag="$1"
    local include_dir="$BUNDLE_DIR/${platform_tag}/include"
    local modulemap="$include_dir/module.modulemap"
    local is_macos=false
    if [[ "$platform_tag" == macos-* ]]; then
        is_macos=true
    fi

    echo "==> Generating module.modulemap for $platform_tag ..."

    cat > "$modulemap" <<'MODULEMAP_HEAD'
module CFFmpeg {
    // libavutil
    header "libavutil/avutil.h"
    header "libavutil/opt.h"
    header "libavutil/dict.h"
    header "libavutil/log.h"
    header "libavutil/error.h"
    header "libavutil/mem.h"
    header "libavutil/pixfmt.h"
    header "libavutil/pixdesc.h"
    header "libavutil/samplefmt.h"
    header "libavutil/channel_layout.h"
    header "libavutil/frame.h"
    header "libavutil/rational.h"
    header "libavutil/imgutils.h"
    header "libavutil/mathematics.h"
    header "libavutil/timestamp.h"
    header "libavutil/avstring.h"
    header "libavutil/buffer.h"
    header "libavutil/common.h"
    header "libavutil/hwcontext.h"

    // libavcodec
    header "libavcodec/avcodec.h"
    header "libavcodec/codec.h"
    header "libavcodec/codec_id.h"
    header "libavcodec/codec_par.h"
    header "libavcodec/packet.h"

    // libavformat
    header "libavformat/avformat.h"
    header "libavformat/avio.h"

    // libavfilter
    header "libavfilter/avfilter.h"
    header "libavfilter/buffersink.h"
    header "libavfilter/buffersrc.h"

    // libswscale
    header "libswscale/swscale.h"

    // libswresample
    header "libswresample/swresample.h"

MODULEMAP_HEAD

    # Common link libraries
    cat >> "$modulemap" <<'MODULEMAP_LINKS'
    link "z"
    link "bz2"
    link "m"
    link "pthread"
MODULEMAP_LINKS

    if $is_macos; then
        cat >> "$modulemap" <<'MODULEMAP_MACOS'

    link framework "VideoToolbox"
    link framework "CoreMedia"
    link framework "CoreVideo"
    link framework "CoreFoundation"
    link framework "CoreServices"
    link framework "AudioToolbox"
    link framework "Security"
MODULEMAP_MACOS
    fi

    cat >> "$modulemap" <<'MODULEMAP_TAIL'

    export *
}
MODULEMAP_TAIL
}

generate_info_json() {
    echo "==> Generating info.json ..."

    local variants=""
    local first=true

    for platform_tag in "${PLATFORM_ARRAY[@]}"; do
        local triple=""
        case "$platform_tag" in
            macos-arm64)    triple="arm64-apple-macosx" ;;
            macos-x86_64)   triple="x86_64-apple-macosx" ;;
            linux-x86_64)   triple="x86_64-unknown-linux-gnu" ;;
            linux-aarch64)  triple="aarch64-unknown-linux-gnu" ;;
            android-arm64)  triple="aarch64-unknown-linux-android" ;;
        esac

        if ! $first; then
            variants+=","
        fi
        first=false

        variants+="
        {
          \"path\": \"${platform_tag}/libcffmpeg.a\",
          \"supportedTriples\": [\"${triple}\"],
          \"staticLibraryMetadata\": {
            \"headerPaths\": [\"${platform_tag}/include\"],
            \"moduleMapPath\": \"${platform_tag}/include/module.modulemap\"
          }
        }"
    done

    cat > "$BUNDLE_DIR/info.json" <<EOF
{
  "schemaVersion": "1.0",
  "artifacts": {
    "CFFmpeg": {
      "type": "staticLibrary",
      "version": "${FFMPEG_VERSION}.0",
      "variants": [${variants}
      ]
    }
  }
}
EOF
}

# ---------- Main ----------

echo "============================================"
echo "  FFmpeg $FFMPEG_VERSION — Artifact Bundle Builder"
echo "  Platforms: ${PLATFORMS}"
echo "============================================"
echo ""

download_ffmpeg
download_lame

for platform_tag in "${PLATFORM_ARRAY[@]}"; do
    case "$platform_tag" in
        macos-arm64)
            build_macos arm64
            ;;
        macos-x86_64)
            build_macos x86_64
            ;;
        linux-x86_64)
            if [[ "$(uname -s)" == "Linux" ]]; then
                build_linux_native x86_64
            else
                build_linux_docker x86_64
            fi
            ;;
        linux-aarch64)
            if [[ "$(uname -s)" == "Linux" && "$(uname -m)" == "aarch64" ]]; then
                build_linux_native aarch64
            else
                build_linux_docker aarch64
            fi
            ;;
        android-arm64)
            build_android_arm64
            ;;
        *)
            echo "Unknown platform: $platform_tag"
            exit 1
            ;;
    esac
done

# Clean previous bundle
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

for platform_tag in "${PLATFORM_ARRAY[@]}"; do
    merge_static_libs "$platform_tag"
    copy_headers "$platform_tag"
    generate_modulemap "$platform_tag"
done

generate_info_json

echo ""
echo "==> Artifact bundle created at: $BUNDLE_DIR"
ls -lh "$BUNDLE_DIR"/*/libcffmpeg.a 2>/dev/null || true

if $DO_ZIP; then
    ZIPFILE="$ROOT_DIR/CFFmpeg.artifactbundle.zip"
    echo "==> Zipping to $ZIPFILE ..."
    cd "$ROOT_DIR"
    zip -r "CFFmpeg.artifactbundle.zip" "CFFmpeg.artifactbundle"
    echo "==> Done: $ZIPFILE"
fi

echo ""
echo "==> Build complete!"
