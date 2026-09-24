#!/bin/bash

# Build and install oga_controls for various dArkOS menus from christianhaitian/oga_controls

call_chroot "cd /home/ark &&
  git clone --recursive --depth=1 https://github.com/christianhaitian/oga_controls.git -b quitter &&
  cd oga_controls &&
  if [ ${UNIT} == \"miniloong\" ]; then sed -i \"/back_key \= 314/s//back_key \= 316/g\" main.c; fi &&
  make -j$(nproc) all &&
  mkdir -p /opt/quitter &&
  strip oga_controls &&
  cp oga_controls /opt/quitter/ &&
  chmod 777 /opt/quitter/oga_controls &&
  chown -R ark:ark /opt/quitter
  "
sudo rm -rf Arkbuild/home/ark/oga_controls