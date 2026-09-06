#!/bin/bash

echo -e "Creating partitions...\n\n"
# Partition setup
ROOT_FILESYSTEM_FORMAT="btrfs"
if [ "$ROOT_FILESYSTEM_FORMAT" == "xfs" ] || [ "$ROOT_FILESYSTEM_FORMAT" == "btrfs" ]; then
  if [ "$ROOT_FILESYSTEM_FORMAT" != "btrfs" ]; then
    ROOT_FILESYSTEM_FORMAT_PARAMETERS="-f -L ROOTFS"
    ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime"
  else
    # Disable free-space-tree
    # In some btrfs-progs versions, this is listed as a filesystem feature (-O)
    if sudo mkfs.btrfs -O list-all 2>&1 | grep -q "free-space-tree"; then
      ROOT_FILESYSTEM_FORMAT_PARAMETERS="-O ^free-space-tree -f -L ROOTFS"
    # In some btrfs-progs versions, this is listed as a runtime features (-R)
    elif sudo mkfs.btrfs -R list-all 2>&1 | grep -q "free-space-tree"; then
      ROOT_FILESYSTEM_FORMAT_PARAMETERS="-R ^free-space-tree -f -L ROOTFS"
    else
      ROOT_FILESYSTEM_FORMAT_PARAMETERS="-f -L ROOTFS"
    fi
    # btrfs on 4.4 has no compress=<algo>:<level> syntax, so "zlib:1" made the
    # whole remount of / fail; confirmed on an RG351MP.
    ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime,compress=lzo"
  fi
elif [[ "$ROOT_FILESYSTEM_FORMAT" == *"ext"* ]]; then
  ROOT_FILESYSTEM_FORMAT_PARAMETERS="-F -L ROOTFS"
  ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime"
fi
SYSTEM_SIZE=100      # FAT32 boot partition size in MB
STORAGE_SIZE=7500    # Root filesystem size in MB
ROM_PART_SIZE=300    # FAT32 ROMS/shared partition size in MB
BUILD_SIZE=52000     # Initial file system size in MB during the build.  Then will be reduced to the DISK_SIZE or below upon completion

SYSTEM_PART_START=32768
SYSTEM_PART_END=$(( SYSTEM_PART_START + (SYSTEM_SIZE * 1024 * 1024 / 512) - 1 ))
STORAGE_PART_START=$(( SYSTEM_PART_END + 1 ))
STORAGE_PART_END=$(( STORAGE_PART_START + (STORAGE_SIZE * 1024 * 1024 / 512) - 1 ))
ROM_PART_START=$(( STORAGE_PART_END + 1 ))
ROM_PART_END=$(( ROM_PART_START + (ROM_PART_SIZE * 1024 * 1024 / 512) - 1 ))

DISK_START_PADDING=$(( (SYSTEM_PART_START + 2048 - 1) / 2048 ))
DISK_SIZE=$(( DISK_START_PADDING + SYSTEM_SIZE + STORAGE_SIZE + ROM_PART_SIZE + 1 ))
FILESYSTEM="ArkOS_File_System.img"

# Create filesystem image
dd if=/dev/zero of="${FILESYSTEM}" bs=1M count=0 seek="${BUILD_SIZE}" conv=fsync
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_FORMAT_PARAMETERS} "${FILESYSTEM}"
mkdir -p Arkbuild/
sudo mount -t ${ROOT_FILESYSTEM_FORMAT} -o ${ROOT_FILESYSTEM_MOUNT_OPTIONS},loop ${FILESYSTEM} Arkbuild/

