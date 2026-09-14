#!/bin/bash

# Build and install 351Files
if [ "$UNIT" == "rgb10" ]; then
  BUILD_UNIT="RGB10"
elif [ "$UNIT" == "rg351mp" ] || [ "$UNIT" == "g350" ] || [ "$UNIT" == "a10mini" ]; then
  BUILD_UNIT="RG351MP"
elif [[ "$UNIT" == *"353"* ]] || [[ "$UNIT" == "rk2023" ]]; then
  BUILD_UNIT="RG353V"
elif [[ "$UNIT" == "503" ]]; then
  BUILD_UNIT="RG503"
elif [[ "$UNIT" == "rgb30" ]]; then
  BUILD_UNIT="RGB30"
elif [[ "$UNIT" == "rgb20pro" ]]; then
  BUILD_UNIT="RGB20PRO"
elif [[ "$UNIT" == "miniloong" ]]; then
  BUILD_UNIT="MINILOONG"
fi

call_chroot "cd /home/ark &&
  git clone --recursive --depth=1 https://github.com/christianhaitian/351Files.git &&
  cd 351Files &&
  ./build_RG351.sh ${BUILD_UNIT} ArkOS /roms ./res &&
  strip 351Files*
  "
sudo mkdir -p Arkbuild/opt/351Files
sudo cp Arkbuild/home/ark/351Files/351Files* Arkbuild/opt/351Files/
sudo chmod 777 Arkbuild/opt/351Files/351Files*
sudo cp -R Arkbuild/home/ark/351Files/res/ Arkbuild/opt/351Files/
sudo rm -rf Arkbuild/home/ark/351Files
