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