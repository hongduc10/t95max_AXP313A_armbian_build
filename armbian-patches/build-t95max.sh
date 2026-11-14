#!/usr/bin/env bash
set -e
WORKSPACE=$(dirname "$(readlink -f "$0")")
cd "${WORKSPACE}"

# Ensure Docker service is running
sudo service docker status >/dev/null 2>&1 || sudo service docker start

echo "======================================================================"
echo " BUILDING ARMBIAN FOR T95 MAX (H618 + DDR3 1.5V + AXP313A + BCM43342)"
echo "======================================================================"

# Run automated Docker build
PESTER_TERMINAL=no ./compile.sh \
    KERNEL_GIT=shallow \
    BOARD=T95zPlus-h618 \
    BRANCH=edge \
    RELEASE=trixie \
    BUILD_MINIMAL=yes \
    BUILD_DESKTOP=no \
    KERNEL_CONFIGURE=no \
    COMPRESS_OUTPUTIMAGE=sha,xz
