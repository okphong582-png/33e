#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
native_ndk="${ANDROID_NDK_HOME:-${ANDROID_HOME:?}/ndk/26.3.11579264}"
cmake -S native -B .build-native -DCMAKE_TOOLCHAIN_FILE="$native_ndk/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 -DANDROID_STL=c++_static -DCMAKE_BUILD_TYPE=Release
cmake --build .build-native --parallel 2
mkdir -p app/src/root/jniLibs/arm64-v8a
cp .build-native/libmizze_silent.so app/src/root/jniLibs/arm64-v8a/
cp .build-native/mizze_loader app/src/root/jniLibs/arm64-v8a/libmizze_loader.so
