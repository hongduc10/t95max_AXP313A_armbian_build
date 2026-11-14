#!/bin/bash

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4
ARCH=$5

set -e

# Disable update kernel
mkdir -p /etc/apt/preferences.d
DISABLE_UPDATE_CONF=/etc/apt/preferences.d/disable-update
PKG_LIST=$(dpkg-query --show --showformat='${Package}\n')

function DISABLE_UPDATE() {
    echo -e "Package: $1\nPin: version *\nPin-Priority: -1\n" >> ${DISABLE_UPDATE_CONF}
}

cat /dev/null > ${DISABLE_UPDATE_CONF}
DISABLE_UPDATE armbian-firmware
DISABLE_UPDATE $(echo "${PKG_LIST}" | grep "armbian-bsp-cli-")
DISABLE_UPDATE $(echo "${PKG_LIST}" | grep "^linux-image-")
DISABLE_UPDATE $(echo "${PKG_LIST}" | grep "^linux-dtb-")
DISABLE_UPDATE $(echo "${PKG_LIST}" | grep "^linux-u-boot")

# htoprc
mkdir -p /etc/skel/.config/htop
cat <<EOF >/etc/skel/.config/htop/htoprc
show_cpu_usage=1
show_cpu_frequency=1
show_cpu_temperature=1
tree_view=1
hide_userland_threads=1

EOF

sudo apt update

sudo apt install dkms vim bluez -y

sudo rm /etc/rc.local
cat <<EOF >/etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

/usr/bin/hciattach -s 1500000 /dev/ttyS1 any 1500000 flow nosleep &
exit 0
EOF

sudo chmod +x /etc/rc.local