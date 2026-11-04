#!/bin/bash

# Build and install linapple standalone emulator along with sdl2-compat
if [ -f "Arkbuild_package_cache/${CHIPSET}/linapplesa.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/linapplesa.commit)" == "$(curl -s https://api.github.com/repos/christianhaitian/linapple/commits/master | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/linapplesa.tar.gz
else
	call_chroot "export CCACHE_DISABLE=1 &&
	  cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh linapplesa
	  "
	sudo mkdir -p Arkbuild/opt/linapple
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/linapplesa-64/linapple Arkbuild/opt/linapple/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/linapple/res/Master.dsk Arkbuild/opt/linapple/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/linapple/res/A2_BASIC.SYM Arkbuild/opt/linapple/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/linapple/res/APPLE2E.SYM Arkbuild/opt/linapple/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/linapplesa.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/linapplesa.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/linapplesa.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/linapplesa.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/linapplesa.tar.gz Arkbuild/opt/linapple/
	sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/linapple/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/linapple rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/linapplesa.commit
fi

sudo cp linapple/gamecontrollerdb.txt Arkbuild/opt/linapple/
sudo cp -R linapple/configs/* Arkbuild/opt/linapple/
sudo cp linapple/apple2.sh Arkbuild/usr/local/bin/
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/linapple/linapple
sudo chmod 777 Arkbuild/usr/local/bin/apple2.sh
