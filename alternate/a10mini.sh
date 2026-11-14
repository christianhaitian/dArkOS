#!/bin/bash

# We'll finalize the regular a10mini image first
sudo mkdir -p /tmp/a10-rootfs
sudo mount ${LOOP}p2 /tmp/a10-rootfs
sudo mv -fv /tmp/a10-rootfs/opt/retroarch/bin/retroarch.${UNIT}v4 /tmp/${UNIT}v4/.
sudo mv -fv /tmp/a10-rootfs/opt/retroarch/bin/retroarch32.${UNIT}v4 /tmp/${UNIT}v4/.
sudo mv -fv /tmp/a10-rootfs/usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.$extension.${UNIT}v4 /tmp/${UNIT}v4/libSDL2-2.0.so.0.$extension.${UNIT}v4.32
sync /tmp/a10-rootfs
#sudo dd if="${FILESYSTEM}" of="${DISK}" bs=512 seek="${STORAGE_PART_START}" conv=fsync,notrunc
sync
sudo umount -l /tmp/a10-rootfs

# Now we prepare the a10mini v4 image
iName=`echo ${UNIT} | tr '[:lower:]' '[:upper:]'`
DISK_ALT="dArkOS_${iName}v4_${DEBIAN_CODE_NAME}_${BUILD_DATE}.img"
cp --reflink=auto ${DISK} ${DISK_ALT}
LOOP_ALT=$(sudo losetup --find --show --partscan "$DISK_ALT")
sudo mkdir -p /tmp/a10v4-boot
sudo mkdir -p /tmp/a10v4-rootfs
sudo mount ${LOOP_ALT}p1 /tmp/a10v4-boot
sudo mount ${LOOP_ALT}p2 /tmp/a10v4-rootfs

sudo rm -fv /tmp/a10v4-boot/${CHIPSET}-${UNIT}*
sudo mv -fv /tmp/${UNIT}v4/${CHIPSET}-${UNIT}-v4-linux.dtb /tmp/a10v4-boot/.
sudo rm -fv /tmp/a10v4-boot/rg351mp-uboot.dtb
sudo mv -fv /tmp/${UNIT}v4/${UNIT}v4-uboot.dtb /tmp/a10v4-boot/rg351mp-uboot.dtb
sudo rm -fv /tmp/a10v4-boot/boot.ini
sudo cp -fv logos/rotated/${UNIT}v4/logo.bmp /tmp/a10v4-boot/.
sudo sed -i 's/a10mini-linux/a10mini-v4-linux/g' /tmp/a10v4-boot/expandtoexfat.sh
cat <<EOF | sudo tee /tmp/a10v4-boot/boot.ini
odroidgoa-uboot-config

setenv bootargs "root=/dev/mmcblk0p2 rootwait rw fsck.repair=yes net.ifnames=0 fbcon=rotate:2 console=/dev/ttyFIQ0 quiet splash consoleblank=0 vt.global_cursor_default=0"

# Booting
setenv loadaddr "0x02000000"
setenv initrd_loadaddr "${INITRD_LOADERADDRESS}"
setenv dtb_loadaddr "0x01f00000"

load mmc 1:1 \${loadaddr} Image
load mmc 1:1 \${initrd_loadaddr} uInitrd

load mmc 1:1 \${dtb_loadaddr} ${CHIPSET}-${UNIT}-v4-linux.dtb

booti \${loadaddr} \${initrd_loadaddr} \${dtb_loadaddr}
EOF
sudo cp -fv /tmp/${UNIT}v4/libSDL2-2.0.so.0.$extension.${UNIT}v4.64 /tmp/a10v4-rootfs/usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.$extension
if [[ -f "/tmp/${UNIT}v4/libSDL2-2.0.so.0.$extension.${UNIT}v4.32" ]]; then
  sudo cp -fv /tmp/${UNIT}v4/libSDL2-2.0.so.0.$extension.${UNIT}v4.32 /tmp/a10v4-rootfs/usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.$extension
fi
sudo cp -fv /tmp/${UNIT}v4/retroarch.${UNIT}v4 /tmp/a10v4-rootfs/opt/retroarch/bin/retroarch
sudo cp -fv /tmp/${UNIT}v4/retroarch32.${UNIT}v4 /tmp/a10v4-rootfs/opt/retroarch/bin/retroarch32
sudo chmod 777 /tmp/a10v4-rootfs/opt/retroarch/bin/retroarch*

NAME="${UNIT}v4"
dNAME=`echo $NAME | tr '[:lower:]' '[:upper:]'`
echo "$dNAME" | sudo tee /tmp/a10v4-rootfs/home/ark/.config/.DEVICE

sync

sudo umount -l /tmp/a10v4-rootfs
sudo umount -l /tmp/a10v4-boot
sudo losetup -d ${LOOP_ALT}