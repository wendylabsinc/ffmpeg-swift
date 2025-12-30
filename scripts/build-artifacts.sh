#!/bin/bash
# Build FFmpeg static libraries for artifact bundles
# This script demonstrates how to build FFmpeg for cross-platform distribution

set -e

FFMPEG_VERSION="7.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$ROOT_DIR/build"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts"

# FFmpeg libraries to build
LIBS="libavcodec libavformat libavutil libswscale libswresample"

# Target platforms and their triples
declare -A TARGETS=(
    ["linux-x86_64"]="x86_64-unknown-linux-gnu"
    ["linux-aarch64"]="aarch64-unknown-linux-gnu"
    ["macos-arm64"]="arm64-apple-macosx"
    ["macos-x86_64"]="x86_64-apple-macosx"
)

build_ffmpeg() {
    local target=$1
    local triple=$2
    local prefix="$BUILD_DIR/$target"

    echo "Building FFmpeg for $target ($triple)..."

    mkdir -p "$prefix"
    cd "$ROOT_DIR/Sources/ffmpeg-source"

    # Configure based on target
    case $target in
        linux-*)
            ./configure \
                --prefix="$prefix" \
                --enable-static \
                --disable-shared \
                --disable-programs \
                --disable-doc \
                --disable-debug
            ;;
        macos-*)
            ./configure \
                --prefix="$prefix" \
                --enable-static \
                --disable-shared \
                --disable-programs \
                --disable-doc \
                --disable-debug \
                --enable-cross-compile \
                --target-os=darwin
            ;;
    esac

    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu)
    make install
    make clean

    cd "$ROOT_DIR"
}

create_artifact_bundle() {
    local lib=$1

    echo "Creating artifact bundle for $lib..."

    local bundle_dir="$ARTIFACTS_DIR/$lib.artifactbundle"
    mkdir -p "$bundle_dir"

    # Create info.json
    local variants=""
    local first=true

    for target in "${!TARGETS[@]}"; do
        local triple="${TARGETS[$target]}"
        local lib_file="$BUILD_DIR/$target/lib/$lib.a"

        if [[ -f "$lib_file" ]]; then
            # Copy library and headers
            mkdir -p "$bundle_dir/$target/include"
            cp "$lib_file" "$bundle_dir/$target/"
            cp -r "$BUILD_DIR/$target/include/"* "$bundle_dir/$target/include/"

            # Create module.modulemap
            cat > "$bundle_dir/$target/module.modulemap" << EOF
module ${lib#lib} [system] {
    umbrella header "include/${lib#lib}.h"
    export *
}
EOF

            if [[ "$first" == "true" ]]; then
                first=false
            else
                variants+=","
            fi

            variants+="
                {
                    \"path\": \"$target/$lib.a\",
                    \"supportedTriples\": [\"$triple\"],
                    \"staticLibraryMetadata\": {
                        \"headerPaths\": [\"$target/include\"],
                        \"moduleMapPath\": \"$target/module.modulemap\"
                    }
                }"
        fi
    done

    # Write info.json
    cat > "$bundle_dir/info.json" << EOF
{
    "schemaVersion": "1.0",
    "artifacts": {
        "$lib": {
            "type": "staticLibrary",
            "version": "$FFMPEG_VERSION",
            "variants": [$variants
            ]
        }
    }
}
EOF
}

main() {
    echo "FFmpeg Artifact Bundle Builder"
    echo "=============================="

    # Build for each target
    for target in "${!TARGETS[@]}"; do
        build_ffmpeg "$target" "${TARGETS[$target]}"
    done

    # Create artifact bundles
    for lib in $LIBS; do
        create_artifact_bundle "$lib"
    done

    echo ""
    echo "Artifact bundles created in $ARTIFACTS_DIR"
    echo "You can now use these with Swift 6.2+ binaryTarget"
}

main "$@"
