#!/usr/bin/env bash

# ==============================================================================
# DOCKER & ARMBIAN BUILD SETUP SCRIPT FOR T95 MAX (H618 + DDR3 1.5V)
# ==============================================================================
# Self-maintained: Uses the official armbian/build repository + local
# armbian-patches/ in this project (no third-party fork dependency).
# Run inside WSL2 Ubuntu on an ext4 Linux filesystem (~/armbian-h618).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PATCHES_DIR="${SCRIPT_DIR}/armbian-patches"
TARGET_DIR="${HOME}/armbian-h618"
SYNC_ONLY=0

if [ "${1:-}" = "--sync" ] || [ "${1:-}" = "-s" ]; then
    SYNC_ONLY=1
fi

if [ "${SYNC_ONLY}" -eq 0 ]; then
    echo "=========================================================="
    echo " [1/4] Checking and installing Docker & required tools"
    echo "=========================================================="
    if ! command -v docker >/dev/null 2>&1; then
        echo "[+] Installing docker.io, git, and curl..."
        sudo apt-get update
        sudo apt-get install -y docker.io git curl
        sudo usermod -aG docker "${USER}"
        echo "[+] Added user ${USER} to the docker group."
    else
        echo "[+] Docker is already installed."
    fi

    if ! docker ps >/dev/null 2>&1; then
        echo "[+] Starting Docker service..."
        sudo service docker start || true
    fi

    echo "=========================================================="
    echo " [2/4] Cloning official Armbian Build Framework (armbian/build)"
    echo "=========================================================="
    if [ -d "${TARGET_DIR}" ]; then
        echo "[+] Directory ${TARGET_DIR} already exists, skipping clone."
    else
        echo "[+] Cloning https://github.com/armbian/build.git into ${TARGET_DIR}..."
        git clone --depth=1 https://github.com/armbian/build.git "${TARGET_DIR}"
    fi
elif [ ! -d "${TARGET_DIR}" ]; then
    echo "[!] ${TARGET_DIR} does not exist yet. Run without --sync first."
    exit 1
fi

echo "=========================================================="
echo " [3/4] Syncing self-maintained Board Config, Patches & Scripts"
echo "=========================================================="
if [ ! -d "${PATCHES_DIR}" ]; then
    echo "[!] Directory ${PATCHES_DIR} not found."
    exit 1
fi

cp -r "${PATCHES_DIR}/config/"* "${TARGET_DIR}/config/"
rm -rf "${TARGET_DIR}/userpatches"
cp -r "${PATCHES_DIR}/userpatches" "${TARGET_DIR}/"
cp "${PATCHES_DIR}/build-t95max.sh" "${TARGET_DIR}/"
chmod +x "${TARGET_DIR}/build-t95max.sh" "${TARGET_DIR}/userpatches/customize-image.sh"

# If building on newer armbian/build (e.g., sunxi-6.12 / sunxi-6.18),
# mirror the patches into matching sunxi-* kernel archive directories:
for KVER_DIR in "${TARGET_DIR}/patch/kernel/archive"/sunxi-*; do
    [ -d "${KVER_DIR}" ] || continue
    KNAME="$(basename "${KVER_DIR}")"
    if [ "${KNAME}" != "sunxi-6.7" ]; then
        mkdir -p "${TARGET_DIR}/userpatches/kernel/archive/${KNAME}"
        cp -f "${PATCHES_DIR}/userpatches/kernel/archive/sunxi-6.7/"*.patch "${TARGET_DIR}/userpatches/kernel/archive/${KNAME}/"
    fi
done

echo "[+] Synced config & userpatches from ${PATCHES_DIR}."

if [ "${SYNC_ONLY}" -eq 1 ]; then
    echo "[OK] Sync complete! Run: cd ${TARGET_DIR} && ./build-t95max.sh"
    exit 0
fi

echo "=========================================================="
echo " [4/4] Creating cleanup script (clean.sh)"
echo "=========================================================="
cat << 'EOF' > "${TARGET_DIR}/clean.sh"
#!/usr/bin/env bash
set -e
WORKSPACE=$(dirname "$(readlink -f "$0")")
cd "${WORKSPACE}"

echo "[+] Detaching any stuck loop mounts..."
sudo losetup -D 2>/dev/null || true

echo "[+] Removing temporary .tmp/ directory..."
sudo rm -rf .tmp/

echo "[+] Pruning stopped Docker containers and unused cache..."
docker container prune -f || true
docker image prune -f || true
docker builder prune -f || true

echo "[OK] Build cleanup complete!"
EOF
chmod +x "${TARGET_DIR}/clean.sh"

echo
echo "=========================================================="
echo " [SUCCESS] ARMBIAN BUILD ENVIRONMENT READY (SELF-MAINTAINED)!"
echo "=========================================================="
echo "Build full Debian 13 (trixie) image:"
echo "    cd ${TARGET_DIR} && ./build-t95max.sh"
echo
echo "Or build kernel .deb packages only:"
echo "    cd ${TARGET_DIR} && PESTER_TERMINAL=no ./compile.sh kernel BOARD=T95zPlus-h618 BRANCH=edge KERNEL_GIT=shallow"
echo "=========================================================="
