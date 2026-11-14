

#!/usr/bin/env bash

# T95 Max / Allwinner H618 hardware audit
# READ-ONLY: Does not flash, erase, modify or reboot the box.

set -u

OUT="t95max-audit-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

echo "========================================"
echo " T95 MAX HARDWARE AUDIT"
echo "========================================"

if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: adb not installed."
    exit 1
fi

adb start-server >/dev/null 2>&1

if ! adb get-state >/dev/null 2>&1; then
    echo "ERROR: No authorized ADB device."
    adb devices -l
    exit 1
fi

SERIAL=$(adb get-serialno 2>/dev/null)
echo "Device: $SERIAL"
echo "Output: $OUT"

# Check root
ROOT=0
if adb shell su -c id 2>/dev/null | grep -q 'uid=0'; then
    ROOT=1
    echo "Root: YES"
else
    echo "Root: NO (some information may be restricted)"
fi

# Run command on Android
remote() {
    if [ "$ROOT" -eq 1 ]; then
        adb shell su -c "$1"
    else
        adb shell "$1"
    fi
}

# Save command output
collect() {
    local name="$1"
    local cmd="$2"

    echo "[+] Collecting $name"

    {
        echo "===== $name ====="
        echo "Command: $cmd"
        echo
        remote "$cmd"
    } > "$OUT/$name.txt" 2>&1
}

# -----------------------------------------
# 1. SYSTEM / SOC / CPU / RAM
# -----------------------------------------

collect "01_getprop" "getprop"
collect "02_cpuinfo" "cat /proc/cpuinfo"
collect "03_meminfo" "cat /proc/meminfo"
collect "04_uname" "uname -a"
collect "05_cmdline" "cat /proc/cmdline"
collect "06_version" "cat /proc/version"
collect "07_bootconfig" "cat /proc/bootconfig"
collect "08_mounts" "cat /proc/mounts"
collect "09_uptime" "cat /proc/uptime"
collect "10_interrupts" "cat /proc/interrupts"

# -----------------------------------------
# 2. DEVICE TREE
# -----------------------------------------

collect "11_device_tree_model" \
"cat /proc/device-tree/model; echo; cat /proc/device-tree/compatible"

collect "12_device_tree_dump" \
"if command -v dtc >/dev/null 2>&1; then dtc -I fs -O dts /proc/device-tree; elif command -v dtc >/dev/null 2>&1; then dtc -I fs -O dts /sys/firmware/devicetree/base; else echo 'DTC NOT INSTALLED'; find /proc/device-tree -type f 2>/dev/null; fi"

collect "13_device_tree_paths" \
"find /proc/device-tree -maxdepth 5 -type f 2>/dev/null"

collect "14_firmware_info" \
"ls -l /sys/firmware /sys/firmware/devicetree /sys/firmware/fdt 2>/dev/null"

# -----------------------------------------
# 3. BOOT / PARTITIONS / STORAGE
# -----------------------------------------

collect "15_partitions" "cat /proc/partitions"
collect "16_mtd" "cat /proc/mtd"
collect "17_block_devices" "ls -lR /dev/block 2>/dev/null"
collect "18_by_name" \
"ls -lR /dev/block/by-name /dev/block/platform 2>/dev/null"

collect "19_mmc" \
"ls -lR /sys/bus/mmc/devices /sys/class/mmc_host 2>/dev/null"

collect "20_block_sysfs" \
"ls -lR /sys/block 2>/dev/null"

collect "21_fstab" \
"cat /vendor/etc/fstab* /odm/etc/fstab* /etc/fstab 2>/dev/null"

collect "22_boot_files" \
"ls -lR /boot /vendor_boot /dev/block/by-name 2>/dev/null"

# -----------------------------------------
# 4. KERNEL CONFIG / MODULES
# -----------------------------------------

collect "23_kernel_config" \
"if [ -r /proc/config.gz ]; then zcat /proc/config.gz; else echo CONFIG_GZ_NOT_AVAILABLE; fi"

collect "24_modules" "cat /proc/modules"
collect "25_module_list" "ls -lR /lib/modules /vendor/lib/modules 2>/dev/null"
collect "26_kernel_log" "dmesg"

collect "27_hardware_errors" \
"dmesg | grep -Ei 'error|failed|timeout|fault|warning|unknown|not found|defer'"

