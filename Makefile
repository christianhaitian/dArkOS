SHELL := /bin/bash

DEBIAN_CODE_NAME ?= trixie
ENABLE_CACHE ?= y
BUILD_ARMHF ?= n

# Ensure system binaries like parted are in the path, and silence strict GCC warnings
PATH := $(PATH):/usr/sbin:/sbin
KCFLAGS := -w

export DEBIAN_CODE_NAME
export ENABLE_CACHE
export BUILD_ARMHF
export PATH
export KCFLAGS

ifeq ($(DEBIAN_CODE_NAME),)
  $(error DEBIAN_CODE_NAME is not set. Please run with DEBIAN_CODE_NAME=suite (e.g., trixie))
endif

all:
	@echo "Please specify a valid build target: make g350, make rg351mp, make rgb10 or make a10mini"

a10mini:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	@sleep 5
	./build_a10mini.sh

g350:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	@sleep 5
	./build_g350.sh

rgb10:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	@sleep 5
	./build_rgb10.sh

rg351mp:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	$(info adding armhf 32bit userspace? ${BUILD_ARMHF})
	@sleep 5
	./build_rg351mp.sh

clean:
	[ -d "mnt/boot" ] && sudo umount mnt/boot && sudo rm -rf mnt/boot || true
	[ -d "mnt/roms" ] && sudo umount mnt/roms && sudo rm -rf mnt/roms || true
	[ -d "main" ] && sudo rm -rf main || true
	[ -d "initrd" ] && sudo rm -rf initrd || true
	[ -f "wget-log" ] && sudo rm -f wget-log* || true
	source utils.sh && remove_arkbuild && remove_arkbuild32
	sudo rm -rf Arkbuild Arkbuild32 Arkbuild-final arkos_* main mnt odroidgoA-4.4.y ArkOS_* rg351 wget-*
	while losetup -a | grep -m 1 ArkOS; do sudo losetup -d "$$(losetup -a | grep ArkOS | cut -d ':' -f 1)"; done
	@echo "Done!"

clean_complete: clean
	[ -d "$${PWD}/Arkbuild_ccache" ] && sudo umount $${PWD}/Arkbuild_ccache || true
	[ -d "$${PWD}/Arkbuild_ccache" ] && sudo rm -rf Arkbuild_ccache || true
	[ -d "$${PWD}/Arkbuild_package_cache" ] && sudo rm -rf Arkbuild_package_cache || true
	sudo rm -f build.log*
