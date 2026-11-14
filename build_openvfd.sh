#!/usr/bin/env bash

# ==============================================================================
# LOCAL OPENVFD CROSS-BUILD SCRIPT (T95 MAX H618 + FD655)
# ==============================================================================
# Run inside WSL2 Ubuntu AFTER Armbian build finishes (reuses the built kernel
# worktree in ~/armbian-h618/cache/sources/linux-kernel-worktree/).
#
# Mode:
#   - Uses local `aarch64-linux-gnu-gcc` directly (no Docker) if installed.
#   - Falls back to the Armbian Docker image automatically if cross-compiler
#     is not installed on the host. (Force with USE_DOCKER=0 or USE_DOCKER=1.)
#
# Output:
#   ~/armbian-h618/output/openvfd/openvfd-t95max-arm64.tar.gz
# ==============================================================================

set -euo pipefail

ARMBIAN_DIR="${ARMBIAN_DIR:-${HOME}/armbian-h618}"
OPENVFD_SRC="${ARMBIAN_DIR}/cache/sources/openvfd"
OUT_DIR="${ARMBIAN_DIR}/output/openvfd"
REPO_URL="https://github.com/Jajo7109/H616-T95-open-vfd.git"
USE_DOCKER="${USE_DOCKER:-auto}"

echo "=========================================================="
echo " [1/4] Locating built kernel worktree"
echo "=========================================================="
KSRC="${KSRC:-}"
if [ -z "${KSRC}" ]; then
    for d in "${ARMBIAN_DIR}/cache/sources/linux-kernel-worktree"/*; do
        if [ -f "${d}/.config" ] && [ -f "${d}/Module.symvers" ]; then
            KSRC="${d}"
            break
        fi
    done
fi
if [ -z "${KSRC}" ] || [ ! -f "${KSRC}/Module.symvers" ]; then
    echo "[!] Built kernel worktree (with .config & Module.symvers) not found under:"
    echo "    ${ARMBIAN_DIR}/cache/sources/linux-kernel-worktree/"
    echo "    Finish building Armbian kernel/image first, or pass KSRC=/path/to/kernel."
    exit 1
fi
echo "[+] Using kernel tree: ${KSRC}"

if [ "${USE_DOCKER}" = "auto" ]; then
    if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        USE_DOCKER=0
    else
        USE_DOCKER=1
    fi
fi

echo "=========================================================="
echo " [2/4] Fetching H616-T95-open-vfd source"
echo "=========================================================="
if [ -d "${OPENVFD_SRC}/.git" ]; then
    git -C "${OPENVFD_SRC}" pull --ff-only
else
    rm -rf "${OPENVFD_SRC}"
    git clone --depth=1 "${REPO_URL}" "${OPENVFD_SRC}"
fi

echo "=========================================================="
echo " [3/4] Cross-compiling openvfd.ko & OpenVFDService"
echo "=========================================================="
if [ "${USE_DOCKER}" = "0" ]; then
    echo "[+] Building directly on host using $(command -v aarch64-linux-gnu-gcc) (no Docker)"
    make -C "${OPENVFD_SRC}/driver" clean || true
    make -C "${KSRC}" M="${OPENVFD_SRC}/driver" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" modules
    rm -f "${OPENVFD_SRC}/OpenVFDService"
    aarch64-linux-gnu-gcc -O2 -Wall -o "${OPENVFD_SRC}/OpenVFDService" "${OPENVFD_SRC}/OpenVFDService.c"
    chmod +x "${OPENVFD_SRC}/OpenVFDService"
else
    DOCKER_IMG="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^armbian\.local\.only/armbian-build:' | grep -v ':initial$' | head -n 1 || true)"
    if [ -z "${DOCKER_IMG}" ]; then
        DOCKER_IMG="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^ghcr\.io/armbian/docker-armbian-build:armbian-debian-trixie' | head -n 1 || true)"
    fi
    if [ -z "${DOCKER_IMG}" ]; then
        echo "[!] No aarch64-linux-gnu-gcc on host and no Armbian Docker image found."
        echo "    Install cross-compiler on WSL2: sudo apt install -y gcc-aarch64-linux-gnu make"
        exit 1
    fi
    echo "[+] Building in Docker image: ${DOCKER_IMG}"
    docker run --rm \
        -v "${KSRC}:/ksrc" \
        -v "${OPENVFD_SRC}:/openvfd" \
        -w /openvfd \
        "${DOCKER_IMG}" \
        bash -lc '
            set -euo pipefail
            make -C /openvfd/driver clean || true
            make -C /ksrc M=/openvfd/driver ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j"$(nproc)" modules
            rm -f /openvfd/OpenVFDService
            aarch64-linux-gnu-gcc -O2 -Wall -o /openvfd/OpenVFDService /openvfd/OpenVFDService.c
            chmod +x /openvfd/OpenVFDService
        '
fi

echo "=========================================================="
echo " [4/4] Packaging openvfd-t95max-arm64.tar.gz"
echo "=========================================================="
PKG_DIR="${OUT_DIR}/pkg"
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}"

cp "${OPENVFD_SRC}/driver/openvfd.ko" "${PKG_DIR}/"
cp "${OPENVFD_SRC}/OpenVFDService" "${PKG_DIR}/"

# Port I (PI) = 8 * 32 = 256 -> PI5 = 261, PI10 = 266
cat << 'EOF' > "${PKG_DIR}/vfd.conf"
# T95 Max (H618 + FD655) OpenVFD configuration
# Port I (PI) = 8 * 32 = 256 -> PI5 = 261, PI10 = 266
vfd_gpio_clk='0,261,0x00'
vfd_gpio_dat='0,266,0x00'
vfd_gpio_stb='0x00,0x00,0xFF'
vfd_gpio_chip_name='300b000.pinctrl'

vfd_chars='0,1,2,3,4'
vfd_dot_bits='0,1,2,3,4,5,6'
vfd_display_type='0x01,0x00,0x00,0x06'
EOF

cat << 'EOF' > "${PKG_DIR}/openvfd.service"
[Unit]
Description=OpenVFD LED Display Service
After=multi-user.target

[Service]
Type=simple
Environment="OPTS=-24h"
ExecStartPre=/bin/sh -c '. /opt/H616-T95-open-vfd/vfd.conf; /sbin/modprobe openvfd vfd_gpio_clk=$vfd_gpio_clk vfd_gpio_dat=$vfd_gpio_dat vfd_gpio_stb=$vfd_gpio_stb vfd_gpio_chip_name=$vfd_gpio_chip_name vfd_chars=$vfd_chars vfd_dot_bits=$vfd_dot_bits vfd_display_type=$vfd_display_type'
ExecStart=/opt/H616-T95-open-vfd/OpenVFDService $OPTS
ExecStopPost=-/sbin/rmmod openvfd
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat << 'EOF' > "${PKG_DIR}/install.sh"
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KVER="$(uname -r)"

sudo mkdir -p "/lib/modules/${KVER}/extra" /opt/H616-T95-open-vfd
sudo cp -f "${SCRIPT_DIR}/openvfd.ko" "/lib/modules/${KVER}/extra/"
sudo depmod -a "${KVER}"

sudo cp -f "${SCRIPT_DIR}/OpenVFDService" "${SCRIPT_DIR}/vfd.conf" /opt/H616-T95-open-vfd/
sudo chmod +x /opt/H616-T95-open-vfd/OpenVFDService

sudo cp -f "${SCRIPT_DIR}/openvfd.service" /etc/systemd/system/openvfd.service
sudo systemctl daemon-reload
sudo systemctl enable openvfd.service
sudo systemctl restart openvfd.service
echo "[OK] OpenVFD installed and started!"
EOF
chmod +x "${PKG_DIR}/install.sh"

tar -C "${PKG_DIR}" -czf "${OUT_DIR}/openvfd-t95max-arm64.tar.gz" .

echo
echo "[OK] Build complete!"
echo "Output bundle: ${OUT_DIR}/openvfd-t95max-arm64.tar.gz"
echo "On the T95 Max box, extract and run:"
echo "    tar -xzf openvfd-t95max-arm64.tar.gz && sudo bash install.sh"
