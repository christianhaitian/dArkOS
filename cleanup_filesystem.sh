#!/bin/bash

# Cleanup to reduce image size and remove build remnants
echo -e "Cleaning up filesystem"
call_chroot "rm -rf /home/ark/EmulationStation-fcamod"
call_chroot "rm -rf /home/ark/libgo2"
call_chroot "rm -rf /home/ark/linux-rga"
call_chroot "rm -rf /home/ark/${CHIPSET}_core_builds"
if [[ "${CHIPSET}" == "rk3566" ]]; then
  call_chroot "apt-mark hold ffmpeg"
fi
call_chroot "apt remove -y autotools-dev \
  build-essential \
  ccache \
  clang \
  cmake \
  g++ \
  liba52-0.7.4-dev \
  libasound2-dev \
  libboost-date-time-dev \
  libboost-dev \
  libboost-filesystem-dev \
  libboost-locale-dev \
  libboost-regex-dev \
  libboost-system-dev \
  libcurl4-openssl-dev \
  libdrm-dev \
  libeigen3-dev \
  libevdev-dev \
  libxext-dev \
  libfaad-dev \
  libflac-dev \
  libfontconfig1-dev \
  libfreeimage-dev \
  libfreetype-dev \
  libfribidi-dev \
  libglew-dev \
  libglfw3-dev \
  libjpeg62-turbo-dev \
  libluajit-5.1-dev \
  libmad0-dev \
  libmpeg2-4-dev \
  libncurses-dev \
  libnl-3-dev \
  libnl-genl-3-dev \
  libnl-route-3-dev \
  libogg-dev \
  libopenal-dev \
  libphysfs-dev \
  libpng-dev \
  libsdl2-dev \
  libsdl2-gfx-dev \
  libsdl2-image-dev \
  libsdl2-mixer-dev \
  libsdl2-ttf-dev \
  libshaderc-dev \
  libslirp-dev \
  libsm-dev \
  libsoxr-dev \
  libspeechd-dev \
  libssl-dev \
  libssl-ocaml-dev \
  libstdc++-12-dev \
  libtheora-dev \
  libudev-dev \
  libvlc-dev \
  libvlccore-dev \
  libvorbis-dev \
  libvorbisidec-dev \
  libvpx-dev \
  libvulkan-dev \
  libx11-dev \
  libx11-xcb1 \
  libxcb-dri2-0 \
  libyaml-dev \
  libzip-dev \
  ninja-build \
  pkg-config \
  premake4 \
  rapidjson-dev \
  zlib1g-dev"

call_chroot "apt -y autoremove"
call_chroot "apt -y clean"

