#!/usr/bin/env bash

# see: http://blog.csdn.net/Sozell/article/details/12451565
# see: https://github.com/swiftlyfalling/SQLiteLib

set -e
set -u

source common.sh

export XCODEDIR=$(xcode-select -p)

xcode_major=$(xcodebuild -version|egrep '^Xcode '|cut -d' ' -f2|cut -d. -f1)
if [ $xcode_major -ge 8 ]; then
  export IOS_SIMULATOR_VERSION_MIN=${IOS_SIMULATOR_VERSION_MIN-"6.0.0"}
  export IOS_VERSION_MIN=${IOS_VERSION_MIN-"6.0.0"}
else
  export IOS_SIMULATOR_VERSION_MIN=${IOS_SIMULATOR_VERSION_MIN-"5.1.1"}
  export IOS_VERSION_MIN=${IOS_VERSION_MIN-"5.1.1"}
fi

function  configure_make() {
    local ARCH=$1
    local SDK_VERSION=$2

    local CONFIGURE_HOST=""
    local PLATFORM="iPhoneOS"

    CPPFLAGS="-DSQLITE_ENABLE_API_ARMOR=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_ENABLE_FTS3=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_ENABLE_FTS3_PARENTHESIS=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_ENABLE_LOCKING_STYLE=0"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_ENABLE_RTREE=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_ENABLE_UPDATE_DELETE_LIMIT=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_MAX_MMAP_SIZE=0"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_OMIT_AUTORESET=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_OMIT_BUILTIN_TEST=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_OMIT_LOAD_EXTENSION=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_SYSTEM_MALLOC=1"
    CPPFLAGS="${CPPFLAGS} -DSQLITE_THREADSAFE=2"

    CFLAGS=""
    LDFLAGS=""
    local PREFIX="$(pwd)/target"
    if [[ "${ARCH}" == "arm64" ]]; then
        CFLAGS="${CFLAGS} -O2 -arch arm64 -mios-version-min=${IOS_VERSION_MIN}"
        LDFLAGS="${LDFLAGS} -arch arm64 -mios-version-min=${IOS_VERSION_MIN}"

        PREFIX="${PREFIX}/${LIB_NAME}-aarch64-apple-ios"
        local CONFIGURE_HOST="arm-apple-darwin10"
    elif [[ "${ARCH}" == "armv7" ]]; then
        CFLAGS="-O2 -mthumb -arch armv7 -mios-version-min=${IOS_VERSION_MIN}"
        LDFLAGS="-mthumb -arch armv7 -mios-version-min=${IOS_VERSION_MIN}"

        PREFIX="${PREFIX}/${LIB_NAME}-armv7-apple-ios"
        local CONFIGURE_HOST="arm-apple-darwin10"
    elif [[ "${ARCH}" == "armv7s" ]]; then
        CFLAGS="-O2 -mthumb -arch armv7s -mios-version-min=${IOS_VERSION_MIN}"
        LDFLAGS="-mthumb -arch armv7s -mios-version-min=${IOS_VERSION_MIN}"

        PREFIX="${PREFIX}/${LIB_NAME}-armv7s-apple-ios"
        local CONFIGURE_HOST="arm-apple-darwin10"
    elif [[ "${ARCH}" == "i386" ]]; then
        CFLAGS="-O2 -arch i386 -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"
        LDFLAGS="-arch i386 -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"

        PREFIX="${PREFIX}/${LIB_NAME}-i386-apple-ios"
        local CONFIGURE_HOST="i686-apple-darwin10"

        PLATFORM="iPhoneSimulator"
    elif [[ "${ARCH}" == "x86_64" ]]; then
        CFLAGS="-O2 -arch x86_64 -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"
        LDFLAGS="-arch x86_64 -mios-simulator-version-min=${IOS_SIMULATOR_VERSION_MIN}"

        PREFIX="${PREFIX}/${LIB_NAME}-x86_64-apple-ios"
        local CONFIGURE_HOST="x86_64-apple-darwin10"

        PLATFORM="iPhoneSimulator"
    fi

    export BASEDIR="${XCODEDIR}/Platforms/${PLATFORM}.platform/Developer"
    export PATH="${BASEDIR}/usr/bin:$BASEDIR/usr/sbin:$PATH"
    export SDK="${BASEDIR}/SDKs/${PLATFORM}.sdk"

    export CFLAGS="${CFLAGS} -isysroot ${SDK}"
    export LDFLAGS="${LDFLAGS} -isysroot ${SDK}"

    if [ -d "${PREFIX}" ]; then rm -fr "${PREFIX}"; fi
    mkdir -p ${PREFIX} || exit 1

    rm -rf "target/${LIB_NAME}"
    mkdir -p "target/${LIB_NAME}"
    #unzip-strip "target/${ARCHIVE}" "target/${LIB_NAME}"
    tar xzf "target/${ARCHIVE}" --strip-components=1 -C "target/${LIB_NAME}"

    cd "target/${LIB_NAME}"
    echo $(pwd)

    ./configure --disable-shared --enable-static --disable-debug-mode \
    --host=${CONFIGURE_HOST} \
    --prefix="${PREFIX}" \
    LDFLAGS="$LDFLAGS -L${PREFIX}/lib" \
    CFLAGS="${CFLAGS} -I${PREFIX}/include" \
    CPPFLAGS="${CPPFLAGS} -I${PREFIX}/include"

    make -j4 && make install && make clean

    cd ../../
}

IOS_ARCHS_ARRAY=(${IOS_ARCHS})
: "${IOS_SDK_VERSION:=10.3}"
for ((i=0; i < ${#IOS_ARCHS_ARRAY[@]}; i++))
do
    if [[ $# -eq 0 || "$1" == "${IOS_ARCHS_ARRAY[i]}" ]]; then
        configure_make "${IOS_ARCHS_ARRAY[i]}" "${IOS_SDK_VERSION}"
    fi
done

if [[ $# -eq 0 && ${#IOS_ARCHS_ARRAY[@]} -eq 5 ]]; then
    # Create universal binary and include folder
    PREFIX="$(pwd)/target/${LIB_NAME}-universal-apple-ios"
    rm -fr -- "${PREFIX}/include" "${PREFIX}/libsqlite3.a" 2> /dev/null
    mkdir -p -- "${PREFIX}/lib"
    lipo -create \
      "$(pwd)/target/${LIB_NAME}-aarch64-apple-ios/lib/libsqlite3.a" \
      "$(pwd)/target/${LIB_NAME}-armv7-apple-ios/lib/libsqlite3.a" \
      "$(pwd)/target/${LIB_NAME}-armv7s-apple-ios/lib/libsqlite3.a" \
      "$(pwd)/target/${LIB_NAME}-i386-apple-ios/lib/libsqlite3.a" \
      "$(pwd)/target/${LIB_NAME}-x86_64-apple-ios/lib/libsqlite3.a" \
      -output "${PREFIX}/lib/libsqlite3.a"
    cp -r -- "$(pwd)/target/${LIB_NAME}-armv7-apple-ios/include" "${PREFIX}/"

    echo
    echo "libsqlite3 has been installed into ${PREFIX}"
    echo
    file -- "${PREFIX}/lib/libsqlite3.a"

    # Cleanup
    rm -rf -- "${PREFIX}/tmp"
    make distclean > /dev/null || echo No rule to make target
fi
