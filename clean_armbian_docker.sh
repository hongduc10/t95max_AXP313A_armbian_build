#!/usr/bin/env bash

# ==============================================================================
# DOCKER & ARMBIAN BUILD CLEANUP SCRIPT
# ==============================================================================
# Usage:
#   bash clean_armbian_docker.sh [option]
#
# Options:
#   1 (Default) : Quick clean (detach stuck loop devices, remove .tmp, prune stopped containers)
#   2           : Medium clean (also remove output/images, output/debs, prune docker cache)
#   3           : Deep purge (remove ~/armbian-h618 and all Docker images/volumes)
# ==============================================================================

set -euo pipefail

TARGET_DIR="${HOME}/armbian-h618"

echo "=========================================================="
echo " SELECT ARMBIAN & DOCKER CLEANUP LEVEL"
echo "=========================================================="
echo " 1) Quick clean : Detach loop mounts, remove .tmp, prune stopped containers"
echo " 2) Image clean : Remove output/ and .tmp, prune dangling Docker images/cache"
echo " 3) Deep purge  : Delete ~/armbian-h618 and run docker system prune -af"
echo "=========================================================="

CHOICE="${1:-}"
if [ -z "${CHOICE}" ]; then
    read -rp "Enter your choice [1/2/3] (Default: 1): " CHOICE
    CHOICE="${CHOICE:-1}"
fi

case "${CHOICE}" in
    1)
        echo "[+] Starting quick clean..."

        if command -v losetup >/dev/null 2>&1; then
            echo "[+] Detaching any stuck loop devices..."
            sudo losetup -D 2>/dev/null || true
        fi

        if [ -d "${TARGET_DIR}/.tmp" ]; then
            echo "[+] Removing ${TARGET_DIR}/.tmp..."
            sudo rm -rf "${TARGET_DIR}/.tmp"
        fi

        if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
            echo "[+] Pruning stopped Docker containers..."
            docker container prune -f || true
        fi
        echo "[OK] Quick clean complete!"
        ;;

    2)
        echo "[+] Starting medium clean..."

        sudo losetup -D 2>/dev/null || true

        if [ -d "${TARGET_DIR}" ]; then
            echo "[+] Removing .tmp and output in ${TARGET_DIR}..."
            sudo rm -rf "${TARGET_DIR}/.tmp" "${TARGET_DIR}/output"
        fi

        if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
            echo "[+] Pruning dangling Docker images and build cache..."
            docker image prune -f || true
            docker builder prune -f || true
        fi
        echo "[OK] Level 2 clean complete! Ready for a clean build."
        ;;

    3)
        echo "[!] WARNING: This will delete ${TARGET_DIR} and all Docker cache."
        read -rp "Are you sure you want to purge everything? (y/N): " CONFIRM
        if [[ "${CONFIRM}" =~ ^[yY]$ ]]; then
            echo "[+] Detaching loop mounts..."
            sudo losetup -D 2>/dev/null || true

            if [ -d "${TARGET_DIR}" ]; then
                echo "[+] Removing ${TARGET_DIR}..."
                sudo rm -rf "${TARGET_DIR}"
            fi

            if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
                echo "[+] Pruning all Docker containers, images, and volumes..."
                docker system prune -af --volumes || true
            fi
            echo "[OK] Full disk space reclaimed!"
        else
            echo "[-] Deep purge cancelled."
        fi
        ;;

    *)
        echo "[-] Invalid choice."
        exit 1
        ;;
esac
