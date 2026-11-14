#!/usr/bin/env bash
set -e
WORKSPACE=$(dirname "$(readlink -f "$0")")
cd "${WORKSPACE}"

# Usage:
#   ./build-t95max.sh          -> build full Debian 13 (trixie) image
#   ./build-t95max.sh kernel   -> build kernel .deb packages only
TARGET="${1:-build}"

# Ensure Docker service is running
sudo service docker status >/dev/null 2>&1 || sudo service docker start

echo "======================================================================"
echo " BUILDING ARMBIAN (${TARGET}) FOR T95 MAX (H618 + DDR3 1.5V + BCM43342)"
echo "======================================================================"

if [ "${TARGET}" = "kernel" ]; then
    PESTER_TERMINAL=no ./compile.sh kernel \
        KERNEL_GIT=shallow \
        BOARD=T95zPlus-h618 \
        BRANCH=current \
        KERNEL_CONFIGURE=no \
        ENABLE_EXTENSIONS=ccache
else
    PESTER_TERMINAL=no ./compile.sh "${TARGET}" \
        KERNEL_GIT=shallow \
        BOARD=T95zPlus-h618 \
        BRANCH=current \
        RELEASE=trixie \
        BUILD_MINIMAL=yes \
        BUILD_DESKTOP=no \
        KERNEL_CONFIGURE=no \
        ENABLE_EXTENSIONS=ccache \
        COMPRESS_OUTPUTIMAGE=sha,xz
fi
