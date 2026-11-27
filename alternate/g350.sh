#!/bin/bash

SAME_DEVICE="g350"
# Now we prepare the G350 image
iName=${SAME_DEVICE}
DISK_ALT="dArkOS_${SAME_DEVICE^^}_${DEBIAN_CODE_NAME}_${BUILD_DATE}.img"
cp --reflink=auto ${DISK} ${DISK_ALT}
LOOP_ALT=$(sudo losetup --find --show --partscan "$DISK_ALT")
sudo mkdir -p /tmp/${SAME_DEVICE}-boot
sudo mkdir -p /tmp/${SAME_DEVICE}-rootfs
sudo mount ${LOOP_ALT}p1 /tmp/${SAME_DEVICE}-boot
sudo mount ${LOOP_ALT}p2 /tmp/${SAME_DEVICE}-rootfs

sudo rm -fv /tmp/${SAME_DEVICE}-boot/${CHIPSET}-${UNIT}*
sudo mv -fv /tmp/${SAME_DEVICE}/${CHIPSET}-${SAME_DEVICE}-linux.dtb /tmp/${SAME_DEVICE}-boot/.
sudo sed -i "s/rg351mp/${SAME_DEVICE}/g" /tmp/${SAME_DEVICE}-boot/boot.ini
# Next 3 lines is to accomodate an alternate solution for displaying a logo. grrrr
sudo cp scripts/${SAME_DEVICE}/*.sh /tmp/${SAME_DEVICE}-rootfs/usr/local/bin/
sudo cp scripts/${SAME_DEVICE}/logo.service /tmp/${SAME_DEVICE}-rootfs/etc/systemd/system/logo.service
sudo systemctl --root=/tmp/${SAME_DEVICE}-rootfs enable logo.service
echo "${SAME_DEVICE}" | sudo tee /tmp/${SAME_DEVICE}-rootfs/etc/hostname
sudo sed -i "s/rg351mp/${SAME_DEVICE}/g" /tmp/${SAME_DEVICE}-rootfs/etc/hosts
echo "${SAME_DEVICE^^}" | sudo tee /tmp/${SAME_DEVICE}-rootfs/home/ark/.config/.DEVICE
# Patch ogage to use Guide button as the system hotkey instead of R3 button
printf '\x1f\x11\x0b\x71' | \
dd of=/tmp/${SAME_DEVICE}-rootfs/usr/local/bin/ogage bs=1 seek=$((0x800c)) conv=notrunc
printf '\x1f\x11\x0b\x71' | \
dd of=/tmp/${SAME_DEVICE}-rootfs/usr/local/bin/ogage bs=1 seek=$((0x8b34)) conv=notrunc
sed -i -E '/name="system_hk"/s/id="[0-9]+"/id="16"/' /tmp/${SAME_DEVICE}-rootfs/etc/emulationstation/es_input.cfg

sync

sudo umount -l /tmp/${SAME_DEVICE}-rootfs
sudo umount -l /tmp/${SAME_DEVICE}-boot
sudo losetup -d ${LOOP_ALT}
sudo rm -rf /tmp/${SAME_DEVICE}*