# -----------------------------------------
# 5. ETHERNET / PHY / MDIO
# -----------------------------------------

collect "28_network_interfaces" "ip addr"
collect "29_network_routes" "ip route"
collect "30_network_links" "ip link"
collect "31_network_sysfs" \
"ls -lR /sys/class/net 2>/dev/null"

collect "32_phy_devices" \
"ls -lR /sys/bus/mdio_bus /sys/class/mdio_bus 2>/dev/null"

collect "33_phy_info" \
"for d in /sys/bus/mdio_bus/devices/*; do [ -e \"\$d\" ] || continue; echo ==== \$d ====; for f in phy_id phy_interface revision; do cat \$d/\$f 2>/dev/null; done; readlink -f \$d/driver; done"

collect "34_ethernet_driver" \
"for d in /sys/class/net/*; do echo ==== \$d ====; readlink -f \$d/device/driver; readlink -f \$d/phydev; cat \$d/address 2>/dev/null; cat \$d/speed 2>/dev/null; cat \$d/duplex 2>/dev/null; done"

collect "35_ethtool" \
"if command -v ethtool >/dev/null 2>&1; then for n in /sys/class/net/*; do n=\${n##*/}; echo ==== \$n ====; ethtool -i \$n; ethtool \$n; ethtool -T \$n; done; else echo ETHTOOL_NOT_INSTALLED; fi"

# -----------------------------------------
# 6. WIFI / SDIO
# -----------------------------------------

collect "36_sdio_devices" \
"for d in /sys/bus/sdio/devices/*; do [ -e \"\$d\" ] || continue; echo ==== \$d ====; for f in vendor device class modalias uevent; do echo --- \$f; cat \$d/\$f 2>/dev/null; done; readlink -f \$d/driver; done"

collect "37_sdio_bus" \
"ls -lR /sys/bus/sdio /sys/class/mmc_host 2>/dev/null"

collect "38_wifi_usb" \
"ls -lR /sys/bus/usb/devices 2>/dev/null"

collect "39_wifi_interfaces" \
"ip link; iw dev 2>/dev/null; rfkill list 2>/dev/null"

collect "40_wifi_driver" \
"for d in /sys/class/net/*; do echo ==== \$d ====; readlink -f \$d/device/driver; done"

collect "41_wifi_firmware" \
"ls -lR /vendor/firmware /vendor/etc/firmware /lib/firmware /system/etc/firmware 2>/dev/null"

collect "42_wifi_log" \
"dmesg | grep -Ei 'wifi|wlan|sdio|brcm|broadcom|rtl|realtek|uwe|uwe5622|xr819|firmware|wireless|wlan0'"

collect "43_wifi_dumpsys" "dumpsys wifi"

# -----------------------------------------
# 7. USB / BLUETOOTH / UART
# -----------------------------------------

collect "44_usb_devices" \
"ls -lR /sys/bus/usb/devices 2>/dev/null"

collect "45_usb_drivers" \
"ls -lR /sys/bus/usb/drivers 2>/dev/null"

collect "46_usb_log" \
"dmesg | grep -Ei 'usb|xhci|ehci|ohci|dwc2|dwc3'"

collect "47_bluetooth" \
"ls -lR /sys/bus/serial/devices /sys/class/bluetooth /sys/bus/platform/drivers 2>/dev/null"

collect "48_bluetooth_log" \
"dmesg | grep -Ei 'bluetooth|hci|btusb|uart|firmware'"

collect "49_serial_ports" \
"ls -lR /dev/tty* /sys/class/tty 2>/dev/null"

collect "50_pinctrl" \
"ls -lR /sys/kernel/debug/pinctrl 2>/dev/null"

# -----------------------------------------
# 8. PMIC / POWER / CLOCK / GPIO
# -----------------------------------------

collect "51_regulators" \
"ls -lR /sys/class/regulator 2>/dev/null"

collect "52_regulator_details" \
"for d in /sys/class/regulator/*; do echo ==== \$d ====; for f in name state microvolts min_microvolts max_microvolts; do cat \$d/\$f 2>/dev/null; done; done"

collect "53_gpio" \
"ls -lR /sys/class/gpio /sys/bus/platform/drivers/gpio* 2>/dev/null"

collect "54_clocks" \
"ls -lR /sys/kernel/debug/clk 2>/dev/null"

