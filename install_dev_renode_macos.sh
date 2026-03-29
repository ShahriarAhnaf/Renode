#!/usr/bin/env bash
# Build and install Renode from a dev fork on macOS (Apple Silicon).
#
# Clones (or updates) the fork to ~/.cache/dev-renode/, builds from source
# with --host-arch aarch64, and installs to /opt/dev-renode/. Installs as
# `dev-renode` / `dev-renode-test` to avoid collisions with upstream Renode.
#
# Prerequisites:
#   - macOS on Apple Silicon (arm64)
#   - .NET SDK 9.0+ (installed via Homebrew if missing)
#   - CMake (installed via Homebrew if missing)
#   - ~2 GB disk for build artifacts, ~200 MB installed
#
# Build time: 10-20 minutes (first build), 2-5 minutes (incremental)
#
# Usage:
#   ./install_dev_renode_macos.sh              # clone + build + install
#   ./install_dev_renode_macos.sh --rebuild     # skip pull, just rebuild
#   ./install_dev_renode_macos.sh --clean       # clean build from scratch

set -euo pipefail

FORK_URL="${RENODE_FORK_URL:-git@github.com:ShahriarAhnaf/Renode.git}"
FORK_BRANCH="${RENODE_FORK_BRANCH:-ahnaf/stm32}"
CACHE_DIR="${HOME}/.cache/dev-renode"
INSTALL_DIR="/opt/dev-renode"

echo "=== Building dev-renode from fork (macOS arm64) ==="
echo "Fork: ${FORK_URL} (branch: ${FORK_BRANCH})"
echo "Cache: ${CACHE_DIR}"
echo ""

# --- Platform checks ---

if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: This script is for macOS only."
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "ERROR: This script is for Apple Silicon (arm64) only."
    exit 1
fi

# --- Dependency checks ---

install_if_missing() {
    local cmd="$1" pkg="$2"
    if ! command -v "$cmd" &>/dev/null; then
        echo "Installing ${pkg} via Homebrew..."
        if ! command -v brew &>/dev/null; then
            echo "ERROR: Homebrew not found. Install from https://brew.sh"
            exit 1
        fi
        brew install "$pkg"
    fi
}

install_if_missing dotnet dotnet@9
install_if_missing cmake cmake

# --- Clone or update ---

if [[ "${1:-}" == "--clean" ]]; then
    echo "Cleaning build cache..."
    rm -rf "${CACHE_DIR}"
fi

if [[ -d "${CACHE_DIR}/.git" ]]; then
    if [[ "${1:-}" != "--rebuild" ]]; then
        echo "Step 1/4: Updating existing clone..."
        cd "${CACHE_DIR}"
        git fetch origin
        git checkout "${FORK_BRANCH}"
        git reset --hard "origin/${FORK_BRANCH}"
        git submodule update --init --recursive
    else
        echo "Step 1/4: Skipping update (--rebuild)"
        cd "${CACHE_DIR}"
    fi
else
    echo "Step 1/4: Cloning fork (with submodules, this takes a few minutes)..."
    git clone --recursive -b "${FORK_BRANCH}" "${FORK_URL}" "${CACHE_DIR}"
    cd "${CACHE_DIR}"
fi

echo ""
echo "Step 2/4: Building Renode from source..."
echo "  (this takes 10-20 minutes on first build)"

./build.sh --no-gui --host-arch aarch64

echo ""
echo "Step 3/4: Installing to ${INSTALL_DIR}..."
sudo rm -rf "${INSTALL_DIR}"
sudo mkdir -p "${INSTALL_DIR}"

if [[ -f output/bin/Release/Renode.dll ]]; then
    BUILD_OUTPUT="output/bin/Release"
else
    BUILD_OUTPUT=$(find output/bin -type f -name "Renode.dll" -exec dirname {} \; | head -1)
fi
if [[ -z "${BUILD_OUTPUT}" || ! -f "${BUILD_OUTPUT}/Renode.dll" ]]; then
    echo "ERROR: Renode.dll not found in build output. Check build logs above."
    exit 1
fi

sudo cp -R "${BUILD_OUTPUT}/." "${INSTALL_DIR}/"

for dir in scripts platforms; do
    if [[ -d "$dir" ]]; then
        sudo cp -R "$dir" "${INSTALL_DIR}/"
    fi
done
if [[ -f .renode-root ]]; then
    sudo cp .renode-root "${INSTALL_DIR}/"
fi

echo ""
echo "Step 4/4: Creating CLI wrappers..."

sudo tee /usr/local/bin/dev-renode >/dev/null <<'WRAPPER'
#!/bin/bash
exec dotnet /opt/dev-renode/Renode.dll "$@"
WRAPPER
sudo chmod +x /usr/local/bin/dev-renode

sudo tee /usr/local/bin/dev-renode-test >/dev/null <<'WRAPPER'
#!/bin/bash
exec dotnet /opt/dev-renode/Renode.dll --disable-xwt --console "$@"
WRAPPER
sudo chmod +x /usr/local/bin/dev-renode-test

FORK_COMMIT="$(git -C "${CACHE_DIR}" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"

echo ""
echo "=== Installation complete! ==="
echo "  Commit: ${FORK_COMMIT}"
echo ""
echo "  dev-renode        - launch Renode"
echo "  dev-renode-test   - launch Renode in headless/test mode"
echo ""
echo "To update the fork later:"
echo "  $0"
echo ""
echo "To rebuild without pulling:"
echo "  $0 --rebuild"
