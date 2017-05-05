#!/usr/bin/env bash

SOURCE="$0"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
export SCRIPT_PATH="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
echo "SCRIPT_PATH: ${SCRIPT_PATH}"

: "${LIB_NAME:=sqlite-3.18.0}"
LIB_VERSION="$(echo ${LIB_NAME} | awk -F- '{print $2}')"
ARCHIVE="${LIB_NAME}.tar.gz"
ARCHIVE_URL="https://www.sqlite.org/2017/sqlite-autoconf-3180000.tar.gz"
#ARCHIVE="${LIB_NAME}.zip"
#ARCHIVE_URL="https://www.sqlite.org/2017/sqlite-amalgamation-3180000.zip"

if [[ ! -v AND_ARCHS ]]; then
    : "${AND_ARCHS:=android android-armeabi android-x86 android64 android64-aarch64}"
fi

if [[ ! -v IOS_ARCHS ]]; then
    : "${IOS_ARCHS:=arm64 armv7 armv7s i386 x86_64}"
fi

FILTER="${SCRIPT_PATH}/filter"

function unzip-strip() {
    local zip=$1
    local dest=${2:-.}
    local temp=$(mktemp -d) && unzip -d "$temp" "$zip" && mkdir -p "$dest" &&
    shopt -s dotglob && local f=("$temp"/*) &&
    if (( ${#f[@]} == 1 )) && [[ -d "${f[0]}" ]] ; then
        mv "$temp"/*/* "$dest"
    else
        mv "$temp"/* "$dest"
    fi && rmdir "$temp"/* "$temp"
}
