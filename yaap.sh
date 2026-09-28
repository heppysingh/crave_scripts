#!/bin/bash

set -eE
trap 'echo " FAILED at line $LINENO"; exit 1' ERR

rm -rf .repo/local_manifests


# repo init rom
repo init -u https://github.com/yaap/manifest.git -b sixteen --depth=1 --git-lfs 
echo "=================="
echo "Repo init success"
echo "=================="

# Local manifests
git clone https://github.com/heppysingh/Local-manifest.git -b main .repo/local_manifests
echo "============================"
echo "Local manifest clone done   "
echo "============================"

# Build Sync


/opt/crave/resync.sh;

/opt/crave/resync.sh;

echo "============="
echo "Sync done    "
echo "============="

# Installing packages 
sudo apt-get update && sudo apt-get install patchelf coreutils -y 
echo "============="
echo "packages done"
echo "============="

# Export
export BUILD_USERNAME=heppy
export BUILD_HOSTNAME=foss
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export IGNORE_PATCH_ERRORS=true
echo "======= Export Done ======"

#Fixing patchs
git -C frameworks/av am --abort 2>/dev/null || true
git -C frameworks/base am --abort 2>/dev/null || true
git -C hardware/interfaces am --abort 2>/dev/null || true
git -C packages/modules/Bluetooth am --abort 2>/dev/null || true
git -C build/soong am --abort 2>/dev/null || true
git -C system/sepolicy am --abort 2>/dev/null || true

#deleting extra generator
rm -rf vendor/lineage/build/soong/generator

#Go fix
SOONG_FILE="build/soong/ui/execution_metrics/execution_metrics.go"

if [ -f "$SOONG_FILE" ]; then
    echo "Re-patching execution_metrics.go safely..."

    git checkout -- "$SOONG_FILE" 2>/dev/null || true

    grep -q '"sort"' "$SOONG_FILE" || \
        sed -i '/^import (/a\    "sort"' "$SOONG_FILE"

    sed -i '/"maps"/d; /"slices"/d' "$SOONG_FILE"

    sed -i 's/slices\.Sorted(maps\.Keys(\([^)]*\)))/func() []string { keys := make([]string, 0, len(\1)); for k := range \1 { keys = append(keys, k) }; sort.Strings(keys); return keys }()/' "$SOONG_FILE"

    echo "patched successfully"
else
    echo "$SOONG_FILE not found, skipping Go patch."
fi

echo "=======soong fix done========"

#Making kernel modules dir
mkdir -p device/xiaomi/blossom-kernel/modules

#Fixing audio files
AUDIO_BP="hardware/interfaces/audio/common/all-versions/default/Android.bp"
if [ -f "$AUDIO_BP" ]; then
    echo "Fixing Audio select type condition..."
    sed -i 's/"true":/true:/g' "$AUDIO_BP"
    echo "Audio Android.bp patched!"
else
    echo "Audio Android.bp not found."
fi

echo "=======audio fix done========="


# Set up build environment
source build/envsetup.sh
echo "============="

# Lunch
lunch yaap_blossom-bp2a-userdebug

# Build
m yaap
