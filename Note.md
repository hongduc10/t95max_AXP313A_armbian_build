# HARDWARE SPECIFICATIONS & ARMBIAN BUILD/INSTALL GUIDE FOR T95 MAX (H618)

---

## 1. HARDWARE SPECIFICATIONS (Extracted from Box Dump Audit)

| Component | Technical Details |
| :--- | :--- |
| **Model / Board** | **T95MAX-H618-A5** (PCB marking: `T95 Max AXP313A V3.0`) |
| **SoC (CPU)** | **Allwinner H618** (`sun50iw9p1`), Quad-core ARM Cortex-A53 (ARMv8 64-bit, Part `0xd03` r0p4) up to ~1.5 GHz |
| **GPU** | ARM Mali-G31 MP2 (OpenGL ES 3.2, Vulkan 1.1; Linux mainline uses `panfrost`) |
| **RAM** | **1 GB DDR3** (8x Samsung K4B1G... 1Gb chips = 1GB total) |
| **DRAM Voltage (VDD_DRAM)** | **1.500 V** (Supplied via AXP313A DCDC3 — *critical when building U-Boot*) |
| **Internal Storage (eMMC)** | **8 GB** Toshiba THGBMBG6D1KBAIL (eMMC 5.0/5.1, `008GE0`, ~7.28 GiB; `mmcblk2` on Armbian 6.7.12, `4022000.mmc`) |
| **MicroSD Slot** | External TF card slot (`mmcblk0` / `mmcblk1` depending on kernel probe order, `4020000.mmc`), supports direct SD boot |
| **PMIC** | **X-Powers AXP313A** (compatible with AXP1530) on `i2c-5` (`0x36`, `7081400.twi`):<br>- **DCDC1**: 0.96V (VDD_SYS)<br>- **DCDC2**: 1.05V (VDD_CPU)<br>- **DCDC3**: 1.50V (VDD_DRAM - DDR3)<br>- **ALDO1**: 1.80V (VCC_1V8)<br>- **DLDO1**: 3.30V (VCC_3V3) |
| **Ethernet (LAN)** | **100 Mbps** Fast Ethernet using Allwinner internal ePHY (PHY ID: `0x00441400`, RMII mode, `dwmac-sun8i`) |
| **Wi-Fi** | Module labeled **LG642**; **Broadcom BCM43342** (`BCM43342/1`, SDIO ID: `02d0:4334`, bus `4021000.mmc`). Linux mainline uses `brcmfmac` (patched with `BRCM_CC_43342_CHIP_ID`) + `brcmfmac43342-sdio.bin` / `.txt` |
| **Bluetooth** | Broadcom UART Bluetooth over `ttyS1` (`5000400.serial`), firmware `BCM43342.hcd` |
| **Front LED Display** | **FD655** 4-digit 7-segment controller (Android module `h6_fd655`, pins `PI5`/`PI10`; Linux supported via `openvfd`) |
| **Debug UART** | **UART0** (`5000000.uart`, `PH0-TX` / `PH1-RX`), Baudrate: **`115200`** (8N1, 3.3V logic) |
| **Stock Firmware (Android)** | Android 12 (API 31, Kernel 5.4.125 `armv8l` 32-bit userland, OEM: `sunvell_H618_12.0`, DTB compatible: `allwinner,h616 arm,sun50iw9p1`) |

---

## 2. HARDWARE COMPATIBILITY & FLASHING MICROSD

### A. Peripheral Status with Self-Maintained Patches

