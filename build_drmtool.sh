#!/bin/bash

# Build and install drm_tool to be used for getting drm info and setting properties
# This is built and installed drm_tool twice as we need to checkout an older version
# for panel color profile setting.  Yes it's weird and shouldn't be needed
# Perhaps i'll clean it up later.  Maybe not. I don't know
call_chroot "cd /home/ark &&
  git clone --recursive https://github.com/christianhaitian/drm_tool.git &&
  cd drm_tool &&
  make -j$(nproc) &&
  strip drm_tool &&
  cp drm_tool /usr/local/bin/ &&
  chmod 777 /usr/local/bin/drm_tool &&
  make clean &&
  git checkout 1cb5b10b7d529105e33f27388519671ee7ce46f3 &&
  make -j$(nproc) &&
  strip drm_tool &&
  cp drm_tool /usr/local/bin/panel_drm_tool &&
  chmod 777 /usr/local/bin/panel_drm_tool
  "
sudo rm -rf Arkbuild/home/ark/drm_tool
