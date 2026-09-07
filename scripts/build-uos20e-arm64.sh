#!/usr/bin/env bash
# Build Scratch Desktop inside the UOS20E arm64 container.
set -euo pipefail

WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
cd "$WORKSPACE"

[ "$(uname -m)" = aarch64 ] || {
    echo "native arm64 is required; got $(uname -m)" >&2
    exit 2
}

command -v node >/dev/null || { echo "node is not available in the build container" >&2; exit 2; }
command -v npm >/dev/null || { echo "npm is not available in the build container" >&2; exit 2; }

EXPECTED_NODE_VERSION=$(tr -d '[:space:]' < .nvmrc)
ACTUAL_NODE_VERSION=$(node --version)
[ "$ACTUAL_NODE_VERSION" = "v$EXPECTED_NODE_VERSION" ] || {
    echo "expected Node v$EXPECTED_NODE_VERSION, got $ACTUAL_NODE_VERSION" >&2
    exit 2
}

export npm_config_arch=arm64
export npm_config_platform=linux
export npm_config_update_notifier=false
mkdir -p "${HOME:-/tmp}" "${npm_config_cache:-.cache/npm}" "${ELECTRON_CACHE:-.cache/electron}" \
    "${ELECTRON_BUILDER_CACHE:-.cache/electron-builder}"

echo "Building Scratch Desktop with Node $ACTUAL_NODE_VERSION and npm $(npm --version)"
npm ci --no-audit --no-fund

# Electron's browser binary is used by webpack.makeConfig.js to read the
# target version. The central UOS20E bootstrap contains the build toolchain
# but not these two browser runtime libraries.
if ! ldconfig -p 2>/dev/null | grep -q 'libnspr4.so'; then
    export DEBIAN_FRONTEND=noninteractive
    APT_OPTIONS=(
        -o Acquire::Check-Valid-Until=false
        -o Acquire::AllowInsecureRepositories=true
        -o APT::Get::AllowUnauthenticated=true
    )
    apt-get update "${APT_OPTIONS[@]}"
    apt-get install -y --no-install-recommends "${APT_OPTIONS[@]}" libnspr4 libnss3
    ldconfig
fi

npm run distDev -- --target=linux-arm64

shopt -s nullglob
APPIMAGES=(dist/*.AppImage)
TAR_GZS=(dist/*.tar.gz)
if [ "${#APPIMAGES[@]}" -ne 1 ]; then
    echo "expected exactly one AppImage, found ${#APPIMAGES[@]}" >&2
    exit 1
fi
if [ "${#TAR_GZS[@]}" -ne 1 ]; then
    echo "expected exactly one tar.gz, found ${#TAR_GZS[@]}" >&2
    exit 1
fi

(
    cd dist
    sha256sum -- *.AppImage *.tar.gz
) > dist/SHA256SUMS

file "${APPIMAGES[0]}" "${TAR_GZS[0]}"
printf 'UOS20E arm64 artifacts ready:\n  %s\n  %s\n' "${APPIMAGES[0]}" "${TAR_GZS[0]}"
