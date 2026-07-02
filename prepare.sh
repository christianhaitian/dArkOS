#!/bin/bash

echo -e "Making sure necessary tools and ccache are available for the build....\n\n"
# Ensure some build tools are installed and ready
HOST_ARCH=$(dpkg --print-architecture)
# 32-bit x86 host libs only exist (and are only needed) on amd64 hosts.
# On an arm64 host (e.g. Apple Silicon building natively) adding i386 fails.
if [ "$HOST_ARCH" == "amd64" ] && [ -z $(dpkg --print-foreign-architectures | grep i386) ]; then
  sudo dpkg --add-architecture i386
fi
sudo apt -y update
NEEDED_TOOLS="bc btrfs-progs build-essential bison flex ccache curl debconf-utils debootstrap device-tree-compiler dosfstools e2fsprogs eatmydata gcc gdisk jq libncurses5-dev libssl-dev lz4 lzop p7zip-full parted python-is-python3 qemu-user-static xfsprogs"
if [ "$HOST_ARCH" == "amd64" ]; then
  # 32-bit x86 libs for the prebuilt Rockchip tools, plus the aarch64 GCC-12
  # cross toolchain (newer GCC cannot build the old U-Boot / 4.4 BSP kernel).
  NEEDED_TOOLS="${NEEDED_TOOLS} lib32stdc++6 libc6-i386 zlib1g:i386 binutils-aarch64-linux-gnu gcc-12-aarch64-linux-gnu g++-12-aarch64-linux-gnu"
fi
for NEEDED_TOOL in ${NEEDED_TOOLS}
do
  apt list --installed 2>/dev/null | grep -q "$NEEDED_TOOL"
  if [[ $? != "0" ]]; then
    sudo apt -y install ${NEEDED_TOOL}
    verify_action
  fi
done

# Make the unversioned aarch64 cross-compiler resolve to GCC 12 so U-Boot's
# make.sh (which we cannot easily parameterize) builds with it too.
if [ "$HOST_ARCH" == "amd64" ] && command -v aarch64-linux-gnu-gcc-12 >/dev/null 2>&1; then
  sudo ln -sf /usr/bin/aarch64-linux-gnu-gcc-12 /usr/bin/aarch64-linux-gnu-gcc
  sudo ln -sf /usr/bin/aarch64-linux-gnu-g++-12 /usr/bin/aarch64-linux-gnu-g++
fi

# Ensure apt-cacher-ng is installed and if enabled for the build
if [[ "${ENABLE_CACHE}" == "y" ]]; then
  if ! apt list --installed 2>/dev/null | grep -q apt-cacher-ng; then
      echo "Installing apt-cacher-ng..."
      sudo debconf-get-selections | grep apt-cacher-ng > apt-cacher-ng.preseed
	  sudo debconf-set-selections apt-cacher-ng.preseed
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-cacher-ng
      verify_action
      sudo rm -f apt-cacher-ng.preseed
      # Allow any ports or apt downloads will most likely fail
      sudo sed -i "/\# AllowUserPorts:/c\AllowUserPorts: 0" /etc/apt-cacher-ng/acng.conf
      # Increase the number of package download retries as the mirrors can be busy
      sudo sed -i "/\# DlMaxRetries: /c\DlMaxRetries: 50000" /etc/apt-cacher-ng/acng.conf
      # If a package changes from what's in the cache, just redownload the whole package again
      # Do not error out with a 503 error [Server reports unexpected range] message
      sudo sed -i "/\# VfileUseRangeOps: /c\VfileUseRangeOps: 0" /etc/apt-cacher-ng/acng.conf
  fi
  # Ensure service is running
  sudo systemctl enable --now apt-cacher-ng
  sudo rm -rf /var/lib/apt/lists
  sudo rm -rf /var/cache/apt/*
  sudo systemctl restart apt-cacher-ng
fi


# Create ccache if it does not exist already
if [ ! -d "Arkbuild_ccache" ]; then
  mkdir Arkbuild_ccache
fi
export CCACHE_DIR=${PWD}/Arkbuild_ccache
sudo /usr/sbin/update-ccache-symlinks
[ -z $(echo $PATH | grep ccache) ] && export PATH=/usr/lib/ccache:$PATH