| Peripheral | Actual T95 Max Hardware | Armbian Status |
| :--- | :--- | :--- |
| **Ethernet (LAN)** | Internal 100M ePHY (`0x00441400`, RMII) | **Works OOB** (`dwmac-sun8i`) |
| **USB** | 2x USB ports on EHCI/OHCI | **Works OOB** |
| **SD Card & eMMC** | TF slot + Toshiba 8GB eMMC | **Works OOB** (U-Boot + DTS configured for 1.5V DDR3) |
| **Wi-Fi (2.4G / 5G)** | **LG642 = Broadcom BCM43342** (`02d0:4334`) | **Works** with `0995-brcmfmac-add-bcm43342-support.patch` + `armbian-firmware` |
| **7-Segment LED** | **FD655** (`PI5`/`PI10`) | **DT node enabled** (`0996-dts-t95zplus-h618-add-openvfd.patch`); requires out-of-tree `openvfd.ko` |
| **Bluetooth** | Broadcom UART BT (`BCM43342.hcd`) | **Needs UART BT DT / `hciattach` setup** |

---

### B. Flashing & Booting from MicroSD
1. **Requirements:** MicroSD card (>= 8GB, Class 10 / A1) and **Rufus** or **balenaEtcher**.
2. **Write Image:** Decompress `.img.xz` / `.img.gz` and flash the `.img` to the MicroSD card.
3. **Boot the Box:**
   - Unplug power, insert the MicroSD card, connect RJ45 Ethernet (or HDMI + USB keyboard), then plug in power.
   - *Tip:* If the box boots into stock Android instead of SD, hold the Reset button inside the 3.5mm AV jack with a toothpick while plugging in power for 5-8 seconds.
4. **First Login:**
   - Find the box IP from your router and connect via `ssh root@<BOX-IP>` (default Armbian password: `1234`).

---

## 3. SELF-MAINTAINED DOCKER BUILD SETUP (`setup_armbian_docker.sh`)

