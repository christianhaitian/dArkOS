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
export CHIPSET=rk3566
export UNIT=rgb20pro
export UNIT_DTB=${CHIPSET}-${UNIT}

# Load shared utilities (if any)
source ./utils.sh

# Let's make sure necessary tools are available
source ./prepare.sh

# Step-by-step build process
source ./setup_partition-rk3566.sh
source ./bootstrap_rootfs-rk3566.sh
source ./build_kernel-rk3566.sh
source ./build_rtl8188fu.sh
source ./build_deps.sh
source ./build_sdl2.sh
source ./build_ppssppsa.sh
source ./build_ppsspp-2021sa.sh
source ./build_duckstationsa.sh
source ./build_mupen64plussa.sh
source ./build_gzdoom.sh
source ./build_lzdoom.sh
source ./build_retroarch.sh
source ./build_retrorun.sh
source ./build_yabasanshirosa.sh
source ./build_mednafen.sh
source ./build_ecwolfsa.sh
source ./build_hypseus-singe.sh
source ./build_openbor.sh
source ./build_solarus.sh
source ./build_scummvmsa.sh
source ./build_fake08.sh
source ./build_xroar.sh
source ./build_mvem.sh
source ./build_ogage.sh
source ./build_ogacontrols.sh
source ./build_351files.sh
source ./build_filemanager.sh
source ./build_filebrowser.sh
source ./build_gptokeyb.sh
source ./build_drmtool.sh
source ./build_image-viewer.sh
source ./build_emulationstation-rk3566.sh
source ./build_linapple.sh
source ./build_applewinsa.sh
source ./build_piemu.sh
source ./build_ti99sim.sh
source ./build_openmsxsa.sh
source ./build_flycastsa.sh
source ./build_dolphinsa.sh
source ./build_sdljoytest.sh
source ./build_controllertester.sh
source ./build_drastic.sh
if [[ "${BUILD_KODI}" == "y" ]]; then
  source ./build_kodi.sh
fi
source ./finishing_touches-rk3566.sh
source ./cleanup_filesystem.sh
source ./write_rootfs-rk3566.sh
source ./clean_mounts.sh
source ./create_image.sh
) 2>&1 | tee -a build.log

echo "RGB20PRO build completed. Final image is ready."
