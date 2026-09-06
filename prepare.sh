#!/bin/bash

echo -e "Making sure necessary tools and ccache are available for the build....\n\n"
# Ensure some build tools are installed and ready
if [ -z $(dpkg --print-foreign-architectures | grep i386) ]; then
  sudo dpkg --add-architecture i386
fi
sudo apt -y update
for NEEDED_TOOL in bc btrfs-progs build-essential bison flex ccache curl debconf-utils debootstrap device-tree-compiler dosfstools e2fsprogs eatmydata gcc gdisk jq lib32stdc++6 libc6-i386 libncurses5-dev libssl-dev lz4 lzop p7zip-full parted python-is-python3 qemu-user-static zlib1g:i386 xfsprogs
do
  apt list --installed 2>/dev/null | grep -q "$NEEDED_TOOL"
  if [[ $? != "0" ]]; then
    sudo apt -y install ${NEEDED_TOOL}
    verify_action
  fi
done

# aarch64 (and armhf) chroots only run on an x86 host if binfmt_misc has qemu-user
# handlers. Desktop systemd registers these via systemd-binfmt; containers and
# Cloud Agent VMs (tini/PID 1) do not, so do it here. Native aarch64 skips this.
if [ "$(uname -m)" != "aarch64" ]; then
  if [ ! -d /proc/sys/fs/binfmt_misc ]; then
    echo "binfmt_misc is not available; cannot emulate aarch64 chroots on this host."
    exit 1
  fi
  if ! mountpoint -q /proc/sys/fs/binfmt_misc; then
    sudo mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc
    verify_action
  fi
  for BINFMT_CONF in /usr/lib/binfmt.d/qemu-aarch64.conf /usr/lib/binfmt.d/qemu-arm.conf; do
    [ -f "${BINFMT_CONF}" ] || continue
    BINFMT_NAME="$(sed -E 's/^:([^:]+):.*/\1/' "${BINFMT_CONF}")"
    if [ ! -e "/proc/sys/fs/binfmt_misc/${BINFMT_NAME}" ]; then
      sudo bash -c "cat '${BINFMT_CONF}' > /proc/sys/fs/binfmt_misc/register"
      verify_action
    fi
  done
  echo "qemu-user binfmt handlers: $(ls /proc/sys/fs/binfmt_misc | grep -E '^qemu-' | tr '\n' ' ')"
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
  # Ensure the daemon is running. systemctl is a no-op without systemd as PID 1
  # (containers, Cloud Agent VMs), so fall back to launching apt-cacher-ng itself.
  sudo systemctl enable --now apt-cacher-ng 2>/dev/null || true
  sudo rm -rf /var/lib/apt/lists
  sudo rm -rf /var/cache/apt/*
  sudo systemctl restart apt-cacher-ng 2>/dev/null || true
  if ! pgrep -x apt-cacher-ng >/dev/null 2>&1; then
    sudo install -d -o apt-cacher-ng -g apt-cacher-ng /run/apt-cacher-ng \
      /var/cache/apt-cacher-ng /var/log/apt-cacher-ng
    sudo -u apt-cacher-ng /usr/sbin/apt-cacher-ng -c /etc/apt-cacher-ng \
      foreground=0 pidfile=/run/apt-cacher-ng/pid || true
    sleep 1
  fi
  if pgrep -x apt-cacher-ng >/dev/null 2>&1; then
    echo "apt-cacher-ng is running on 127.0.0.1:3142"
  else
    echo "apt-cacher-ng failed to start; set ENABLE_CACHE=n or fix the daemon."
    exit 1
  fi
fi


# Create ccache if it does not exist already
if [ ! -d "Arkbuild_ccache" ]; then
  mkdir Arkbuild_ccache
fi
export CCACHE_DIR=${PWD}/Arkbuild_ccache

# ccache defaults to a 5G cache.  A full dArkOS build compiles far more than 5G
# worth of objects (retroarch and its cores, ppsspp x2, gzdoom/lzdoom, scummvm,
# emulationstation, ...), so the cache evicts its own earlier entries inside a
# single run and the "subsequent builds are much faster" property never
# materialises.  Size it for the whole build instead.  The file lives in
# CCACHE_DIR, which is bind mounted into the chroot at /home/ark/Arkbuild_ccache,
# so host and chroot compilers share these settings.
CCACHE_MAX_SIZE="${CCACHE_MAX_SIZE:-40G}"
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

# update-ccache-symlinks only creates entries for compilers dpkg knows about, and
# the aarch64 toolchain used for the kernel is the Linaro 6.3.1 tarball that
# utils.sh puts on PATH, not a package.  Without these symlinks the kernel and
# u-boot cross compiles bypass ccache completely and are rebuilt in full on every
# run.  ccache re-resolves the real compiler through PATH, which still finds the
# Linaro one because /usr/lib/ccache is prepended in front of it below.
# Only for tools that actually exist behind the prefix.  Creating a masquerade
# link for a compiler that is not there (the Linaro tarball ships no
# aarch64-linux-gnu-cc) turns a clean "not found, fall back" probe in some
# configure script into a hard `ccache: Could not find compiler` mid-build.
# update-ccache-symlinks above deletes links whose /usr/bin/<name> is missing, so
# these are re-created here on every run by design.
for CROSS_TOOL in gcc g++ cpp c++; do
  CROSS_BIN="${CROSS_COMPILE:-aarch64-linux-gnu-}${CROSS_TOOL}"
  if command -v "${CROSS_BIN}" > /dev/null 2>&1 && [ ! -e "/usr/lib/ccache/${CROSS_BIN}" ]; then
    sudo ln -sf /usr/bin/ccache "/usr/lib/ccache/${CROSS_BIN}"
  fi
done

[ -z $(echo $PATH | grep ccache) ] && export PATH=/usr/lib/ccache:$PATH

# Default: use distcc to a native aarch64 cross gcc on x86-64 hosts. Override
# with USE_DISTCC=n (make or environment) to keep compiles inside qemu-user.
if [ -z "${USE_DISTCC}" ]; then
  if [ "$(uname -m)" = "x86_64" ]; then
    USE_DISTCC=y
  else
    USE_DISTCC=n
  fi
fi
export USE_DISTCC
if [[ "${USE_DISTCC}" == "y" ]]; then
  source ./distcc_cross.sh
  if distcc_host_start; then
    trap 'type distcc_host_stop >/dev/null 2>&1 && distcc_host_stop' EXIT
  else
    echo "distcc host start failed; chroot compiles will stay under qemu-user."
  fi
fi
