#!/usr/bin/env bash
# ==============================================================================
# Script to build OrangeFox Recovery 
# Converted from .github/workflows/build.yml
# ==============================================================================

set -eo pipefail

# ----------------- Configuration & Defaults -----------------
# Can be overridden via arguments or environment variables:
#  
MANIFEST_BRANCH="${1:-${MANIFEST_BRANCH:-16.0}}"
BUILD_TARGET="${2:-${BUILD_TARGET:-fox_tornado-bp2a-eng}}"
WORK_DIR="${WORK_DIR:-/fox/android}"
DEVICE_TREE_REPO="https://github.com/heppysingh/ofox_tornado.git"
DEVICE_TREE_BRANCH="main"
DEVICE_DIR="$WORK_DIR/device/xiaomi/tornado"

echo "=================================================="
echo " Starting OrangeFox Build for "
echo " Manifest Branch : $MANIFEST_BRANCH"
echo " Build Target    : $BUILD_TARGET"
echo " Working Dir     : $WORK_DIR"
echo "=================================================="

# ----------------- 1. Prepare Environment & Dependencies -----------------
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v repo &>/dev/null; then
    echo "[-] repo not found. Downloading Google repo tool..."
    curl -sL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/.local/bin/repo"
    chmod +x "$HOME/.local/bin/repo"
fi

# Set git identity if not configured
if [ -z "$(git config --global user.name)" ]; then
    git config --global user.name "OrangeFox Builder"
fi
if [ -z "$(git config --global user.email)" ]; then
    git config --global user.email "builder@orangefox.tech"
fi
git config --global color.ui true

# ----------------- 2. Sync OrangeFox Sources -----------------
mkdir -p "$WORK_DIR"
SYNC_TOOLS_DIR="/tmp/sync_tools"
rm -rf "$SYNC_TOOLS_DIR"
mkdir -p "$SYNC_TOOLS_DIR"

echo "[+] Cloning OrangeFox sync tool..."
git clone --depth=1 https://gitlab.com/OrangeFox/sync.git "$SYNC_TOOLS_DIR"

echo "[+] Syncing OrangeFox sources (Branch: $MANIFEST_BRANCH)..."
cd "$SYNC_TOOLS_DIR"
./orangefox_sync.sh --branch "$MANIFEST_BRANCH" --path "$WORK_DIR"

# ----------------- 3. Setup Device Tree -----------------
echo "[+] Setting up device tree in: $DEVICE_DIR"
mkdir -p "$DEVICE_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/BoardConfig.mk" ]; then
    echo "[+] Copying device tree from local script directory ($SCRIPT_DIR)..."
    rsync -a --exclude=.git --exclude=.github "$SCRIPT_DIR/" "$DEVICE_DIR/"
elif [ -f "./BoardConfig.mk" ]; then
    echo "[+] Copying device tree from current working directory..."
    rsync -a --exclude=.git --exclude=.github ./ "$DEVICE_DIR/"
else
    echo "[+] Cloning device tree from GitHub ($DEVICE_TREE_REPO)..."
    rm -rf "$DEVICE_DIR"
    git clone --depth=1 -b "$DEVICE_TREE_BRANCH" "$DEVICE_TREE_REPO" "$DEVICE_DIR"
fi

# ----------------- 4. Build OrangeFox Recovery -----------------
cd "$WORK_DIR"

# Source Android build environment
set +e
source build/envsetup.sh

# Source OrangeFox vendor setup flags
if [ -f "$DEVICE_DIR/vendorsetup.sh" ]; then
    echo "[+] Sourcing vendorsetup.sh..."
    source "$DEVICE_DIR/vendorsetup.sh"
fi
set -e

echo "=== Lunching target: $BUILD_TARGET ==="
lunch "$BUILD_TARGET"

echo "=== Building vendorbootimage ==="
mka vendorbootimage -j$(nproc --all)

# ----------------- 5. Verify Build Output -----------------
OUTPUT_DIR="$WORK_DIR/out/target/product/tornado"
echo "=================================================="
echo " Build Output Directory: $OUTPUT_DIR"
echo "=================================================="
if [ -d "$OUTPUT_DIR" ]; then
    find "$OUTPUT_DIR" -maxdepth 2 -type f \( \
        -name "OrangeFox*.zip" -o \
        -name "OrangeFox*.img" -o \
        -name "*vendor*boot*.img" -o \
        -name "vendor_ramdisk_recovery.cpio" -o \
        -name "recovery.img" -o \
        -name "boot.img" \
    \) -exec ls -lh {} + || true
else
    echo "[-] Warning: Output directory not found!"
fi

echo "=================================================="
echo " Build script finished!"
echo " Pull your artifacts using:"
echo "   out/target/product/tornado/vendor_boot.img"
echo "   out/target/product/tornado/OrangeFox*"
echo "=================================================="
