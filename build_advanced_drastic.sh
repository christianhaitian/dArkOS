#!/bin/bash

# Build and install advanced_drastic standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/advanced_drastic.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/advanced_drastic.commit)" == "$(curl -s https://api.github.com/repos/trngaje/advanced_drastic/commits/master | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/advanced_drastic.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh advanced_drastic
	  "
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/advanced_drastic-64/advanced_drastic Arkbuild/opt/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/advanced_drastic.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/advanced_drastic.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/advanced_drastic.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/advanced_drastic.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/advanced_drastic.tar.gz Arkbuild/opt/advanced_drastic/
	curl -s https://api.github.com/repos/trngaje/advanced_drastic/commits/master | jq -r '.sha' > Arkbuild_package_cache/${CHIPSET}/advanced_drastic.commit
fi
if [[ -e "advanced_drastic/configs/drastic.cfg.$UNIT" ]]; then
  sudo cp -L advanced_drastic/configs/drastic.cfg.${UNIT} Arkbuild/opt/advanced_drastic/config/drastic.cfg
else
  sudo cp -L advanced_drastic/configs/drastic.cfg.${CHIPSET} Arkbuild/opt/advanced_drastic/config/drastic.cfg
fi

if test -z "$(cat Arkbuild/etc/emulationstation/es_systems.cfg | grep advanced_drastic | tr -d '\0')"
then
  sudo sed -i '/<emulator name="drastic">/i\
  \t\t\t<emulator name="advanced_drastic">\
  \t\t\t</emulator>' Arkbuild/etc/emulationstation/es_systems.cfg
fi

call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/advanced_drastic/drastic
