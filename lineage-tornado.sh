#!/bin/bash
set -e

echo "========================"
echo "removing local manifests"
echo "========================"

rm -rf .repo/local_manifests;
rm -rf out/soong/.intermediates/system/sepolicy;

echo "====================="
echo "      Repo init      "
echo "====================="

repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --depth=1 --git-lfs;

git clone https://github.com/heppysingh/local-manifest-tornado.git -b main .repo/local_manifests;

echo "==================="
echo "     repo sync     "
echo "==================="

# Purge dirty/deprecated prebuilts from Crave cache to prevent SyncError
rm -rf prebuilts/gcc prebuilts/clang

/opt/crave/resync.sh;

sudo apt-get update && sudo apt-get install patchelf coreutils -y;

export BUILD_USERNAME=Happy
export BUILD_HOSTNAME=foss

rm -rf build/soong/fsgen;

echo "build started!..."

. build/envsetup.sh;
lunch lineage_tornado-bp4a-userdebug;
m bacon

echo "Upload to GoFile will be started..."

ZIP=$(find out/target/product/tornado -maxdepth 1 -type f -name "*.zip" | head -n 1)

if [ -n "$ZIP" ]; then
    echo "Uploading $ZIP..."
    wget https://raw.githubusercontent.com/lordgaruda/GoFile-Upload/refs/heads/master/upload.sh
    chmod +x upload.sh
    ./upload.sh "$ZIP"
else
    echo "No ROM ZIP found!
    "
    exit 1
fi
