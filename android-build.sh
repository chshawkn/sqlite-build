#! /bin/sh

if [ -z "$NDK_PLATFORM" ]; then
  export NDK_PLATFORM="android-24"
  export NDK_PLATFORM_COMPAT="${NDK_PLATFORM_COMPAT:-android-16}"
else
  export NDK_PLATFORM_COMPAT="${NDK_PLATFORM_COMPAT:-${NDK_PLATFORM}}"
fi
export NDK_API_VERSION=$(echo "$NDK_PLATFORM" | sed 's/^android-//')
export NDK_API_VERSION_COMPAT=$(echo "$NDK_PLATFORM_COMPAT" | sed 's/^android-//')

if [ -z "$ANDROID_NDK_HOME" ]; then
  echo "You should probably set ANDROID_NDK_HOME to the directory containing"
  echo "the Android NDK"
  exit
fi

if [ ! -f ./configure ]; then
  echo "Can't find ./configure. Wrong directory or haven't run autogen.sh?" >&2
  exit 1
fi

if [ "x$TARGET_ARCH" = 'x' ] || [ "x$ARCH" = 'x' ] || [ "x$HOST_COMPILER" = 'x' ]; then
  echo "You shouldn't use android-build.sh directly, use android-[arch].sh instead" >&2
  exit 1
fi

export MAKE_TOOLCHAIN="${ANDROID_NDK_HOME}/build/tools/make_standalone_toolchain.py"

export PREFIX="$(pwd)/sqlite-android-${TARGET_ARCH}"
export TOOLCHAIN_DIR="$(pwd)/android-toolchain-${TARGET_ARCH}"
export PATH="${PATH}:${TOOLCHAIN_DIR}/bin"

export CC=${CC:-"${HOST_COMPILER}-clang"}

rm -rf "${TOOLCHAIN_DIR}" "${PREFIX}"

echo
echo "Building for platform [${NDK_PLATFORM}], retaining compatibility with platform [${NDK_PLATFORM_COMPAT}]"
echo

env - PATH="$PATH" \
    "$MAKE_TOOLCHAIN" --force --api="$NDK_API_VERSION_COMPAT" \
    --unified-headers --arch="$ARCH" --install-dir="$TOOLCHAIN_DIR" || exit 1

./configure \
    --disable-soname-versions \
    --enable-minimal \
    --host="${HOST_COMPILER}" \
    --prefix="${PREFIX}" \
    --with-sysroot="${TOOLCHAIN_DIR}/sysroot" || exit 1

if [ "$NDK_PLATFORM" != "$NDK_PLATFORM_COMPAT" ]; then
  egrep '^#define ' config.log | sort -u > config-def-compat.log
  echo
  echo "Configuring again for platform [${NDK_PLATFORM}]"
  echo
  env - PATH="$PATH" \
      "$MAKE_TOOLCHAIN" --force --api="$NDK_API_VERSION" \
      --unified-headers --arch="$ARCH" --install-dir="$TOOLCHAIN_DIR" || exit 1

  ./configure \
      --disable-soname-versions \
      --enable-minimal \
      --host="${HOST_COMPILER}" \
      --prefix="${PREFIX}" \
      --with-sysroot="${TOOLCHAIN_DIR}/sysroot" || exit 1

  egrep '^#define ' config.log | sort -u > config-def.log
  if ! cmp config-def.log config-def-compat.log; then
    echo "Platform [${NDK_PLATFORM}] is not backwards-compatible with [${NDK_PLATFORM_COMPAT}]" >&2
    diff -u config-def.log config-def-compat.log >&2
    exit 1
  fi
  rm -f config-def.log config-def-compat.log
fi

make clean && \
make -j3 install && \
echo "sqlite has been installed into ${PREFIX}"
