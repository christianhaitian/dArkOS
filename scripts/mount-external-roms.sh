#!/bin/bash
# mount-external-roms.sh — On dual-SD devices, ensure external card's EASYROMS is at /roms
#
# Problem: When both SD cards have a partition labelled EASYROMS, fstab's LABEL=EASYROMS
# resolves non-deterministically via udev. ~40% of boots mount the system card's EASYROMS
# instead of the external games card.
#
# This script runs after local-fs.target (after fstab mounts) and before emulationstation.
# If /roms is mounted from the system card but an external card with EASYROMS also exists,
# it swaps to the external card.

MOUNT_POINT="/roms"

# Find what's currently mounted at /roms
CURRENT_DEV=$(findmnt -n -o SOURCE "$MOUNT_POINT" 2>/dev/null)
if [ -z "$CURRENT_DEV" ]; then
    # /roms not mounted at all — nothing to do (no EASYROMS partition found by fstab)
    exit 0
fi

# If already mounted from a non-mmcblk0 device, it's already correct
if ! echo "$CURRENT_DEV" | grep -q "^/dev/mmcblk0"; then
    exit 0
fi

# System card is mounted at /roms. Check if there's another EASYROMS partition.
# Scan all mmcblk devices besides mmcblk0 for an EASYROMS label.
EXTERNAL_DEV=""
for dev in /dev/mmcblk[1-9]*; do
    [ -b "$dev" ] || continue
    LABEL=$(blkid -o value -s LABEL "$dev" 2>/dev/null)
    if [ "$LABEL" = "EASYROMS" ]; then
        EXTERNAL_DEV="$dev"
        break
    fi
done

# No external EASYROMS found — single card setup, leave as is
if [ -z "$EXTERNAL_DEV" ]; then
    exit 0
fi

# Swap: unmount system card's EASYROMS, mount external card's

# Unmount bind mount at /opt/system/Tools first (depends on /roms)
if mountpoint -q /opt/system/Tools 2>/dev/null; then
    umount /opt/system/Tools 2>/dev/null
fi

# Unmount /roms
if ! umount "$MOUNT_POINT" 2>/dev/null; then
    exit 1
fi

# Mount from external card
if ! mount -t exfat -o defaults,umask=000,uid=1000,gid=1000,noatime "$EXTERNAL_DEV" "$MOUNT_POINT" 2>/dev/null; then
    # Fallback: try to remount the original device
    mount -t exfat -o defaults,umask=000,uid=1000,gid=1000,noatime "$CURRENT_DEV" "$MOUNT_POINT" 2>/dev/null
    exit 1
fi

# Restore bind mount
if [ -d "$MOUNT_POINT/tools" ]; then
    mount --bind "$MOUNT_POINT/tools" /opt/system/Tools 2>/dev/null
fi
