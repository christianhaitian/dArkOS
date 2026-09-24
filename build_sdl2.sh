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
SDL2_SO="${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/sdl2-${BITNESS}/libSDL2-2.0.so.0.${extension}"
SDL2_CONFIG_SRC=""
for SDL2_CONFIG_CANDIDATE in \
  "${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/SDL/build/sdl2-config" \
  "${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/SDL/${sub_folder}/sdl2-config"
do
  if [ -x "${SDL2_CONFIG_CANDIDATE}" ]; then
    SDL2_CONFIG_SRC="${SDL2_CONFIG_CANDIDATE}"
    break
  fi
done
if [[ "$UNIT" != *"rgb10"* ]] && [ "$UNIT" != "rk2020" ] && [ "$CHIPSET" == "rk3326" ]; then
  if [ -f "${SDL2_SO}" ]; then
    sudo chroot ${CHROOT_DIR}/ bash -c "cp -f /home/ark/${CHIPSET}_core_builds/sdl2-${BITNESS}/libSDL2-2.0.so.0.$extension /usr/lib/${ARCH}/."
  else
    echo "custom SDL2 ${SDL2_SO} missing; not rewriting libSDL2.so symlinks"
  fi
fi
if [ -f "${SDL2_SO}" ] || [ -e "${CHROOT_DIR}/usr/lib/${ARCH}/libSDL2-2.0.so.0.${extension}" ]; then
  sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL2.so /usr/lib/${ARCH}/libSDL2-2.0.so.0"
  sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL2-2.0.so.0.${extension} /usr/lib/${ARCH}/libSDL2.so"
fi
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/include/SDL2 /usr/local/include/"
if [ -n "${SDL2_CONFIG_SRC}" ]; then
  sudo mkdir -p "${CHROOT_DIR}/usr/lib/aarch64-linux-gnu/bin"
  sudo cp -a "${SDL2_CONFIG_SRC}" "${CHROOT_DIR}/usr/lib/aarch64-linux-gnu/bin/sdl2-config"
  sudo chmod +x "${CHROOT_DIR}/usr/lib/aarch64-linux-gnu/bin/sdl2-config"
fi
sudo chroot ${CHROOT_DIR}/ bash -c "rm -f /usr/bin/sdl2-config"
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/aarch64-linux-gnu/bin/sdl2-config /usr/bin/sdl2-config"
sudo cp -R ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/SDL/include/* ${CHROOT_DIR}/usr/include/${ARCH}/SDL2/
sudo rm -rf ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/SDL