To build your own clean Armbian kernel or image using official `armbian/build` + your local patches, use [setup_armbian_docker.sh](file:///d:/T95/t95max-audit-20261112-210427/setup_armbian_docker.sh).

### A. What the Setup Script Does
1. Checks and installs Docker + Git inside WSL2 (if missing).
2. Clones the **official Armbian build framework** (`https://github.com/armbian/build.git`) into `~/armbian-h618` (on an ext4 Linux filesystem), with no third-party fork dependency.
3. Syncs your self-maintained board config, U-Boot & Kernel patches from `armbian-patches/` into `~/armbian-h618`:
   - Sets `CONFIG_AXP_DCDC3_VOLT=1500` (U-Boot) and `reg_dcdc3 = 1500000` uV (Kernel DTS) for 1.5V Samsung DDR3 RAM.
   - Adds kernel patch `0995-brcmfmac-add-bcm43342-support.patch` to enable **Broadcom BCM43342** Wi-Fi.
   - Adds DTS patch `0996-dts-t95zplus-h618-add-openvfd.patch` to enable the `openvfd` node for the **FD655** LED display.
   - Clean `customize-image.sh` (no third-party mirror scripts or unused firmware).
   - Creates `build-t95max.sh` configured for **Debian 13 (`trixie`)** with `PESTER_TERMINAL=no` and `KERNEL_GIT=shallow`.

### B. Running Setup & Build
Inside WSL2 Ubuntu:
```bash
bash /mnt/d/T95/t95max-audit-20261112-210427/setup_armbian_docker.sh
```

**Option 1: Build Kernel `.deb` Packages Only (fast, patch Wi-Fi / DTB on a running box)**
```bash
cd ~/armbian-h618
PESTER_TERMINAL=no ./compile.sh kernel BOARD=T95zPlus-h618 BRANCH=edge KERNEL_GIT=shallow
```
Output packages are in `~/armbian-h618/output/debs/`. Copy and install them on the running box:
```bash
scp ~/armbian-h618/output/debs/linux-{image,dtb,headers}-edge-sunxi64_*.deb root@<BOX-IP>:/tmp/
ssh root@<BOX-IP> "dpkg -i /tmp/linux-*.deb && apt-get --fix-broken install -y && reboot"
```
*(Tip: If `apt-get update` hits `403 Forbidden` over IPv6 from an Armbian mirror, force IPv4 with `echo 'Acquire::ForceIPv4 true;' > /etc/apt/apt.conf.d/99force-ipv4`.)*

**Option 2: Build Full Debian 13 (`trixie`) Image**
```bash
cd ~/armbian-h618
./build-t95max.sh
```
The output image will be in `~/armbian-h618/output/images/` (decompress `.img.xz` and flash with Rufus / balenaEtcher).

### C. Post-Boot Setup & Persistent Wi-Fi
1. **Verify Wi-Fi (`BCM43342`):**
   ```bash
   dmesg | grep brcmfmac
   nmcli dev status
   ```
2. **Persistent Wi-Fi Connection (auto-reconnects after reboot, disables Wi-Fi powersave):**
   Save this as `connect_wifi.sh` on the box and run `bash connect_wifi.sh "<SSID>" "<PASSWORD>"`:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   SSID="${1:-}"
   PASS="${2:-}"

   if [ -z "$SSID" ]; then
       read -rp "Enter Wi-Fi SSID: " SSID
   fi
   if [ -z "$PASS" ]; then
       read -rsp "Enter Wi-Fi password for '$SSID': " PASS
       echo
   fi

   nmcli connection delete "$SSID" 2>/dev/null || true
   nmcli dev wifi connect "$SSID" password "$PASS" ifname wlan0 name "$SSID"
   nmcli connection modify "$SSID" \
       connection.autoconnect yes \
       connection.autoconnect-retries 0 \
       802-11-wireless.powersave 2

   nmcli -f NAME,TYPE,DEVICE,STATE connection show --active
   ip -4 addr show wlan0
   ```
   NetworkManager stores the profile in `/etc/NetworkManager/system-connections/` and automatically reconnects on every boot.

3. **Install FD655 LED Driver (`openvfd`):**
   The `openvfd` node is enabled in the Device Tree (`/proc/device-tree/openvfd`), while `openvfd.ko` is an out-of-tree module. Once booted on the new kernel (with `linux-headers` installed), clone `H616-T95-open-vfd` / `linux_openvfd` on the box, run `make && make modules_install`, and start `OpenVFDService` configured for pins `PI5`/`PI10`.

---

## 4. CLEANING DOCKER & BUILD CACHE (`clean_armbian_docker.sh`)

Use [clean_armbian_docker.sh](file:///d:/T95/t95max-audit-20261112-210427/clean_armbian_docker.sh) in WSL2:
```bash
bash /mnt/d/T95/t95max-audit-20261112-210427/clean_armbian_docker.sh
```
Levels:
1. **Level 1 (Quick clean):** Detach stuck loop mounts, delete `.tmp/`, prune stopped containers.
2. **Level 2 (Image clean):** Also delete `output/`, prune dangling Docker images and build cache.
3. **Level 3 (Deep purge):** Delete `~/armbian-h618` and run `docker system prune -af --volumes`.

Manual quick commands:
```bash
sudo losetup -D
cd ~/armbian-h618 && sudo rm -rf .tmp/ output/
docker system prune -f
```

---

## 5. FLASHING TO INTERNAL EMMC (OPTIONAL)
> **Important (erases stock Android):** This overwrites the entire internal eMMC. Test **Wi-Fi (`wlan0`), LAN, USB, and reboot** thoroughly on the MicroSD card first.
> Always verify block devices with `lsblk` before flashing:
> - Root `/` (`29.7G` or your SD card size): MicroSD card currently booting.
> - **`/dev/mmcblk2`** (`7.3G`, chip `008GE0`): Internal 8 GB eMMC.

Steps on the running box (booted from MicroSD):
1. Run:
   ```bash
   sudo armbian-install
   ```
2. Select **Boot from eMMC - system on eMMC** (option `1`).
3. Select the eMMC target device **`/dev/mmcblk2`** (`7.3G`).
4. Select **`ext4`** as the filesystem.
5. Once finished, run `poweroff`, **remove the MicroSD card**, and power on the box to boot directly from internal eMMC.
