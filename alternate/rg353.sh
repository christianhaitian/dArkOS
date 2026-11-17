#!/bin/bash

# Now we prepare the rg353v image using the existing rg353m image with just some minor changes
DISK_ALT="dArkOS_RG353v_${DEBIAN_CODE_NAME}_${BUILD_DATE}.img"
cp --reflink=auto ${DISK} ${DISK_ALT}
LOOP_ALT=$(sudo losetup --find --show --partscan "$DISK_ALT")
sudo mkdir -p /tmp/rg353v-boot
sudo mkdir -p /tmp/rg353v-rootfs
sudo mount ${LOOP_ALT}p3 /tmp/rg353v-boot
sudo mount ${LOOP_ALT}p4 /tmp/rg353v-rootfs

sudo rm -fv /tmp/rg353v-boot/${CHIPSET}-${UNIT}*
sudo mv -fv /tmp/rg353v/${CHIPSET}-353v* /tmp/rg353v-boot/.
sudo sed -i 's/353m/353v/g' /tmp/rg353v-boot/extlinux/extlinux.conf
echo "RG353V" | sudo tee /tmp/rg353v-rootfs/home/ark/.config/.DEVICE
echo "rg353v" | sudo tee /tmp/rg353v-rootfs/etc/hostname
sudo sed -i 's/353m/353v/g' /tmp/rg353v-rootfs/etc/hosts
sudo cp scripts/.asoundbackup/.asoundrcbak.rg353v /tmp/rg353v-rootfs/home/ark/.asoundrc
sudo cp scripts/.asoundbackup/.asoundrcbak.rg353v /tmp/rg353v-rootfs/home/ark/.asoundrcbak

sync

sudo umount -l /tmp/rg353v-rootfs
sudo umount -l /tmp/rg353v-boot
sudo losetup -d ${LOOP_ALT}
sudo rm -rf /tmp/rg353v*
