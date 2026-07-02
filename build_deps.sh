#!/bin/bash

echo -e "Installing build dependencies and needed packages...\n\n"

if [ "$1" == "32" ]; then
  BIT="32"
  ARCH="arm-linux-gnueabihf"
  CHROOT_DIR="Arkbuild32"
else
  BIT="64"
  ARCH="aarch64-linux-gnu"
  CHROOT_DIR="Arkbuild"
fi

# Install additional needed packages and protect them from autoremove
while read NEEDED_PACKAGE; do
  if [[ ! "$NEEDED_PACKAGE" =~ ^# ]] && [[ ! -z "$NEEDED_PACKAGE" ]]; then
    install_package $BIT "${NEEDED_PACKAGE}"
    protect_package $BIT "${NEEDED_PACKAGE}"
  fi
done <needed_packages.txt

# Install build dependencies
while read NEEDED_DEV_PACKAGE; do
  if [[ ! "$NEEDED_DEV_PACKAGE" =~ ^# ]] && [[ ! -z "$NEEDED_DEV_PACKAGE" ]]; then
    install_package $BIT "${NEEDED_DEV_PACKAGE}"
  fi
done <needed_dev_packages.txt

# Bind ccache to chroot to speed up consecutive builds
[ ! -d "${CHROOT_DIR}/home/ark/Arkbuild_ccache" ] && sudo mkdir -p ${CHROOT_DIR}/home/ark/Arkbuild_ccache
sudo mount --bind ${PWD}/Arkbuild_ccache ${CHROOT_DIR}/home/ark/Arkbuild_ccache
sudo chroot ${CHROOT_DIR}/ bash -c "[ -z \$(echo \$CCACHE_DIR | grep ccache) ]" && echo -e "export CCACHE_DIR=/home/ark/Arkbuild_ccache" | sudo tee -a ${CHROOT_DIR}/root/.bashrc > /dev/null
sudo chroot ${CHROOT_DIR}/ bash -c "[ -z \$(echo \$PATH | grep ccache) ]" && echo -e "export PATH=/usr/lib/ccache:\$PATH" | sudo tee -a ${CHROOT_DIR}/root/.bashrc > /dev/null
sudo chroot ${CHROOT_DIR}/ bash -c "/usr/sbin/update-ccache-symlinks"

# Symlink fix for DRM headers (display / KMS)
sudo chroot ${CHROOT_DIR}/ bash -c "[ ! -e /usr/include/drm ] && ln -s /usr/include/libdrm/ /usr/include/drm || true"
