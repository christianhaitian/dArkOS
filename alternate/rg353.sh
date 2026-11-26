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

# Now we prepare the rk2023 image using the existing rg353m image with just some minor changes
SAME_DEVICE="rk2023"
DISK_ALT="dArkOS_${SAME_DEVICE^^}_${DEBIAN_CODE_NAME}_${BUILD_DATE}.img"
cp --reflink=auto ${DISK} ${DISK_ALT}
LOOP_ALT=$(sudo losetup --find --show --partscan "$DISK_ALT")
sudo mkdir -p /tmp/${SAME_DEVICE}-boot
sudo mkdir -p /tmp/${SAME_DEVICE}-rootfs
sudo mount ${LOOP_ALT}p3 /tmp/${SAME_DEVICE}-boot
sudo mount ${LOOP_ALT}p4 /tmp/${SAME_DEVICE}-rootfs

sudo rm -fv /tmp/${SAME_DEVICE}-boot/${CHIPSET}-${UNIT}*
sudo mv -fv /tmp/${SAME_DEVICE}/${CHIPSET}-${SAME_DEVICE}* /tmp/${SAME_DEVICE}-boot/.
sudo sed -i 's/353m/${SAME_DEVICE}/g' /tmp/${SAME_DEVICE}-boot/extlinux/extlinux.conf
echo "${SAME_DEVICE^^}" | sudo tee /tmp/${SAME_DEVICE}-rootfs/home/ark/.config/.DEVICE
echo "${SAME_DEVICE}" | sudo tee /tmp/${SAME_DEVICE}-rootfs/etc/hostname
sudo sed -i "s/rg353m/${SAME_DEVICE}/g" /tmp/${SAME_DEVICE}-rootfs/etc/hosts
# Patch ogage to use R3 as the system hotkey instead of guide button
printf '\x1f\xf9\x04\x71' | \
dd of=/tmp/${SAME_DEVICE}-rootfs/usr/local/bin/ogage bs=1 seek=$((0x81b4)) conv=notrunc status=none
sed -i -E '/name="system_hk"/s/id="[0-9]+"/id="12"/' /tmp/${SAME_DEVICE}-rootfs/etc/emulationstation/es_input.cfg
cp lzdoom/configs/${SAME_DEVICE}/lzdoom.ini /tmp/${SAME_DEVICE}-rootfs/home/ark/.config/lzdoom/.
cp gzdoom/configs/${SAME_DEVICE}/lzdoom.ini /tmp/${SAME_DEVICE}-rootfs/home/ark/.config/lzdoom/.
sync

sudo umount -l /tmp/${SAME_DEVICE}-rootfs
sudo umount -l /tmp/${SAME_DEVICE}-boot
sudo losetup -d ${LOOP_ALT}
sudo rm -rf /tmp/${SAME_DEVICE}*