#!/bin/bash

# Build and install Yabasanshiro-pirry standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/yabasanshirosa-pirry.sh | grep -oP '(?<=TAG=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz
else
	call_chroot "source /root/.bashrc && cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  sed -i '/python-pip/s//python3-pip/g' scripts/yabasanshirosa-pirry.sh &&
	  eatmydata ./builds-alt.sh yabasanshirosa-pirry &&
	  mkdir -p /opt/yabasanshiro &&
	  cp yabasanshirosa-pirry64/yabasanshiro* /opt/yabasanshiro/
	  "
	if [ -f "Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz Arkbuild/opt/yabasanshiro/
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/yabasanshirosa.sh | grep -oP '(?<=TAG=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.commit
fi
if [ "$UNIT" == "rgb10" ] || [ "$UNIT" == "rk2020" ]; then
  sudo cp -a Arkbuild/opt/yabasanshiro/yabasanshiro-pirry.oga Arkbuild/opt/yabasanshiro/yabasanshiro
else
  sudo rm -fv Arkbuild/opt/yabasanshiro/yabasanshiro-pirry.oga
fi
sudo cp -a Arkbuild/opt/yabasanshiro/yabasanshiro-pirry Arkbuild/opt/yabasanshiro/yabasanshiro
sudo rm -fv Arkbuild/opt/yabasanshiro/yabasanshiro-pirry
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/yabasanshiro/yabasanshiro
sudo cp yabasanshiro/saturn.sh Arkbuild/usr/local/bin/saturn.sh
sudo chmod 777 Arkbuild/usr/local/bin/saturn.sh
