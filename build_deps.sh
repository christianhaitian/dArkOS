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

# Install additional needed packages and protect them from autoremove.
# Collected into one list first: install_package and protect_package both take a
# list, and one apt transaction under qemu costs far less than 94 of them.
NEEDED_PACKAGES=()
while read NEEDED_PACKAGE; do
  if [[ ! "$NEEDED_PACKAGE" =~ ^# ]] && [ -n "${NEEDED_PACKAGE}" ]; then
    NEEDED_PACKAGES+=( "${NEEDED_PACKAGE}" )
  fi
done <needed_packages.txt
install_package $BIT "${NEEDED_PACKAGES[@]}"
protect_package $BIT "${NEEDED_PACKAGES[@]}"

# Install build dependencies
NEEDED_DEV_PACKAGES=()
while read NEEDED_DEV_PACKAGE; do
  if [[ ! "$NEEDED_DEV_PACKAGE" =~ ^# ]] && [ -n "${NEEDED_DEV_PACKAGE}" ]; then
    NEEDED_DEV_PACKAGES+=( "${NEEDED_DEV_PACKAGE}" )
  fi
done <needed_dev_packages.txt
install_package $BIT "${NEEDED_DEV_PACKAGES[@]}"

# Default gcc and g++ to version 12 if gcc is newer than 12
GCC_VERSION=`sudo chroot ${CHROOT_DIR}/ bash -c "gcc --version | head -n 1 | awk '{print $3}' | cut -d' ' -f3 | cut -d'.' -f1"`
if (( GCC_VERSION > 12 )); then
  install_package $BIT gcc-12
  install_package $BIT g++-12
  sudo chroot ${CHROOT_DIR}/ bash -c "update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 10"
  sudo chroot ${CHROOT_DIR}/ bash -c "update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 20"
  sudo chroot ${CHROOT_DIR}/ bash -c "update-alternatives --set gcc /usr/bin/gcc-12"
  sudo chroot ${CHROOT_DIR}/ bash -c "update-alternatives --set g++ /usr/bin/g++-12"
fi

# Bind ccache to chroot to speed up consecutive builds
[ ! -d "${CHROOT_DIR}/home/ark/Arkbuild_ccache" ] && sudo mkdir -p ${CHROOT_DIR}/home/ark/Arkbuild_ccache
sudo mount --bind ${PWD}/Arkbuild_ccache ${CHROOT_DIR}/home/ark/Arkbuild_ccache
sudo chroot ${CHROOT_DIR}/ bash -c "[ -z \$(echo \$CCACHE_DIR | grep ccache) ]" && echo -e "export CCACHE_DIR=/home/ark/Arkbuild_ccache" | sudo tee -a ${CHROOT_DIR}/root/.bashrc > /dev/null
sudo chroot ${CHROOT_DIR}/ bash -c "[ -z \$(echo \$PATH | grep ccache) ]" && echo -e "export PATH=/usr/lib/ccache:\$PATH" | sudo tee -a ${CHROOT_DIR}/root/.bashrc > /dev/null
sudo chroot ${CHROOT_DIR}/ bash -c "/usr/sbin/update-ccache-symlinks"

# Symlink fix for DRM headers
sudo chroot ${CHROOT_DIR}/ bash -c "ln -s /usr/include/libdrm/ /usr/include/drm"

# Place libmali manually (assumes you have libmali.so or mali drivers ready)
ARCHITECTURE_ARRAY=("aarch64-linux-gnu")
if [[ "${BUILD_ARMHF}" == "y" ]]; then
  ARCHITECTURE_ARRAY+=("arm-linux-gnueabihf")
fi
for ARCHITECTURE in "${ARCHITECTURE_ARRAY[@]}"
do
  if [ "$ARCHITECTURE" == "aarch64-linux-gnu" ]; then
    FOLDER="aarch64"
  else
    FOLDER="armhf"
  fi
  sudo mkdir -p Arkbuild/usr/lib/${ARCHITECTURE}/
  wget --retry-connrefused --retry-on-http-error=429 --waitretry=20 -t 65 -T 60 --no-check-certificate -O ${whichmali} https://github.com/christianhaitian/${CHIPSET}_core_builds/raw/refs/heads/master/mali/${FOLDER}/${whichmali}
  sudo mv ${whichmali} Arkbuild/usr/lib/${ARCHITECTURE}/.
  cd Arkbuild/usr/lib/${ARCHITECTURE}
  sudo ln -sf ${whichmali} libMali.so
  for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
  do
    sudo rm -fv ${LIB}
    sudo ln -sfv libMali.so ${LIB}
  done
  cd ../../../../
done
sudo chroot Arkbuild/ ldconfig -X

# Install meson
sudo chroot ${CHROOT_DIR}/ bash -c "git clone https://github.com/mesonbuild/meson.git && ln -s /meson/meson.py /usr/bin/meson"

# Build and install librga
sudo chroot ${CHROOT_DIR}/ bash -c "cd /home/ark &&
  git clone https://github.com/christianhaitian/linux-rga.git &&
  cd linux-rga &&
  git checkout 1fc02d56d97041c86f01bc1284b7971c6098c5fb &&
  meson build && cd build &&
  meson compile &&
  cp -r librga.so* /usr/lib/${ARCH}/ &&
  cd .. &&
  mkdir -p /usr/local/include/rga &&
  cp -f drmrga.h rga.h RgaApi.h RockchipRgaMacro.h /usr/local/include/rga/
  "

# Build and install libgo2
sudo chroot ${CHROOT_DIR}/ bash -c "cd /home/ark &&
  git clone https://github.com/OtherCrashOverride/libgo2.git &&
  cd libgo2 &&
  premake4 gmake &&
  make -j$(nproc) &&
  cp libgo2.so* /usr/lib/${ARCH}/ &&
  mkdir -p /usr/include/go2 &&
  cp -L src/*.h /usr/include/go2/
  "
