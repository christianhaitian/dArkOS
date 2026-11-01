#!/bin/bash

if [ "$CHIPSET" == "rk3566" ]; then
	sudo mkdir -p Arkbuild/opt/duckstation
	sudo mkdir -p Arkbuild/home/ark/.local/share/duckstation
	sudo cp duckstation/duckstation-sa-0.1-10495.AppImage Arkbuild/opt/duckstation/duckstationsa
	sudo cp duckstation/scripts/standalone-duckstation Arkbuild/usr/local/bin/
	sudo cp duckstation/configs/settings.ini.${UNIT} Arkbuild/home/ark/.local/share/duckstation/settings.ini
	call_chroot "chown -R ark:ark /opt/"
	call_chroot "chown -R ark:ark /home/ark/"
	sudo chmod 777 Arkbuild/opt/duckstation/duckstationsa
	sudo chmod 777 Arkbuild/usr/local/bin/standalone-duckstation
else
	if [ -f "Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz" ]; then
		sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz
	else
		call_chroot "cd /home/ark &&
		  cd ${CHIPSET}_core_builds &&
		  chmod 777 builds-alt.sh &&
		  eatmydata ./builds-alt.sh duckstationsa
		  "
		sudo mkdir -p Arkbuild/opt/duckstation
		sudo mkdir -p Arkbuild/home/ark/.config/duckstation
		sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstationsa-64/duckstation-nogui* Arkbuild/opt/duckstation/.
		sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstation/data/database Arkbuild/home/ark/.config/duckstation/
		sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstation/data/inputprofiles Arkbuild/home/ark/.config/duckstation/
		sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstation/data/resources Arkbuild/home/ark/.config/duckstation/
		sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstation/data/shaders Arkbuild/home/ark/.config/duckstation/
		if [ -f "Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz" ]; then
		  sudo rm -f Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz
		fi
		sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz Arkbuild/opt/duckstation/ Arkbuild/home/ark/.config/duckstation/
	fi
	if [ "$UNIT" == "rgb10" ]; then
	  sudo cp -Ra Arkbuild/opt/duckstation/duckstation-nogui.chirgb10 Arkbuild/opt/duckstation/duckstation-nogui
	fi
	sudo rm -fv Arkbuild/opt/duckstation/duckstation-nogui.chirgb10
	sudo cp duckstation/scripts/standalone-duckstation-old Arkbuild/usr/local/bin/standalone-duckstation
	sudo cp duckstation/configs/settings.ini.${UNIT} Arkbuild/home/ark/.config/duckstation/settings.ini
	call_chroot "chown -R ark:ark /opt/"
	call_chroot "chown -R ark:ark /home/ark/"
	sudo chmod 777 Arkbuild/opt/duckstation/duckstation-nogui
	sudo chmod 777 Arkbuild/usr/local/bin/standalone-duckstation
fi