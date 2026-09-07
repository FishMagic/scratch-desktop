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
# target version. The central UOS20E bootstrap contains the build toolchain,
# but a minimal rootfs can still omit Chromium's shared-library dependencies.
RUNTIME_PACKAGES=(
    libasound2
    libatk1.0-0
    libatk-bridge2.0-0
    libatspi2.0-0
    libcairo2
    libcups2
    libdbus-1-3
    libdrm2
    libexpat1
    libfontconfig1
    libfreetype6
    libgbm1
    libglib2.0-0
    libgtk-3-0
    libnspr4
    libnss3
    libpango-1.0-0
    libpangocairo-1.0-0
    libpulse0
    libstdc++6
    libwayland-client0
    libwayland-egl1
    libwayland-server0
    libx11-6
    libx11-xcb1
    libxcb-image0
    libxcb-keysyms1
    libxcb-render-util0
    libxcb-render0
    libxcb-shm0
    libxcb-sync1
    libxcb-xfixes0
    libxcb-xkb1
    libxcb1
    libxcomposite1
    libxdamage1
    libxext6
    libxfixes3
    libxkbcommon-x11-0
    libxkbcommon0
    libxrandr2
    libxrender1
    libxss1
    libxtst6
    zlib1g
)
RUNTIME_LIBRARIES=(
    libasound.so.2
    libatk-1.0.so.0
    libatk-bridge-2.0.so.0
    libatspi.so.0
    libcairo.so.2
    libcups.so.2
    libdbus-1.so.3
    libdrm.so.2
    libexpat.so.1
    libfontconfig.so.1
    libfreetype.so.6
    libgbm.so.1
    libglib-2.0.so.0
    libgtk-3.so.0
    libnspr4.so
    libnss3.so
    libpango-1.0.so.0
    libpangocairo-1.0.so.0
    libpulse.so.0
    libstdc++.so.6
    libwayland-client.so.0
    libwayland-egl.so.1
    libwayland-server.so.0
    libX11.so.6
    libX11-xcb.so.1
    libxcb-image.so.0
    libxcb-keysyms.so.1
    libxcb-render-util.so.0
    libxcb-render.so.0
    libxcb-shm.so.0
    libxcb-sync.so.1
    libxcb-xfixes.so.0
    libxcb-xkb.so.1
    libxcb.so.1
    libXcomposite.so.1
    libXdamage.so.1
    libXext.so.6
    libXfixes.so.3
    libxkbcommon-x11.so.0
    libxkbcommon.so.0
    libXrandr.so.2
    libXrender.so.1
    libXss.so.1
    libXtst.so.6
    libz.so.1
)
RUNTIME_MISSING=0
for library in "${RUNTIME_LIBRARIES[@]}"; do
    if ! ldconfig -p 2>/dev/null | grep -Fq "$library"; then
        RUNTIME_MISSING=1
        break
    fi
done

if [ "$RUNTIME_MISSING" -eq 1 ]; then
    export DEBIAN_FRONTEND=noninteractive
    APT_OPTIONS=(
        -o Acquire::Check-Valid-Until=false
        -o Acquire::AllowInsecureRepositories=true
        -o APT::Get::AllowUnauthenticated=true
    )
    apt-get update "${APT_OPTIONS[@]}"
    APT_TMP=$(mktemp -d)
    (
        cd "$APT_TMP"
        apt-get download "${APT_OPTIONS[@]}" "${RUNTIME_PACKAGES[@]}"
        for deb in ./*.deb; do
            dpkg-deb -x "$deb" /
        done
    )
    rm -rf "$APT_TMP"
    ldconfig
fi

ELECTRON_BINARY=node_modules/electron/dist/electron
MISSING_ELECTRON_LIBRARIES=$(ldd "$ELECTRON_BINARY" 2>/dev/null | grep 'not found' || true)
if [ -n "$MISSING_ELECTRON_LIBRARIES" ]; then
    echo "Electron still has missing shared libraries:" >&2
    echo "$MISSING_ELECTRON_LIBRARIES" >&2
    exit 1
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
