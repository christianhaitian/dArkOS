#!/bin/bash

# Write rootfs to disk
sync Arkbuild

# Cloud / custom host kernels often lack btrfs. If Arkbuild was built as a
# directory on ext4, pack it into an ext4 image (the RG351MP 4.4 kernel has
# ext4, and expandtoexfat.sh already knows how to grow it).
pack_directory_rootfs_ext4() {
  local used_mb size_mb img packdir
  echo "Arkbuild is not a btrfs mount; packing via ext4."
  used_mb=$(sudo du -xm --exclude=proc --exclude=dev --exclude=sys --exclude='home/ark/Arkbuild_ccache' -s Arkbuild | awk '{print $1}')
  size_mb=$(( used_mb + used_mb / 5 + 512 ))
  if [ "$size_mb" -lt "${STORAGE_SIZE:-7500}" ]; then
    size_mb=${STORAGE_SIZE}
  fi
  img="${FILESYSTEM}.ext4pack"
  packdir="Arkbuild-pack"
  rm -f "$img"
  dd if=/dev/zero of="$img" bs=1M count=0 seek="${size_mb}" conv=fsync
  sudo mkfs.ext4 -F -L ROOTFS "$img"
  mkdir -p "$packdir"
  sudo mount -o loop "$img" "$packdir"
  sudo mkdir -p "$packdir"/{proc,dev,sys}
  if [ -f Arkbuild/etc/fstab ]; then
    sudo sed -i 's|^LABEL=ROOTFS / btrfs .*|LABEL=ROOTFS / ext4 defaults,noatime 0 1|' Arkbuild/etc/fstab
  fi
  if [ -f mnt/boot/fstab.exfat ]; then
    sudo sed -i 's|^LABEL=ROOTFS / btrfs .*|LABEL=ROOTFS / ext4 defaults,noatime 0 0|' mnt/boot/fstab.exfat
  fi
  sudo rsync -aHAX --numeric-ids --info=progress2 \
    --exclude={'proc','dev','sys','home/ark/Arkbuild_ccache'} \
    Arkbuild/ "$packdir"/
  sudo umount "$packdir"
  sudo rm -rf "$packdir"
  sudo e2fsck -p -f "$img"
  sudo resize2fs -M "$img"
  sudo e2fsck -p -f "$img"
  rm -f "${FILESYSTEM}"
  mv "$img" "${FILESYSTEM}"
  ROOT_FILESYSTEM_FORMAT="ext4"
  ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime"
}

