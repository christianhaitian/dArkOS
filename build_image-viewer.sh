#!/bin/bash

# Build and install image-viewer
call_chroot "cd /home/ark &&
  git clone --recursive --depth=1 https://github.com/JohnIrvine1433/ThemeMaster-Image_Viewer.git &&
  cd ThemeMaster-Image_Viewer &&
  make -j$(nproc) &&
  strip image-viewer &&
  cp image-viewer /usr/local/bin/ &&
  chmod 777 /usr/local/bin/image-viewer
  "
sudo rm -rf Arkbuild/home/ark/ThemeMaster-Image_Viewer