if [[ "${BUILD_ARMHF}" == "y" ]]; then
  # Ensure additional needed packages are still in place
  while read NEEDED_PACKAGE; do
    if [[ ! "$NEEDED_PACKAGE" =~ ^# ]]; then
      install_package armhf ${NEEDED_PACKAGE}
    fi
  done <needed_packages32.txt
  sync Arkbuild
fi

# Ensure additional needed packages for Kodi are still in place if Kodi is built
if [[ "$CHIPSET" == *"3566"* ]] && [[ "$BUILD_KODI" == "y" ]]; then
  while read KODI_NEEDED_PACKAGE; do
    if [[ ! "$KODI_NEEDED_PACKAGE" =~ ^# ]] && [[ "$KODI_NEEDED_PACKAGE" != *"-dev"* ]]; then
      install_package 64 ${KODI_NEEDED_PACKAGE}
      protect_package 64 ${KODI_NEEDED_PACKAGE}
    fi
  done <kodi_needed_dev_packages.txt
fi

while read NEEDED_PACKAGE; do
  if [[ ! "$NEEDED_PACKAGE" =~ ^# ]]; then
    if [[ "$CHIPSET" != *"3566"* ]]; then
      install_package 64 ${NEEDED_PACKAGE}
      protect_package 64 ${NEEDED_PACKAGE}
    else
      if [[ "$NEEDED_PACKAGE" != "ffmpeg" ]]; then
        install_package 64 ${NEEDED_PACKAGE}
        protect_package 64 ${NEEDED_PACKAGE}
      else
        continue
      fi
    fi 
  fi
done <needed_packages.txt
sync

if [[ "$BUILD_BLUEALSA" == "y" ]]; then
  while read BLUETOOTH_NEEDED_PACKAGE; do
    if [[ ! "$BLUETOOTH_NEEDED_PACKAGE" =~ ^# ]]; then
      install_package 64 ${BLUETOOTH_NEEDED_PACKAGE}
      protect_package 64 ${BLUETOOTH_NEEDED_PACKAGE}
    fi
  done <bluetooth_needed_packages.txt
  call_chroot "systemctl disable watchforbtaudio bluetooth bluealsa"
fi

if [[ "${BUILD_ARMHF}" == "y" ]]; then
  cd Arkbuild/usr/lib/arm-linux-gnueabihf
  for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
  do
    sudo rm -fv ${LIB}
    sudo ln -sfv libMali.so ${LIB}
  done
  cd ../../../../

  # We need to replace the armhf version of libasound2t64 with the older libasound2 binary from Bookworm
  # because the current one supplied wtih Trixie has a ioctl error issue which leads to no audio for 32bit apps
  # This can be retrieved from snapshot.debian.org
  for (( ; ; ))
  do
    wget -t 3 -T 60 --no-check-certificate https://snapshot.debian.org/archive/debian/20230104T090216Z/pool/main/a/alsa-lib/libasound2_1.2.8-1%2Bb1_armhf.deb
    if [ $? == 0 ]; then
     break
    fi
	sleep 10
  done
  dpkg --fsys-tarfile libasound2_1.2.8-1+b1_armhf.deb | tar -xO ./usr/lib/arm-linux-gnueabihf/libasound.so.2.0.0 > libasound.so.2.0.0
  sudo mv -f libasound.so.2.0.0 Arkbuild/usr/lib/arm-linux-gnueabihf/
  call_chroot "chown root:root /usr/lib/arm-linux-gnueabihf/libasound.so.2.0.0"
  rm -f libasound2_1.2.8-1+b1_armhf.deb
fi

cd Arkbuild/usr/lib/aarch64-linux-gnu
for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
do
  sudo rm -fv ${LIB}
  sudo ln -sfv libMali.so ${LIB}
done
cd ../../../../

# Make sure the built librga shared libs are still available in aarch64
sudo cp -av Arkbuild/usr/lib/librga.so* Arkbuild/usr/lib/aarch64-linux-gnu/


if [[ "${ENABLE_CACHE}" == "y" ]]; then
  sudo rm -f Arkbuild/etc/apt/apt.conf.d/99proxy
  sudo sed -i '/127.0.0.1:3142\//s///' Arkbuild/etc/apt/sources.list
fi

call_chroot "ln -sfv /usr/lib/aarch64-linux-gnu/libSDL2.so /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0"
call_chroot "ln -sfv /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.${extension} /usr/lib/aarch64-linux-gnu/libSDL2.so"
if [[ "${BUILD_ARMHF}" == "y" ]]; then
  call_chroot "ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2.so /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0"
  call_chroot "ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension} /usr/lib/arm-linux-gnueabihf/libSDL2.so"
fi
# Ensure sdl2-config is linked to the proper version
call_chroot "ln -sfv /usr/lib/aarch64-linux-gnu/bin/sdl2-config /usr/bin/sdl2-config"
# Ensure sdl-image is symlinked properly
call_chroot "rm /lib/libSDL_image-1.2.so.0"
call_chroot "cd /lib && ln -sf $(find /lib/ -name libSDL_image-1.2.so.0.* | head -n 1) /lib/libSDL_image-1.2.so.0"
call_chroot "ldconfig -X"

if grep -qs "Arkbuild/home/ark/Arkbuild_ccache" /proc/mounts; then
  sudo umount -l Arkbuild/home/ark/Arkbuild_ccache
fi
sudo rm -rf Arkbuild/home/ark/Arkbuild_ccache
sudo rm -rf Arkbuild/var/log/journal
sudo rm Arkbuild/usr/sbin/policy-rc.d
sudo rm -f Arkbuild/etc/resolv.conf
sudo rm -f Arkbuild/etc/network/interfaces
# The build-time dpkg path-excludes (bootstrap_rootfs.sh) must not ship: on the
# device they would silently strip man pages and docs from everything the user
# ever installs with apt.
sudo rm -f Arkbuild/etc/dpkg/dpkg.cfg.d/01-darkos-slim
sudo rm -rf Arkbuild/usr/share/man/*
#for i in {1..8}; do sudo mkdir -p Arkbuild/usr/share/man/man"$i"; done
sudo rm -rf Arkbuild/var/lib/apt/lists/*
sudo rm -f Arkbuild/var/log/*.log
sudo rm -f Arkbuild/var/log/apt/*.log
sudo rm -f Arkbuild/tmp/reboot-needed
if [[ "${CHIPSET}" == "rk3566" ]]; then
  sudo rm -f Arkbuild/usr/share/vulkan/icd.d/*_icd.*
  # Ensure libvulkan is symlinked properly
  call_chroot "find /usr/lib/aarch64-linux-gnu -type f -name 'libvulkan.so*' -not -name 'libvulkan.so.1.3.274' -delete"
  call_chroot "rm -f /usr/lib/aarch64-linux-gnu/libvulkan.so.1 /usr/lib/aarch64-linux-gnu/libvulkan.so"
  call_chroot "ln -sf /usr/lib/aarch64-linux-gnu/libvulkan.so.1.3.274 /usr/lib/aarch64-linux-gnu/libvulkan.so.1"
  call_chroot "ln -sf /usr/lib/aarch64-linux-gnu/libvulkan.so.1 /usr/lib/aarch64-linux-gnu/libvulkan.so"
fi
