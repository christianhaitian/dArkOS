SHELL := /bin/bash

DEBIAN_CODE_NAME ?= trixie
ENABLE_CACHE ?= y
BUILD_KODI ?= n
BUILD_ARMHF ?= y
BUILD_BLUEALSA ?= y

# Ensure system binaries like parted are in the path, and silence strict GCC warnings
PATH := $(PATH):/usr/sbin:/sbin
KCFLAGS := -w

export DEBIAN_CODE_NAME
export ENABLE_CACHE
export BUILD_KODI
export BUILD_ARMHF
export BUILD_BLUEALSA
export PATH
export KCFLAGS

ifeq ($(DEBIAN_CODE_NAME),)
  $(error DEBIAN_CODE_NAME is not set. Please run with DEBIAN_CODE_NAME=suite (e.g., trixie))
endif

all:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	$(info adding bluetooth support? ${BUILD_BLUEALSA})
	@sleep 5
	./build_a10mini.sh
	./build_rg351mp.sh
	./build_rgb10.sh
	./build_miniloong.sh
	./build_rgb20pro.sh
	./build_rgb30.sh
	./build_rg353m.sh
	./build_rg503.sh

a10mini:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	@sleep 5
	./build_a10mini.sh

miniloong:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	$(info adding bluetooth support? ${BUILD_BLUEALSA})
	@sleep 5
	./build_miniloong.sh

rgb10:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	@sleep 5
	./build_rgb10.sh

rgb20pro:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	$(info adding bluetooth support? ${BUILD_BLUEALSA})
	@sleep 5
	./build_rgb20pro.sh

rgb30:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	$(info adding bluetooth support? ${BUILD_BLUEALSA})
	@sleep 5
	./build_rgb30.sh

rg351mp:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	@sleep 5
	./build_rg351mp.sh

rg353:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	$(info adding bluetooth support? ${BUILD_BLUEALSA})
	@sleep 5
	./build_rg353m.sh

rg503:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	$(info adding bluetooth support? ${BUILD_BLUEALSA})
	@sleep 5
	./build_rg503.sh

devenv:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	@sleep 5
	./build_devenv.sh

devenv32:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	@sleep 5
	./build_devenv.sh 32

clean:
	[ -d "mnt/boot" ] && sudo umount mnt/boot && sudo rm -rf mnt/boot || true
	[ -d "mnt/roms" ] && sudo umount mnt/roms && sudo rm -rf mnt/roms || true
	[ -d "main" ] && sudo rm -rf main || true
	[ -d "initrd" ] && sudo rm -rf initrd || true
	[ -f "wget-log" ] && sudo rm -f wget-log* || true
	source utils.sh && remove_arkbuild && remove_arkbuild32
	sudo rm -rf Arkbuild Arkbuild32 Arkbuild-final arkos_* main mnt odroidgoA-4.4.y ArkOS_* rg351 wget-*
	for devlo in $$(losetup -a | grep -F "($$(pwd)/" | cut -d ':' -f 1); do sudo losetup -d "$$devlo" || echo "Skipping $$devlo (still in use)"; done
	@echo "Done!"

clean_devenv:
	./clean_mounts_devenv.sh
	sudo rm -rf Ark_devenv/
	@echo "Done!"

clean_devenv32:
	./clean_mounts_devenv.sh 32
	sudo rm -rf Ark_devenv32/
	@echo "Done!"

clean_complete: clean
	[ -d "$${PWD}/Arkbuild_ccache" ] && sudo umount $${PWD}/Arkbuild_ccache || true
	[ -d "$${PWD}/Arkbuild_ccache" ] && sudo rm -rf Arkbuild_ccache || true
	[ -d "$${PWD}/Arkbuild_package_cache" ] && sudo rm -rf Arkbuild_package_cache || true
	sudo rm -f build.log*
