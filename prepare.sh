#!/bin/bash

echo -e "Making sure necessary tools and ccache are available for the build....\n\n"
# Ensure some build tools are installed and ready
if [ -z $(dpkg --print-foreign-architectures | grep i386) ]; then
  sudo dpkg --add-architecture i386
fi
sudo apt -y update
for NEEDED_TOOL in bc btrfs-progs build-essential bison flex ccache curl debconf-utils debootstrap device-tree-compiler dosfstools e2fsprogs eatmydata gcc gdisk jq lib32stdc++6 libc6-i386 libncurses5-dev libssl-dev lz4 lzop p7zip-full parted python-is-python3 zlib1g:i386 xfsprogs
do
  apt list --installed 2>/dev/null | grep -q "$NEEDED_TOOL"
  if [[ $? != "0" ]]; then
    sudo apt -y install ${NEEDED_TOOL}
    verify_action
  fi
done

if apt-cache policy qemu-user-static | grep -qE 'Candidate: [0-9]'; then
    sudo apt-get install -y qemu-user-static
    apt list --installed 2>/dev/null | grep -q qemu-user-static
    if [[ $? != "0" ]]; then
      sudo apt -y install qemu-user-static
      verify_action
    fi
elif apt-cache show qemu-user-binfmt &>/dev/null; then
    if ! dpkg -s qemu-user qemu-user-binfmt &>/dev/null; then
      sudo apt -y install qemu-user qemu-user-binfmt
      verify_action
      sudo cp -fv /usr/bin/qemu-aarch64 /usr/bin/qemu-aarch64-static
	  sudo cp -fv /usr/bin/qemu-arm /usr/bin/qemu-arm-static
    fi
else
    echo "ERROR: No supported QEMU user emulation package found."
    exit 1
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

CCACHE_MAX_SIZE="${CCACHE_MAX_SIZE:-50G}"
if [ ! -f "${CCACHE_DIR}/ccache.conf" ] || ! sudo grep -q "^max_size" "${CCACHE_DIR}/ccache.conf"; then
  # sudo, like every other file write here: the directory is bind mounted into the
  # chroot and root writes into it for the whole build, so an unprivileged tee can
  # fail on a tree from an earlier sudo-run build and silently leave the 5G default.
  # Only max_size is set.  Nothing here relaxes ccache's correctness checks:
  # include_file_mtime/ctime sloppiness would let a regenerated autoconf.h go
  # unnoticed, and the kernel regenerates exactly that on every defconfig change.
  echo "max_size = ${CCACHE_MAX_SIZE}" | sudo tee "${CCACHE_DIR}/ccache.conf" > /dev/null
fi

sudo /usr/sbin/update-ccache-symlinks

for CROSS_TOOL in gcc g++ cpp c++; do
  CROSS_BIN="${CROSS_COMPILE:-aarch64-linux-gnu-}${CROSS_TOOL}"
  if command -v "${CROSS_BIN}" > /dev/null 2>&1 && [ ! -e "/usr/lib/ccache/${CROSS_BIN}" ]; then
    sudo ln -sf /usr/bin/ccache "/usr/lib/ccache/${CROSS_BIN}"
  fi
done

[ -z $(echo $PATH | grep ccache) ] && export PATH=/usr/lib/ccache:$PATH
