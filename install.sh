#! /usr/bin/env bash

set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo 'This script must be run as root!' >&2
    exit 1
fi

if ! [ -x "$(command -v dkms)" ]; then
    echo 'This script requires DKMS!' >&2
    exit 1
fi

if [ -f /usr/local/bin/xow ]; then
    echo 'Please uninstall xow!' >&2
    exit 1
fi

if [ -n "${SUDO_USER:-}" ]; then
    # Run as the invoking user to avoid Git's "unsafe repository" check.
    base_version=$(sudo -u "$SUDO_USER" git describe --tags --always --dirty 2>/dev/null \
        || sudo -u "$SUDO_USER" git rev-parse --short HEAD 2>/dev/null \
        || echo local)
else
    base_version=$(git describe --tags --always --dirty 2>/dev/null \
        || git rev-parse --short HEAD 2>/dev/null \
        || echo local)
fi

base_version=${base_version##v}
version="${base_version}-impulse"

source="/usr/src/xone-$version"
log="/var/lib/dkms/xone/$version/build/make.log"

if [ -n "$(dkms status xone)" ]; then
    echo -e 'Driver is already installed, uninstalling...\n'
    ./uninstall.sh --no-firmware
fi

echo "Installing xone $version..."
cp -r . "$source"
find "$source" -type f \( -name dkms.conf -o -name '*.c' \) -exec sed -i "s/#VERSION#/$version/" {} +

# Kernels built with Clang need external modules built with LLVM as well.
if [ -n "$(cat /proc/version | grep clang)" ]; then
    echo 'MAKE[0]="make V=1 LLVM=1 -C ${kernel_source_dir}'\
        'M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build"'\
        >> "$source/dkms.conf"
fi

if [ "${1:-}" == --debug ]; then
    echo 'ccflags-y += -DDEBUG' >> "$source/Kbuild"
fi

# Put the blacklist in place before DKMS runs so distro post-install hooks
# (including initramfs rebuilds) see it.
blacklist="/etc/modprobe.d/xone-blacklist.conf"
install -D -m 644 install/modprobe.conf "$blacklist"

if dkms install -m xone -v "$version" --force; then
    # Avoid conflicts between xpad and xone
    if lsmod | grep -q '^xpad'; then
        modprobe -r xpad
    fi

    # Avoid conflicts between mt76x2u and xone
    if lsmod | grep -q '^mt76x2u'; then
        modprobe -r mt76x2u
    fi
else
    rm -f "$blacklist"

    if [ -r "$log" ]; then
        cat "$log" >&2
    fi

    exit 1
fi

echo -e "\nxone installation finished\n"
