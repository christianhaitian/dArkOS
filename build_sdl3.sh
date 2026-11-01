#!/bin/bash

BITNESS="64"
ARCH="aarch64-linux-gnu"
CHROOT_DIR="Arkbuild"
SDL3_MIXER_TAG="release-3.2.4"
SDL3_MIXER_EXTENSION=$(echo ${SDL3_MIXER_TAG} | sed 's/release-3.//g')
sdl3_extension=$(grep -oP '(?<=extension=").*?(?=")' ${CHROOT_DIR}/home/ark/${CHIPSET}_core_builds/scripts/sdl3.sh)

# Build and install SDL3
if [ -f "Arkbuild_package_cache/${CHIPSET}/sdl3.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/sdl3.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/sdl3.sh | grep -oP '(?<=extension=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/sdl3.tar.gz
else
	sudo chroot ${CHROOT_DIR}/ bash -c "source /root/.bashrc && cd /home/ark &&
	  if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh sdl3 &&
	  cp sdl3-${BITNESS}/libSDL3.so.${sdl3_extension} /usr/lib/${ARCH}/. &&
	  cd SDL3/build &&
		  git clone --recursive https://github.com/libsdl-org/SDL_mixer.git -b ${SDL3_MIXER_TAG} &&
		  cd SDL_mixer &&
		  cmake -S . -B build -DCMAKE_PREFIX_PATH="../" &&
		  cmake --build build -j$(nproc) &&
		  strip build/libSDL3_mixer.so.0.${SDL3_MIXER_EXTENSION} &&
		  cp build/libSDL3_mixer.so.0.${SDL3_MIXER_EXTENSION} /usr/lib/${ARCH}/.
	  "
	if [ -f "Arkbuild_package_cache/${CHIPSET}/sdl3.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/sdl3.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/sdl3.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/sdl3.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/sdl3.tar.gz Arkbuild/usr/lib/${ARCH}/libSDL3.so.${sdl3_extension} Arkbuild/usr/lib/${ARCH}/libSDL3_mixer.so.0.${SDL3_MIXER_EXTENSION}
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/sdl3.sh | grep -oP '(?<=extension=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/sdl3.commit
fi
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL3.so.${sdl3_extension} /usr/lib/${ARCH}/libSDL3.so.0"
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL3.so.0 /usr/lib/${ARCH}/libSDL3.so"
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL3_mixer.so.0.${SDL3_MIXER_EXTENSION} /usr/lib/${ARCH}/libSDL3_mixer.so.0"
sudo chroot ${CHROOT_DIR}/ bash -c "ln -sfv /usr/lib/${ARCH}/libSDL3_mixer.so.0 /usr/lib/${ARCH}/libSDL3_mixer.so"
