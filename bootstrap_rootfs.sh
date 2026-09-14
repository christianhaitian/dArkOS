#!/bin/bash

echo -e "Boostraping Debian....\n\n"
if [ -f "Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.tar.gz" ] && [ "$(cat Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.commit)" == "$(curl -s https://deb.debian.org/debian/dists/stable/Release | grep "^Version:" | cut -d' ' -f2)" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.tar.gz
else
	if [[ "${ENABLE_CACHE}" == "y" ]]; then
	  export DEBIAN_LOCATION="http://127.0.0.1:3142/deb.debian.org/debian/"
	else
	  export DEBIAN_LOCATION="http://deb.debian.org/debian/"
	fi
	# Bootstrap base system
	sudo eatmydata debootstrap --no-check-gpg --include=eatmydata --resolve-deps --arch=arm64 --foreign ${DEBIAN_CODE_NAME} Arkbuild ${DEBIAN_LOCATION}
	sudo cp /usr/bin/qemu-aarch64-static Arkbuild/usr/bin/
	if [[ "${ENABLE_CACHE}" == "y" ]]; then
	  echo 'Acquire::http::proxy "http://127.0.0.1:3142";' | sudo tee Arkbuild/etc/apt/apt.conf.d/99proxy
	fi
	sudo chroot Arkbuild/ apt-get -y install ccache eatmydata
	sudo chroot Arkbuild/ eatmydata /debootstrap/debootstrap --second-stage

	if [[ "${BUILD_ARMHF}" == "y" ]]; then
	  # Enable armhf architecture and update
	  sudo chroot Arkbuild/ dpkg --add-architecture armhf
	  sudo chroot Arkbuild/ eatmydata apt-get -y update
	  sudo chroot Arkbuild/ eatmydata apt-get -y install libc6:armhf liblzma5:armhf libasound2t64:armhf libfreetype6:armhf libxkbcommon-x11-0:armhf libudev1:armhf libudev0:armhf libgbm1:armhf libstdc++6:armhf
	fi
	sudo cat Arkbuild/etc/os-release | grep "^DEBIAN_VERSION_FULL=" | cut -d'=' -f2 > Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.commit
	sudo tar -cvpzf Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.tar.gz Arkbuild/
fi

# Bind essential host filesystems into chroot for networking
sudo mount --bind /dev Arkbuild/dev
sudo mount -t devpts none Arkbuild/dev/pts -o newinstance,ptmxmode=0666
#sudo mount --bind /dev/pts Arkbuild/dev/pts -o newinstance,ptmxmode=0666
sudo mount --bind /proc Arkbuild/proc
sudo mount --bind /sys Arkbuild/sys
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee Arkbuild/etc/resolv.conf > /dev/null

# Avoid service autostarts
echo "exit 101" | sudo tee Arkbuild/usr/sbin/policy-rc.d > /dev/null
sudo chmod 0755 Arkbuild/usr/sbin/policy-rc.d
sudo chroot Arkbuild/ mount -t proc proc /proc

# Every dpkg run in this chroot is emulated, and the build installs ~145 packages
# plus everything they pull in.  Manual pages and docs are the most expensive part
# of that for no benefit: they are unpacked under qemu, they fire the man-db
# trigger on every transaction, and cleanup_filesystem.sh deletes
# /usr/share/man/* at the end anyway.  Skip unpacking them in the first place and
# turn the man-db index rebuild off.  Copyright files are kept - the image ships
# GPL software and those have to stay.
sudo mkdir -p Arkbuild/etc/dpkg/dpkg.cfg.d
cat <<'EOF' | sudo tee Arkbuild/etc/dpkg/dpkg.cfg.d/01-darkos-slim > /dev/null
path-exclude=/usr/share/man/*
path-exclude=/usr/share/info/*
path-exclude=/usr/share/doc/*
path-include=/usr/share/doc/*/copyright
EOF
echo 'man-db man-db/auto-update boolean false' | sudo chroot Arkbuild/ debconf-set-selections 2>/dev/null || true

# Install base runtime packages
sudo chroot Arkbuild/ eatmydata apt-get -y update
sudo chroot Arkbuild/ eatmydata apt-get -y upgrade
sudo chroot Arkbuild/ eatmydata apt-get install -y btrfs-progs initramfs-tools sudo evtest network-manager systemd-sysv locales locales-all ssh dosfstools fluidsynth
sudo chroot Arkbuild/ eatmydata apt-get install -y python3 python3-pip
sudo sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' Arkbuild/etc/locale.gen
echo 'LANG="en_US.UTF-8"' | sudo tee -a Arkbuild/etc/default/locale > /dev/null
echo -e "export LC_All=en_US.UTF-8" | sudo tee -a Arkbuild/root/.bashrc > /dev/null
sudo chroot Arkbuild/ bash -c "update-locale LANG=en_US.UTF-8"
sudo chroot Arkbuild/ bash -c "locale-gen"
sudo chroot Arkbuild/ systemctl enable NetworkManager

# Install libmali, DRM, and GBM libraries for ${CHIPSET}
sudo chroot Arkbuild/ eatmydata apt-get install -y libdrm-dev libgbm1

setup_ark_user
sleep 10
echo -e "Generating /etc/fstab"
echo -e "LABEL=ROOTFS / ${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_MOUNT_OPTIONS} 0 1
LABEL=BOOT /boot vfat defaults 0 0
LABEL=EASYROMS /roms vfat defaults,auto,umask=000,uid=1000,gid=1000,noatime 0 0" | sudo tee Arkbuild/etc/fstab
echo -e "Generating 10-standard.rules for udev"
echo -e "# Rules
KERNEL==\"mali0\", GROUP=\"video\", MODE=\"0660\"
KERNEL==\"rga\", GROUP=\"video\", MODE=\"0660\"
ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/bin/chgrp video /sys/class/backlight/%k/brightness\"
ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/bin/chmod g+w /sys/class/backlight/%k/brightness\"" | sudo tee Arkbuild/etc/udev/rules.d/10-standard.rules
echo -e "Generating 40-usb_modeswitch.rules for udev"
echo -e "# Rules
ACTION!=\"add|change\", GOTO=\"end_modeswitch\"

# Atheros Wireless / Netgear WNDA3200
ATTRS{idVendor}==\"0cf3\", ATTRS{idProduct}==\"20ff\", RUN+=\"/usr/bin/eject '/dev/%k'\"

# Realtek RTL8821CU chipset 802.11ac NIC
#   initial cdrom mode 0bda:1a2b, wlan mode 0bda:c811
# Odroid WiFi Module 5B
#   initial cdrom mode 0bda:1a2b, wlan mode 0bda:c820
ATTR{idVendor}==\"0bda\", ATTR{idProduct}==\"1a2b\", RUN+=\"/usr/sbin/usb_modeswitch -K -v 0bda -p 1a2b\"
ATTR{idVendor}==\"0bda\", ATTR{idProduct}==\"c811\", RUN+=\"/usr/sbin/usb_modeswitch -K -v 0bda -p c811\"

LABEL=\"end_modeswitch\"" | sudo tee Arkbuild/etc/udev/rules.d/40-usb_modeswitch.rules
sudo chroot Arkbuild/ sync
sleep 5
sudo chroot Arkbuild/ umount /proc

