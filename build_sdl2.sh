#!/bin/bash

if [ "$CHIPSET" == "rk3326" ]; then
  sub_folder=""
else
  sub_folder="build"
fi

if [ "$1" == "32" ]; then
  BITNESS="32"
  ARCH="arm-linux-gnueabihf"
  CHROOT_DIR="Arkbuild32"
else
  BITNESS="64"
  ARCH="aarch64-linux-gnu"
  CHROOT_DIR="Arkbuild"
fi

# Build and install SDL2
if [ "$ARCH" == "arm-linux-gnueabihf" ]; then
  sudo chroot ${CHROOT_DIR}/ bash -c "source /root/.bashrc && cd /home/ark &&
    export CFLAGS=\"-Wno-error=int-conversion\" &&
    if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
    cd ${CHIPSET}_core_builds &&
    if [[ ${UNIT} == *"miniloong"* ]]; then cp patches/${UNIT}/sdl2/*.patch patches/.; fi &&
    chmod 777 builds-alt.sh &&
    eatmydata ./builds-alt.sh sdl2 &&
    cd SDL/${sub_folder} &&
    make install
    "
else
  sudo chroot ${CHROOT_DIR}/ bash -c "source /root/.bashrc && cd /home/ark &&
    if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
    cd ${CHIPSET}_core_builds &&
    if [[ ${UNIT} == *"miniloong"* ]]; then cp patches/${UNIT}/sdl2/*.patch patches/.; fi &&
    chmod 777 builds-alt.sh &&
    eatmydata ./builds-alt.sh sdl2 &&
    cd SDL/build &&
    make install
    "
fi

extension=$(grep -oP '(?<=extension=").*?(?=")' ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/scripts/sdl2.sh)
if [[ "$UNIT" == *"rgb10"* ]] || [[ "$UNIT" == "rk2020" ]]; then
  sudo chroot ${CHROOT_DIR}/ bash -c "cp -f /home/ark/${CHIPSET}_core_builds/sdl2-${BITNESS}/libSDL2-2.0.so.0.$extension.rotated /usr/lib/${ARCH}/libSDL2-2.0.so.0.$extension"
elif [[ "$UNIT" == *"a10mini"* ]]; then
  sudo chroot ${CHROOT_DIR}/ bash -c "cp -f /home/ark/${CHIPSET}_core_builds/sdl2-${BITNESS}/libSDL2-2.0.so.0.$extension /usr/lib/${ARCH}/libSDL2-2.0.so.0.$extension"
  sudo cp -f ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/sdl2-${BITNESS}/libSDL2-2.0.so.0.$extension.a10miniv4 /tmp/a10miniv4/libSDL2-2.0.so.0.$extension.a10miniv4.${BITNESS}
elif [[ "$CHIPSET" == "rk3326" ]]; then
  sudo chroot ${CHROOT_DIR}/ bash -c "cp -f /home/ark/${CHIPSET}_core_builds/sdl2-${BITNESS}/libSDL2-2.0.so.0.$extension /usr/lib/${ARCH}/."
fi

sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL2.so /usr/lib/${ARCH}/libSDL2-2.0.so.0"
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL2-2.0.so.0.${extension} /usr/lib/${ARCH}/libSDL2.so"
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/include/SDL2 /usr/local/include/"
sudo chroot ${CHROOT_DIR}/ bash -c "rm -f /usr/bin/sdl2-config"
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/aarch64-linux-gnu/bin/sdl2-config /usr/bin/sdl2-config"
sudo cp -R ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/SDL/include/* ${CHROOT_DIR}/usr/include/${ARCH}/SDL2/
sudo rm -rf ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/SDL