collect "55_i2c_devices" \
"ls -lR /sys/bus/i2c/devices 2>/dev/null"

collect "56_power_log" \
"dmesg | grep -Ei 'pmic|axp|regulator|power|voltage|thermal|cpu.*freq|opp'"

# -----------------------------------------
# 9. GPU / HDMI / DISPLAY
# -----------------------------------------

collect "57_gpu_devices" \
"ls -lR /sys/bus/platform/devices /sys/class/devfreq 2>/dev/null"

collect "58_gpu_driver" \
"ls -lR /sys/bus/platform/drivers/panfrost /sys/bus/platform/drivers/mali 2>/dev/null"

collect "59_drm" \
"ls -lR /sys/class/drm 2>/dev/null"

collect "60_drm_connector" \
"for d in /sys/class/drm/*; do echo ==== \$d ====; for f in status enabled modes; do echo --- \$f; cat \$d/\$f 2>/dev/null; done; done"

collect "61_display_dumpsys" "dumpsys display"
collect "62_surfaceflinger" "dumpsys SurfaceFlinger"
collect "63_screen_resolution" "wm size"
collect "64_gpu_log" \
"dmesg | grep -Ei 'drm|hdmi|tcon|display|mali|panfrost|gpu|edid|phy'"

# -----------------------------------------
# 10. AUDIO
# -----------------------------------------

collect "65_audio_devices" \
"ls -lR /dev/snd /sys/class/sound 2>/dev/null"

collect "66_audio_cards" \
"cat /proc/asound/cards /proc/asound/pcm 2>/dev/null"

collect "67_audio_log" \
"dmesg | grep -Ei 'audio|sound|codec|hdmi.*audio|i2s|spdif|snd'"

# -----------------------------------------
# 11. TEMPERATURE / CPU FREQUENCY
# -----------------------------------------

collect "68_thermal" \
"ls -lR /sys/class/thermal 2>/dev/null"

collect "69_cpu_frequency" \
"ls -lR /sys/devices/system/cpu/cpufreq /sys/devices/system/cpu/cpu0/cpufreq 2>/dev/null"

collect "70_cpu_topology" \
"ls -lR /sys/devices/system/cpu 2>/dev/null"

# -----------------------------------------
# 12. ANDROID LOGS / SERVICES
# -----------------------------------------

collect "71_android_services" "service list"
collect "72_dumpsys_services" "dumpsys -l"

collect "73_android_hardware_log" \
"logcat -b all -d | grep -Ei 'wifi|wlan|sdio|ethernet|eth0|hdmi|drm|gpu|mali|firmware|bluetooth|mmc|usb'"

collect "74_android_display_log" \
"logcat -b all -d | grep -Ei 'SurfaceFlinger|DisplayManager|HDMI|HWC|Composer'"

# -----------------------------------------
# 13. DEVICE IDENTITY / SUMMARY
# -----------------------------------------

collect "75_device_identity" \
"echo MODEL; getprop ro.product.model; echo BOARD; getprop ro.product.board; echo HARDWARE; getprop ro.hardware; echo SOC; getprop ro.board.platform; echo MANUFACTURER; getprop ro.product.manufacturer; echo ANDROID; getprop ro.build.version.release; echo BUILD; getprop ro.build.fingerprint"

# -----------------------------------------
# 14. PACKAGE RESULTS
# -----------------------------------------

{
    echo "T95 MAX AUDIT"
    echo "Date: $(date)"
    echo "ADB serial: $SERIAL"
    echo "Root available: $ROOT"
    echo
    echo "Files collected:"
    ls -lh "$OUT"
} > "$OUT/README.txt"

# Create archive
if command -v zip >/dev/null 2>&1; then
    zip -qr "${OUT}.zip" "$OUT"
elif command -v tar >/dev/null 2>&1; then
    tar -czf "${OUT}.tar.gz" "$OUT"
fi

echo
echo "========================================"
echo " AUDIT COMPLETED"
echo "========================================"
echo "Folder: $OUT"

if [ -f "${OUT}.zip" ]; then
    echo "Archive: ${OUT}.zip"
elif [ -f "${OUT}.tar.gz" ]; then
    echo "Archive: ${OUT}.tar.gz"
fi

echo
echo "Please send the ZIP/TAR.GZ file for analysis."

