#!/bin/bash
# Create Swift 6.2 artifact bundles from built FFmpeg libraries (SE-0482)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUILDS_DIR="$ROOT_DIR/builds"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts"

FFMPEG_VERSION="${FFMPEG_VERSION:-7.1}"

# FFmpeg libraries to package
LIBS=(
    "libavcodec:avcodec"
    "libavformat:avformat"
    "libavutil:avutil"
    "libswscale:swscale"
    "libswresample:swresample"
)

# Platform mappings: directory -> triple
declare -A PLATFORM_TRIPLES=(
    ["ffmpeg-macos-arm64"]="arm64-apple-macosx"
    ["ffmpeg-macos-x86_64"]="x86_64-apple-macosx"
    ["ffmpeg-linux-x86_64"]="x86_64-unknown-linux-gnu"
    ["ffmpeg-linux-aarch64"]="aarch64-unknown-linux-gnu"
)

# Clean up old artifacts
rm -rf "$ARTIFACTS_DIR"/*.artifactbundle "$ARTIFACTS_DIR"/*.artifactbundle.zip
mkdir -p "$ARTIFACTS_DIR"

create_module_map() {
    local lib_name=$1
    local module_name=$2
    local header_dir=$3
    local output_file=$4

    cat > "$output_file" << EOF
module $module_name [system] {
    umbrella header "$header_dir/$lib_name/$lib_name.h"
    link "$module_name"
    export *
}
EOF
}

create_artifact_bundle() {
    local lib_entry=$1
    local lib_name="${lib_entry%%:*}"
    local module_name="${lib_entry##*:}"

    echo "Creating artifact bundle for $lib_name..."

    local bundle_dir="$ARTIFACTS_DIR/$lib_name.artifactbundle"
    mkdir -p "$bundle_dir"

    local variants_json=""
    local first=true

    for platform_dir in "${!PLATFORM_TRIPLES[@]}"; do
        local triple="${PLATFORM_TRIPLES[$platform_dir]}"
        local build_path="$BUILDS_DIR/$platform_dir"
        local lib_file="$build_path/lib/$lib_name.a"

        if [[ ! -f "$lib_file" ]]; then
            echo "  Warning: $lib_file not found, skipping $platform_dir"
            continue
        fi

        echo "  Adding $platform_dir ($triple)"

        # Create platform directory in bundle
        local target_dir="$bundle_dir/$platform_dir"
        mkdir -p "$target_dir/include"

        # Copy static library
        cp "$lib_file" "$target_dir/"

        # Copy headers
        if [[ -d "$build_path/include/$lib_name" ]]; then
            cp -r "$build_path/include/$lib_name" "$target_dir/include/"
        fi

        # Also copy common headers that might be needed
        if [[ -d "$build_path/include/libavutil" && "$lib_name" != "libavutil" ]]; then
            cp -r "$build_path/include/libavutil" "$target_dir/include/" 2>/dev/null || true
        fi

        # Create module.modulemap
        cat > "$target_dir/module.modulemap" << EOF
module C${module_name^} [system] {
    header "include/$lib_name/$lib_name.h"
    link "$module_name"
    export *
}
EOF

        # Build JSON variant entry
        if [[ "$first" == "true" ]]; then
            first=false
        else
            variants_json+=","
        fi

        variants_json+="
        {
          \"path\": \"$platform_dir/$lib_name.a\",
          \"supportedTriples\": [\"$triple\"],
          \"staticLibraryMetadata\": {
            \"headerPaths\": [\"$platform_dir/include\"],
            \"moduleMapPath\": \"$platform_dir/module.modulemap\"
          }
        }"
    done

    # Write info.json
    cat > "$bundle_dir/info.json" << EOF
{
  "schemaVersion": "1.0",
  "artifacts": {
    "$lib_name": {
      "type": "staticLibrary",
      "version": "$FFMPEG_VERSION",
      "variants": [$variants_json
      ]
    }
  }
}
EOF

    # Create zip
    echo "  Creating zip..."
    (cd "$ARTIFACTS_DIR" && zip -r "$lib_name.artifactbundle.zip" "$lib_name.artifactbundle")

    echo "  Done: $lib_name.artifactbundle.zip"
}

main() {
    echo "=========================================="
    echo "FFmpeg Artifact Bundle Creator (SE-0482)"
    echo "=========================================="
    echo ""
    echo "FFmpeg Version: $FFMPEG_VERSION"
    echo "Builds Directory: $BUILDS_DIR"
    echo "Output Directory: $ARTIFACTS_DIR"
    echo ""

    # Verify builds exist
    if [[ ! -d "$BUILDS_DIR" ]]; then
        echo "Error: Builds directory not found at $BUILDS_DIR"
        exit 1
    fi

    echo "Available platforms:"
    for platform_dir in "${!PLATFORM_TRIPLES[@]}"; do
        if [[ -d "$BUILDS_DIR/$platform_dir" ]]; then
            echo "  ✓ $platform_dir -> ${PLATFORM_TRIPLES[$platform_dir]}"
        else
            echo "  ✗ $platform_dir (not found)"
        fi
    done
    echo ""

    # Create artifact bundles for each library
    for lib_entry in "${LIBS[@]}"; do
        create_artifact_bundle "$lib_entry"
        echo ""
    done

    echo "=========================================="
    echo "Artifact bundles created successfully!"
    echo "=========================================="
    ls -la "$ARTIFACTS_DIR"/*.artifactbundle.zip 2>/dev/null || echo "No zip files created"
}

main "$@"
