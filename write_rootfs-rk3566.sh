#!/bin/bash

# Write rootfs to disk
sync Arkbuild
if [ "${ROOT_FILESYSTEM_FORMAT}" == "xfs" ]; then
  mkdir Arkbuild-final
  sudo mount -o loop ${LOOP_DEV}p4 Arkbuild-final/
  sudo rsync -aHAXv --exclude={'home/ark/Arkbuild_ccache','proc','dev','sys'} Arkbuild/ Arkbuild-final/
  sudo umount Arkbuild-final/
  sudo rm -rf Arkbuild-final/
elif [[ "${ROOT_FILESYSTEM_FORMAT}" == *"ext"* ]]; then
  e2fsck -p -f ${FILESYSTEM}
  resize2fs -M ${FILESYSTEM}
  sudo dd if="${FILESYSTEM}" of="${LOOP_DEV}p4" bs=512 conv=fsync,notrunc
elif [ "${ROOT_FILESYSTEM_FORMAT}" == "btrfs" ]; then
  # Create a fresh, size-limited Btrfs rootfs instead of shrinking a large one.
  # Arkbuild remains mounted and the original ${FILESYSTEM} is not modified.
  # The raw rootfs must fit BOTH 7.25 GiB and ${LOOP_DEV}p4.
  if [[ -z "${LOOP_DEV:-}" || -z "${FILESYSTEM:-}" || ! -b "${LOOP_DEV}p4" ]]; then
    echo "ERROR: LOOP_DEV/FILESYSTEM missing or ${LOOP_DEV:-}p4 is not a block device." >&2
    exit 1
  fi
  if [[ "$(findmnt -rn -M Arkbuild -o FSTYPE)" != "btrfs" ]]; then
    echo "ERROR: Arkbuild must be a mounted Btrfs filesystem." >&2
    exit 1
  fi
  if ! findmnt -rn -M Arkbuild -o OPTIONS | tr ',' '\n' | grep -qx rw; then
    echo "ERROR: Arkbuild is not mounted read-write." >&2
    exit 1
  fi
  if findmnt -rn -S "${LOOP_DEV}p4" >/dev/null; then
    echo "ERROR: Destination ${LOOP_DEV}p4 is mounted; refusing to overwrite." >&2
    exit 1
  fi
  # Confirm the source contains only the top-level Btrfs subvolume.
  if [[ -n "$(sudo btrfs subvolume list -a Arkbuild)" ]]; then
    echo "ERROR: Arkbuild has nested subvolumes; plain rsync would not preserve them." >&2
    exit 1
  fi

  partition_bytes=$(sudo blockdev --getsize64 "${LOOP_DEV}p4") || exit 1
  limit_bytes=$((725 * 1024 * 1024 * 1024 / 100))
  (( partition_bytes < limit_bytes )) && limit_bytes=$partition_bytes
  # Round DOWN to a whole MiB, never exceeding the size limit.
  image_mib=$((limit_bytes / 1048576))
  if (( image_mib < 1024 )); then
    echo "ERROR: Destination partition too small (${image_mib} MiB)." >&2
    exit 1
  fi
  image_bytes=$((image_mib * 1048576))

  # Keep the temporary image on the same filesystem as FILESYSTEM.
  # No truncation or resize of the mounted original rootfs is performed.
  tmpdir=$(mktemp -d "$(dirname -- "$FILESYSTEM")/.darkos-btrfs.XXXXXXXX") || exit 1
  new_image="$tmpdir/rootfs.img"
  new_mount="$tmpdir/mnt"
  mkdir -p "$new_mount" || exit 1
  btrfs_cleanup() {
    if mountpoint -q "$new_mount"; then sudo umount "$new_mount" || true; fi
    if [[ -n "${tmpdir:-}" && -d "$tmpdir" ]]; then sudo rm -rf -- "$tmpdir"; fi
  }
  trap btrfs_cleanup EXIT

  echo "Creating fresh ROOTFS Btrfs image (${image_mib} MiB, limit ${limit_bytes} bytes)."
  truncate -s "$image_bytes" "$new_image" || exit 1
  sudo mkfs.btrfs -f -L ROOTFS -d single -m dup "$new_image" || exit 1
  sudo mount -o loop,noatime,compress=zstd:1 "$new_image" "$new_mount" || exit 1

  # -x avoids the host's mounted /dev, /proc, /sys and /dev/pts.
  # Exclude the build-only cache, but preserve ownership, ACLs, xattrs and links.
  sudo rsync -aHAXx --numeric-ids \
    --exclude='/home/ark/Arkbuild_ccache/***' \
    Arkbuild/ "$new_mount/" || exit 1

  echo "New Btrfs filesystem usage:"
  sudo btrfs filesystem usage -T "$new_mount" || exit 1
  # A dry-run comparison catches omitted or changed files after the copy.
  # --checksum verifies contents rather than relying only on timestamps/sizes.
  differences=$(sudo rsync -aHAXxcniO --numeric-ids \
    --exclude='/home/ark/Arkbuild_ccache/***' \
    Arkbuild/ "$new_mount/") || exit 1
  if [[ -n "$differences" ]]; then
    echo "ERROR: Source and destination differ after rsync:" >&2
    printf '%s\n' "$differences" | head -40 >&2
    exit 1
  fi

  sudo sync
  sudo umount "$new_mount" || exit 1
  sudo btrfs check --readonly "$new_image" || exit 1
  actual_bytes=$(stat -c %s "$new_image") || exit 1
  if (( actual_bytes > limit_bytes || actual_bytes > partition_bytes )); then
    echo "ERROR: New image exceeds 7.25 GiB or destination partition." >&2
    exit 1
  fi
  sudo dd if="$new_image" of="${LOOP_DEV}p4" bs=4M conv=fsync,notrunc status=progress || exit 1
  echo "Btrfs rootfs written successfully (${actual_bytes} bytes)."
  # EXIT trap removes the temporary image; the original FILESYSTEM is retained.
fi
sync ${DISK}