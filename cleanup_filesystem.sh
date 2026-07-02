#!/bin/bash

# Cleanup to reduce image size and remove build remnants
echo -e "Cleaning up filesystem"

# Remove build-time dev packages (runtime libs are kept and protected below)
call_chroot "apt remove -y autotools-dev \
  build-essential \
  ccache \
  cmake \
  g++ \
  libasound2-dev \
  libdrm-dev \
  libevdev-dev \
  libncurses-dev \
  libnl-3-dev \
  libnl-genl-3-dev \
  libnl-route-3-dev \
  libssl-dev \
  libudev-dev \
  ninja-build \
  pkg-config \
  zlib1g-dev"

call_chroot "apt -y autoremove"
call_chroot "apt -y clean"

# Re-assert and protect the runtime packages so autoremove did not take them
while read NEEDED_PACKAGE; do
  if [[ ! "$NEEDED_PACKAGE" =~ ^# ]] && [[ ! -z "$NEEDED_PACKAGE" ]]; then
    install_package 64 ${NEEDED_PACKAGE}
    protect_package 64 ${NEEDED_PACKAGE}
  fi
done <needed_packages.txt
sync

if [[ "${ENABLE_CACHE}" == "y" ]]; then
  sudo rm -f Arkbuild/etc/apt/apt.conf.d/99proxy
  sudo sed -i '/127.0.0.1:3142\//s///' Arkbuild/etc/apt/sources.list
fi

call_chroot "ldconfig"

if grep -qs "Arkbuild/home/ark/Arkbuild_ccache" /proc/mounts; then
  sudo umount -l Arkbuild/home/ark/Arkbuild_ccache
fi
sudo rm -rf Arkbuild/home/ark/Arkbuild_ccache
sudo rm -rf Arkbuild/var/log/journal
sudo rm -f Arkbuild/usr/sbin/policy-rc.d
sudo rm -f Arkbuild/etc/resolv.conf
sudo rm -f Arkbuild/etc/network/interfaces
sudo rm -rf Arkbuild/usr/share/man/*
sudo rm -rf Arkbuild/var/lib/apt/lists/*
sudo rm -f Arkbuild/var/log/*.log
sudo rm -f Arkbuild/var/log/apt/*.log
sudo rm -f Arkbuild/tmp/reboot-needed
