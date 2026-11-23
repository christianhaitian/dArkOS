#!/bin/bash

ARMSX2_FILE="ARMSX2-nightly-20261120-1d1c26d8a2-Linux-arm64-SDL-handheld.tar.zst"
ARMSX2_NIGHTLY=$(echo $ARMSX2_FILE | cut -d'-' -f2,3)
ARMSX2_SHA=$(echo $ARMSX2_FILE | cut -d'-' -f4)
MALISX2_FILE="malisx2-0.5.1-aarch64.tar.gz"
MALISX2_VERSION=$(echo $MALISX2_FILE | cut -d'-' -f2)

sudo mkdir -p Arkbuild/opt/armsx2
sudo mkdir -p Arkbuild/opt/malisx2
get_file https://github.com/ARMSX2/ARMSX2/releases/download/$ARMSX2_NIGHTLY/$ARMSX2_FILE -O /tmp/$ARMSX2_FILE
sudo tar --zstd -xvf /tmp/${ARMSX2_FILE} -C Arkbuild/opt/armsx2/ --strip-components=1 armsx2-linux-arm64-sdl-sha[$ARMSX2_SHA]/armsx2-sdl armsx2-linux-arm64-sdl-sha[$ARMSX2_SHA]/resources/
get_file https://github.com/bmdhacks/malisx2/releases/download/v$MALISX2_VERSION/$MALISX2_FILE -O /tmp/$MALISX2_FILE
sudo tar -zxvf /tmp/${MALISX2_FILE} -C Arkbuild/opt/malisx2/ --strip-components=2 malisx2/$MALISX2_VERSION/
sudo cp armsx2/scripts/ps2.sh Arkbuild/usr/local/bin/.
sudo cp armsx2/configs/PCSX2.ini.template Arkbuild/opt/armsx2/.
sudo cp armsx2/configs/game_controller_db.txt Arkbuild/opt/armsx2/resources/.
sudo cp armsx2/configs/malisx2.json Arkbuild/opt/malisx2/.
rm -fv /tmp/$ARMSX2_FILE
rm -fv /tmp/$MALISX2_FILE
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/armsx2/armsx2-sdl
sudo chmod 777 Arkbuild/usr/local/bin/ps2.sh
