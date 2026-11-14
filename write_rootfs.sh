#!/bin/bash

# Write rootfs to disk
sync Arkbuild
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
  if [[ -z "${DISK:-}" || -z "${FILESYSTEM:-}" || ! "${STORAGE_PART_START:-}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: DISK, FILESYSTEM, or STORAGE_PART_START is missing/invalid." >&2
    exit 1
  fi
  if [[ ! -f "$DISK" && ! -b "$DISK" ]]; then
    echo "ERROR: Destination DISK does not exist: $DISK" >&2
    exit 1
  fi
  if [[ "$(findmnt -rn -M Arkbuild -o FSTYPE)" != btrfs ]]; then
    echo "ERROR: Arkbuild must be a mounted Btrfs filesystem." >&2
    exit 1
  fi
  if [[ -n "$(sudo btrfs subvolume list -a Arkbuild)" ]]; then
    echo "ERROR: Arkbuild contains nested Btrfs subvolumes; rsync is insufficient." >&2
    exit 1
  fi
  for cmd in sfdisk jq rsync mkfs.btrfs; do
    command -v "$cmd" >/dev/null || { echo "ERROR: Missing $cmd" >&2; exit 1; }
  done
  
  # Resolve the partition by its exact starting sector, not an assumed p4 path.
  # sfdisk's start and size are in logical sectors; the dd seek below uses 512 bytes.
  partition_json=$(sudo sfdisk --json "$DISK") || exit 1
  sector_bytes=$(jq -er '.partitiontable.sectorsize' <<<"$partition_json") || exit 1
  if [[ "$sector_bytes" != 512 ]]; then
    echo "ERROR: Destination uses ${sector_bytes}-byte sectors; original dd assumes 512." >&2
    exit 1
  fi
  matches=$(jq --argjson start "$STORAGE_PART_START" \
    '[.partitiontable.partitions[] | select(.start == $start)] | length' <<<"$partition_json") || exit 1
  if [[ "$matches" != 1 ]]; then
    echo "ERROR: Expected exactly one partition starting at sector $STORAGE_PART_START; found $matches." >&2
    exit 1
  fi
  partition_sectors=$(jq -er --argjson start "$STORAGE_PART_START" \
    '.partitiontable.partitions[] | select(.start == $start) | .size' <<<"$partition_json") || exit 1
  partition_bytes=$((partition_sectors * 512))
  limit_bytes=$((745 * 1024 * 1024 * 1024 / 10)) # 7.45 GiB (binary)
  (( partition_bytes < limit_bytes )) && limit_bytes=$partition_bytes
  image_mib=$((limit_bytes / 1048576))
  if (( image_mib < 1024 )); then
    echo "ERROR: Rootfs partition too small (${image_mib} MiB)." >&2
    exit 1
  fi
  image_bytes=$((image_mib * 1048576))
  
  # Guard against writing to the source filesystem image or an actively mounted destination.
  source_backing=$(findmnt -rn -M Arkbuild -o SOURCE) || exit 1
  if [[ "$DISK" == "$FILESYSTEM" || ( -b "$DISK" && "$DISK" == "$source_backing" ) ]]; then
    echo "ERROR: DISK is the mounted source Btrfs device." >&2
    exit 1
  fi
  if [[ -b "$DISK" ]] && findmnt -rn -S "$DISK" >/dev/null; then
    echo "ERROR: Destination disk is mounted." >&2
    exit 1
  fi
  
  # The new image is temporary; do not modify the source FILESYSTEM.
  tmpdir=$(mktemp -d "$(dirname -- "$FILESYSTEM")/.darkos-rk3326-btrfs.XXXXXXXX") || exit 1
  new_image="$tmpdir/rootfs.img"
  new_mount="$tmpdir/mnt"
  mkdir -p "$new_mount" || exit 1
  rk3326_btrfs_cleanup() {
    if mountpoint -q "$new_mount"; then sudo umount "$new_mount" || return 1; fi
    sudo rm -rf -- "$tmpdir"
  }
  trap rk3326_btrfs_cleanup EXIT
  
  echo "Creating fresh RK3326 ROOTFS (${image_mib} MiB; partition ${partition_bytes} bytes)."
  truncate -s "$image_bytes" "$new_image" || exit 1
  sudo mkfs.btrfs ${ROOT_FILESYSTEM_FORMAT_PARAMETERS} "$new_image" || exit 1
  sudo mount -t btrfs -o ${ROOT_FILESYSTEM_MOUNT_OPTIONS},loop "$new_image" "$new_mount" || exit 1
  
  # Do not traverse Arkbuild/dev, proc, sys, or other nested mounts.
  sudo rsync -aHAXxO --numeric-ids \
    --exclude='/home/ark/Arkbuild_ccache/***' \
    Arkbuild/ "$new_mount/" || exit 1
  
  sudo btrfs filesystem usage -T "$new_mount" || exit 1
  # -O (capital O) ignores volatile mountpoint directory timestamps.
  differences=$(sudo rsync -aHAXxcniO --numeric-ids \
    --exclude='/home/ark/Arkbuild_ccache/***' \
    Arkbuild/ "$new_mount/") || exit 1
  if [[ -n "$differences" ]]; then
    echo "ERROR: Source and destination differ after rsync:" >&2
    printf '%s\n' "$differences" | head -40 >&2
    exit 1
  fi
  sync
  sudo umount "$new_mount" || exit 1
  sudo btrfs check --readonly "$new_image" || exit 1
  actual_bytes=$(stat -c %s "$new_image") || exit 1
  if (( actual_bytes > limit_bytes || actual_bytes > partition_bytes )); then
    echo "ERROR: Image exceeds rootfs partition or 7.45 GiB limit." >&2
    exit 1
  fi
  # Preserve the RK3326 sector-offset write (no partition loop device required).
  sudo dd if="$new_image" of="$DISK" bs=512 seek="$STORAGE_PART_START" \
    count="$((actual_bytes / 512))" iflag=fullblock \
    conv=fsync,notrunc status=progress || exit 1
  sync
  rk3326_btrfs_cleanup || exit 1
  trap - EXIT
fi
sync ${DISK}