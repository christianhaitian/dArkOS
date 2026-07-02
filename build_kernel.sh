#!/bin/bash

# Build and install custom kernel from christianhaitian/linux
if [ "$UNIT" == "rgb10" ] || [ "$UNIT" == "rk2020" ]; then
  KERNEL_SRC="odroidgoA-4.4.y"
  DEF_CONFIG="odroidgoa_tweaked_defconfig"
  SCREEN_ROTATION="3"
  if [ "$UNIT" == "rgb10" ]; then
    KERNEL_DTB="${CHIPSET}-odroidgo2-linux-v11.dtb"
    KERNEL_DTB_ALT="${CHIPSET}-odroidgo2-linux-v11-alt.dtb"
    KERNEL_DTB_RGB10S="${CHIPSET}-odroidgo2-linux-v11-rgb10s.dtb"
  else
    KERNEL_DTB="${CHIPSET}-odroidgo2-linux.dtb"
  fi
else
  KERNEL_SRC="rg351"
  DEF_CONFIG="rg351p_tweaked_defconfig"
  SCREEN_ROTATION="0"
  KERNEL_DTB="${CHIPSET}-${UNIT}-linux.dtb"
fi
if [ ! -d "$KERNEL_SRC" ]; then
  git clone --recursive --depth=1 https://github.com/christianhaitian/linux.git -b $KERNEL_SRC $KERNEL_SRC
fi
# The old RK3326 4.4 BSP kernel does not compile with GCC 13/14. Prefer the
# aarch64 GCC-12 cross compiler if it is available; fall back gracefully.
KERNEL_CC=""
for cc in aarch64-linux-gnu-gcc-12 aarch64-linux-gnu-gcc-13 aarch64-linux-gnu-gcc; do
  if command -v "$cc" >/dev/null 2>&1; then
    KERNEL_CC="$cc"
    break
  fi
done
echo "Building kernel with CROSS_COMPILE=aarch64-linux-gnu- CC=${KERNEL_CC:-<default>}"

cd $KERNEL_SRC
make ARCH=arm64 ${DEF_CONFIG}
CFLAGS=-Wno-deprecated-declarations make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ${KERNEL_CC:+CC="$KERNEL_CC"} modules_prepare
CFLAGS=-Wno-deprecated-declarations make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ${KERNEL_CC:+CC="$KERNEL_CC"} Image dtbs modules
verify_action

if [ "$UNIT" == "g350" ]; then
  # The G350's single USB-C hangs off one PHY whose role is fixed per boot in
  # the DTB: stock = host (USB drives / MIDI / wifi dongle), no gadget. Build
  # both variants; the gadget one (SSH deploy link) ships as the default.
  # Switch on device with usbmode.sh, or swap the files on the BOOT partition.
  G350_DTS="arch/arm64/boot/dts/rockchip/rk3326-g350-linux.dts"
  DTB_OUT="${G350_DTS%.dts}.dtb"
  MAKE_DTBS="make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ${KERNEL_CC:+CC=$KERNEL_CC} dtbs"
  git checkout -- ${G350_DTS}   # pristine, in case a previous cached run patched it
  ${MAKE_DTBS} && cp ${DTB_OUT} ${DTB_OUT}.host
  verify_action
  sed -i -e '/u2phy_host: host-port/,/}/ s/status = "okay"/status = "disabled"/' \
         -e '/u2phy_otg: otg-port/,/}/ s/status = "disabled"/status = "okay"/' ${G350_DTS}
  ${MAKE_DTBS} && cp ${DTB_OUT} ${DTB_OUT}.gadget
  verify_action
  git checkout -- ${G350_DTS}
fi
cd ..

# Install kernel modules
sudo make -C $KERNEL_SRC ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=../Arkbuild modules_install

# Format boot partition
BOOT_PART_OFFSET=$((SYSTEM_PART_START * 512))
BOOT_PART_SIZE=$(( (SYSTEM_PART_END - SYSTEM_PART_START + 1) * 512 ))
LOOP_BOOT=$(sudo losetup --find --show --offset ${BOOT_PART_OFFSET} --sizelimit ${BOOT_PART_SIZE} ${DISK})
sudo mkfs.vfat -F 32 -n BOOT ${LOOP_BOOT}
mountpoint="mnt/boot"
mkdir -p ${mountpoint}
sudo mount ${LOOP_BOOT} ${mountpoint}

# Copy kernel, device tree, and modules into target rootfs
KERNEL_VERSION=$(basename $(ls Arkbuild/lib/modules))
sudo cp $KERNEL_SRC/.config Arkbuild/boot/config-${KERNEL_VERSION}
sudo cp $KERNEL_SRC/arch/arm64/boot/Image ${mountpoint}/
sudo cp $KERNEL_SRC/arch/arm64/boot/dts/rockchip/${KERNEL_DTB} ${mountpoint}/
if [ "$UNIT" == "g350" ]; then
  # Both USB-C role variants on /boot; gadget (deploy link) is the active one
  sudo cp $KERNEL_SRC/arch/arm64/boot/dts/rockchip/${KERNEL_DTB}.host ${mountpoint}/
  sudo cp $KERNEL_SRC/arch/arm64/boot/dts/rockchip/${KERNEL_DTB}.gadget ${mountpoint}/
  sudo cp $KERNEL_SRC/arch/arm64/boot/dts/rockchip/${KERNEL_DTB}.gadget ${mountpoint}/${KERNEL_DTB}
fi
if [ "$UNIT" == "rg351mp" ] || [ "$UNIT" == "g350" ] || [ "$UNIT" == "a10mini" ]; then
  sudo cp /tmp/${UNIT}-uboot.dtb ${mountpoint}/rg351mp-uboot.dtb
  sudo rm /tmp/${UNIT}-uboot.dtb
elif [ "$UNIT" == "rgb10" ]; then
  sudo cp $KERNEL_SRC/arch/arm64/boot/dts/rockchip/${KERNEL_DTB_ALT} ${mountpoint}/rk3326-odroidgo2-linux-v11.dtb.oga11
  sudo cp $KERNEL_SRC/arch/arm64/boot/dts/rockchip/${KERNEL_DTB_ALT_RGB10S} ${mountpoint}/rk3326-odroidgo2-linux-v11.dtb.rgb10s
fi

# Create uInitrd from generated initramfs
sudo cp /usr/bin/qemu-aarch64-static Arkbuild/usr/bin/
KERNEL_VERSION=$(basename $(find Arkbuild/lib/modules -maxdepth 1 -mindepth 1 -type d))
# Create symlink so depmod/initramfs can find modules for uname -r (host kernel)
sudo touch Arkbuild/lib/modules/${KERNEL_VERSION}/modules.builtin.modinfo
call_chroot "uname() { echo ${KERNEL_VERSION}; }; export -f uname; depmod ${KERNEL_VERSION}; update-initramfs -c -k ${KERNEL_VERSION}"
sudo rm Arkbuild/usr/bin/qemu-aarch64-static
sudo cp Arkbuild/boot/initrd.img-* ${mountpoint}/initrd.img
if ! command -v mkimage &> /dev/null; then
  sudo apt -y update
  sudo apt -y install u-boot-tools
fi
sudo mkimage -A arm64 -O linux -T ramdisk -C none -n uInitrd -d ${mountpoint}/initrd.img ${mountpoint}/uInitrd
sudo rm -f ${mountpoint}/initrd.img
