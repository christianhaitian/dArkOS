#!/bin/bash
#exec 3>&1 4>&2
#trap 'exec 2>&4 1>&3' 0 1 2 3
#exec 1>build.log 2>&1
#set -e
if [ -f "build.log" ]; then
  ext=1
  while true
  do
    if [ -f "build.log.${ext}" ]; then
      let ext=ext+1
	  continue
	else
      mv build.log build.log.${ext}
	  break
	fi
  done
fi
(
# Set chipset in environment variable
export CHIPSET=rk3326
export UNIT=a10mini

# Load shared utilities (if any)
source ./utils.sh

# Let's make sure necessary tools are available
source ./prepare.sh

# Step-by-step build process
source ./setup_partition.sh
source ./bootstrap_rootfs.sh
source ./image_setup.sh
source ./build_kernel.sh
source ./build_deps.sh
source ./finishing_touches.sh
source ./cleanup_filesystem.sh
source ./write_rootfs.sh
source ./clean_mounts.sh
source ./create_image.sh
) 2>&1 | tee -a build.log

echo "A10 Mini build completed. Final image is ready."

