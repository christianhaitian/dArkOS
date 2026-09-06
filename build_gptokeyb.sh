#!/bin/bash

# Build and install gptokeyb for various dArkOS menus from christianhaitian/gptokeyb

call_chroot "cd /home/ark &&
  git clone --recursive --depth=1 https://github.com/christianhaitian/gptokeyb.git -b inttools &&
  cd gptokeyb &&
  make -j$(nproc) all &&
  mkdir -p /opt/inttools &&
  strip gptokeyb &&
  cp gptokeyb /opt/inttools/ &&
  chmod 777 /opt/inttools/gptokeyb
  "
sudo rm -rf Arkbuild/home/ark/gptokeyb
sudo cp inttools/* Arkbuild/opt/inttools/
call_chroot "chown -R ark:ark /opt/inttools"
sudo chmod 777 Arkbuild/opt/inttools/osk.py

# Copy some other tools that make use of gptokeyb
sudo cp scripts/osk Arkbuild/usr/bin/
sudo cp scripts/msgbox Arkbuild/usr/bin/
sudo chmod 777 Arkbuild/usr/bin/osk
sudo chmod 777 Arkbuild/usr/bin/msgbox