grow_disk_for_rootfs() {
  local rootfs_bytes part_bytes need_mb new_disk
  rootfs_bytes=$(stat -c%s "${FILESYSTEM}")
  part_bytes=$(( (STORAGE_PART_END - STORAGE_PART_START + 1) * 512 ))
  if [ "$rootfs_bytes" -le "$part_bytes" ]; then
    return 0
  fi
  need_mb=$(( (rootfs_bytes / 1024 / 1024) + 256 ))
  echo "Growing image rootfs partition from $((part_bytes/1024/1024))M to ${need_mb}M"
  SYSTEM_SIZE=100
  STORAGE_SIZE=${need_mb}
  ROM_PART_SIZE=300
  SYSTEM_PART_START=32768
  SYSTEM_PART_END=$(( SYSTEM_PART_START + (SYSTEM_SIZE * 1024 * 1024 / 512) - 1 ))
  STORAGE_PART_START=$(( SYSTEM_PART_END + 1 ))
  STORAGE_PART_END=$(( STORAGE_PART_START + (STORAGE_SIZE * 1024 * 1024 / 512) - 1 ))
  ROM_PART_START=$(( STORAGE_PART_END + 1 ))
  ROM_PART_END=$(( ROM_PART_START + (ROM_PART_SIZE * 1024 * 1024 / 512) - 1 ))
  DISK_START_PADDING=$(( (SYSTEM_PART_START + 2048 - 1) / 2048 ))
  DISK_SIZE=$(( DISK_START_PADDING + SYSTEM_SIZE + STORAGE_SIZE + ROM_PART_SIZE + 1 ))
  new_disk="${DISK}.grown"
  dd if=/dev/zero of="${new_disk}" bs=1M count=0 seek="${DISK_SIZE}" conv=fsync
  dd if="${DISK}" of="${new_disk}" bs=1M count=16 conv=notrunc
  parted -s "${new_disk}" mklabel msdos
  parted -s "${new_disk}" -a min unit s mkpart primary fat32 ${SYSTEM_PART_START} ${SYSTEM_PART_END}
  parted -s "${new_disk}" set 1 boot on
  parted -s "${new_disk}" -a min unit s mkpart primary ext4 ${STORAGE_PART_START} ${STORAGE_PART_END}
  parted -s "${new_disk}" -a min unit s mkpart primary fat32 ${ROM_PART_START} ${ROM_PART_END}
  local boot_loop rom_loop
  BOOT_PART_OFFSET=$((SYSTEM_PART_START * 512))
  BOOT_PART_SIZE=$(( (SYSTEM_PART_END - SYSTEM_PART_START + 1) * 512 ))
  boot_loop=$(sudo losetup --find --show --offset ${BOOT_PART_OFFSET} --sizelimit ${BOOT_PART_SIZE} "${new_disk}")
  sudo mkfs.vfat -F 32 -n BOOT ${boot_loop}
  if ! command -v mcopy >/dev/null 2>&1; then
    sudo apt-get -y install mtools
  fi
  export MTOOLS_SKIP_CHECK=1
  if [ -d mnt/boot ]; then
    for bootfile in mnt/boot/*; do
      [ -e "$bootfile" ] || continue
      sudo mcopy -o -i ${boot_loop} -s "$bootfile" :: || true
    done
  fi
  sudo losetup -d ${boot_loop}
  ROM_PART_OFFSET=$((ROM_PART_START * 512))
  ROM_PART_SIZE_BYTES=$(( (ROM_PART_END - ROM_PART_START + 1) * 512 ))
  rom_loop=$(sudo losetup --find --show --offset ${ROM_PART_OFFSET} --sizelimit ${ROM_PART_SIZE_BYTES} "${new_disk}")
  sudo mkfs.vfat -F 32 -n EASYROMS ${rom_loop}
  sudo losetup -d ${rom_loop}
  mv -f "${new_disk}" "${DISK}"
}

if [ "${ROOT_FILESYSTEM_FORMAT}" == "btrfs" ]; then
  arkbuild_fs=$(findmnt -n -o FSTYPE -T Arkbuild 2>/dev/null || echo "")
  if [ "$arkbuild_fs" != "btrfs" ]; then
    pack_directory_rootfs_ext4
    grow_disk_for_rootfs
  fi
fi

if [ "${ROOT_FILESYSTEM_FORMAT}" == "xfs" ]; then
  mkdir Arkbuild-final
  sudo mount -o loop ${LOOP_DEV}p4 Arkbuild-final/
  sudo rsync -av --exclude={'home/ark/Arkbuild_ccache','proc','dev','sys'} Arkbuild/ Arkbuild-final/
  sudo umount Arkbuild-final/
  sudo rm -rf Arkbuild-final/
elif [[ "${ROOT_FILESYSTEM_FORMAT}" == *"ext"* ]]; then
  e2fsck -p -f ${FILESYSTEM}
  resize2fs -M ${FILESYSTEM}
  sudo dd if="${FILESYSTEM}" of="${DISK}" bs=512 seek="${STORAGE_PART_START}" conv=fsync,notrunc
elif [ "${ROOT_FILESYSTEM_FORMAT}" == "btrfs" ]; then
  # The point of this balance is to empty the mostly-unused chunks of a 52G
  # build filesystem so it can be shrunk to ~7G, and usage-filtered balances do
  # exactly that while rewriting a fraction of the data a --full-balance does
  # (a full balance rewrites every chunk, including the ones already packed).
  # --full-balance is still the fallback in the retry path below, which is why the
  # filters stop at 75: past that a filtered balance is a full balance with extra
  # steps, and if these do not free enough the retry path runs the real one anyway.
  for USAGE in 0 20 50 75; do
    sudo btrfs balance start -dusage=${USAGE} -musage=${USAGE} Arkbuild
  done
  sudo sync Arkbuild
  sizes=(8000 7700 7300 7250 7100)
  i=0
  count=0
  while [[ $i -lt ${#sizes[@]} ]]; do
    size=${sizes[$i]}
    sudo btrfs filesystem resize "${size}M" Arkbuild/
    if [ $? -eq 0 ]; then
      tsize=$((size + 350))
      ((i++)) || true
    else
      if [[ -z $tsize ]] && [[ $count -le 4 ]]; then
        sudo btrfs balance start --full-balance Arkbuild
        sudo sync Arkbuild
        ((count++)) || true
        i=0
      else
        break
      fi
    fi
  done
  #verify_action
  sync Arkbuild
  if [[ ! -z $tsize ]]; then
    sudo truncate -s ${tsize}MB ${FILESYSTEM}
  else
    printf "\n\nFailed to resize Arkbuild.  Exiting...\n\n"
    exit 1
  fi
  sync Arkbuild
  sudo dd if="${FILESYSTEM}" of="${DISK}" bs=512 seek="${STORAGE_PART_START}" conv=fsync,notrunc
fi
sync ${DISK}