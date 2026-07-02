#!/bin/bash

# Create boot.ini
if [ "$UNIT" == "rg351mp" ]; then
  INITRD_LOADERADDRESS="0x01100000"
else
  INITRD_LOADERADDRESS="0x04000000"
fi
cat <<EOF | sudo tee ${mountpoint}/boot.ini
odroidgoa-uboot-config

setenv bootargs "root=/dev/mmcblk0p2 rootwait rw fsck.repair=yes net.ifnames=0 fbcon=rotate:${SCREEN_ROTATION} console=/dev/ttyFIQ0 console=tty1 consoleblank=0 vt.global_cursor_default=0"

# Booting
setenv loadaddr "0x02000000"
setenv initrd_loadaddr "${INITRD_LOADERADDRESS}"
setenv dtb_loadaddr "0x01f00000"

load mmc 1:1 \${loadaddr} Image
load mmc 1:1 \${initrd_loadaddr} uInitrd

load mmc 1:1 \${dtb_loadaddr} ${KERNEL_DTB}

booti \${loadaddr} \${initrd_loadaddr} \${dtb_loadaddr}
EOF

if [ "$UNIT" == "rgb10" ] || [ "$UNIT" == "rk2020" ]; then
  sudo cp logos/rotated/logo.bmp ${mountpoint}/
else
  sudo cp logos/unrotated/logo.bmp ${mountpoint}/
fi

if [ -d "optional" ]; then
  if [ ! -z "$(find optional/ -mindepth 1 -maxdepth 1)" ]; then
    sudo cp optional/* ${mountpoint}/
  fi
fi

# Power button = clean shutdown (so the SD isn't corrupted by yanking power).
echo "HandlePowerKey=poweroff" | sudo tee -a Arkbuild/etc/systemd/logind.conf

# Add some important exports to .bashrc for user ark
echo "export PATH=\"\$PATH:/usr/sbin\"" | sudo tee -a Arkbuild/home/ark/.bashrc
sudo chroot Arkbuild/ bash -c "chown ark:ark /home/ark/.bashrc"

# Set the name in the hostname and add it to the hosts file
NAME="${UNIT}"
echo "$NAME" | sudo tee Arkbuild/etc/hostname
echo -e "# This host address\n127.0.1.1\t${NAME}" | sudo tee -a Arkbuild/etc/hosts

# Copy the .asoundrc file for proper ALSA audio
sudo cp audio/.asoundrc Arkbuild/home/ark/.asoundrc
sudo cp audio/.asoundrcbak Arkbuild/home/ark/.asoundrcbak
sudo chroot Arkbuild/ bash -c "chown ark:ark /home/ark/.asoundrc*"
sudo chroot Arkbuild/ bash -c "ln -sfv /home/ark/.asoundrc /etc/asound.conf"

# Sleep script
sudo mkdir -p Arkbuild/usr/lib/systemd/system-sleep
sudo cp scripts/sleep.${CHIPSET} Arkbuild/usr/lib/systemd/system-sleep/sleep
sudo chmod 777 Arkbuild/usr/lib/systemd/system-sleep/sleep

# Set CPU governor on boot
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/perfnorm quiet &\") | crontab -"

# Speaker Toggle to set audio output to SPK on boot
sudo mkdir -p Arkbuild/usr/local/bin
sudo cp scripts/spktoggle.sh Arkbuild/usr/local/bin/
sudo chmod 777 Arkbuild/usr/local/bin/spktoggle.sh
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/spktoggle.sh &\") | crontab -"
sudo cp scripts/audiopath.service Arkbuild/etc/systemd/system/audiopath.service
sudo cp scripts/audiostate.service Arkbuild/etc/systemd/system/audiostate.service
sudo chroot Arkbuild/ bash -c "systemctl enable audiopath"
sudo chroot Arkbuild/ bash -c "systemctl enable audiostate"

# Seed a sane default ALSA mixer state so audio is not muted on first boot
sudo mkdir -p Arkbuild/var/local
sudo cp audio/asound.state.${CHIPSET} Arkbuild/var/local/asound.state

# Copy tools for expansion of ROOTFS and conversion of the data partition to exfat on first boot
sudo cp scripts/expandtoexfat.sh.${CHIPSET} ${mountpoint}/expandtoexfat.sh
sudo cp scripts/firstboot.sh ${mountpoint}/firstboot.sh
sudo cp scripts/firstboot.service Arkbuild/etc/systemd/system/firstboot.service
sudo chroot Arkbuild/ bash -c "systemctl enable firstboot"

# Generate fstab to be used after the data partition expansion
if [ "$ROOT_FILESYSTEM_FORMAT" == "btrfs" ]; then
  ROOT_FILESYSTEM_MOUNT_OPTIONS="${ROOT_FILESYSTEM_MOUNT_OPTIONS},ssd_spread"
fi
cat <<EOF | sudo tee ${mountpoint}/fstab.exfat
LABEL=ROOTFS / ${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_MOUNT_OPTIONS} 0 0

LABEL=BOOT /boot vfat defaults 0 2
LABEL=SOLISDATA /data exfat defaults,nofail,auto,umask=000,uid=1000,gid=1000,noatime 0 0
EOF
# Ensure the /data mountpoint exists in the rootfs
sudo mkdir -p Arkbuild/data

# Disable some unneeded services
sudo chroot Arkbuild/ bash -c "systemctl disable ModemManager polkit"

# Enable SSH so the device is reachable headless
sudo chroot Arkbuild/ bash -c "systemctl enable ssh"

# Update Message of the Day
sudo cp -f scripts/00-header Arkbuild/etc/update-motd.d/00-header
sudo cp -f scripts/10-help-text Arkbuild/etc/update-motd.d/10-help-text
sudo rm -f Arkbuild/etc/motd
sudo chmod 777 Arkbuild/etc/update-motd.d/*

# Disable some unneeded interfaces in NetworkManager
cat <<EOF | sudo tee -a Arkbuild/etc/NetworkManager/NetworkManager.conf

[device]
wifi.scan-rand-mac-address=no

[keyfile]
unmanaged-devices=interface-name:p2p0;interface-name:ap0
EOF

# Remove requirement of sudo for controlling nmcli
cat <<EOF | sudo tee -a Arkbuild/etc/polkit-1/rules.d/10-networkmanager.rules
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager") == 0 &&
        subject.isInGroup("netdev")) {
        return polkit.Result.YES;
    }
});
EOF

# Default set timezone to New York
sudo chroot Arkbuild/ bash -c "ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime"

# Copy performance scripts
sudo cp scripts/perf* Arkbuild/usr/local/bin/

# Add USB DAC Support
echo -e "Generating 20-usb-alsa.rules udev for usb dac support"
echo -e "KERNEL==\"controlC[0-9]*\", DRIVERS==\"usb\", SYMLINK=\"snd/controlC7\"" | sudo tee Arkbuild/etc/udev/rules.d/20-usb-alsa.rules
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/checknswitchforusbdac.sh &\") | crontab -"

# Fix LEDs on A10 Mini to default to the nice dim blue light while powered on
if [[ "$UNIT" == "a10mini" ]]; then
  sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/fix_power_led &\") | crontab -"
fi

# Disable requirement for sudo for setting niceness
echo "ark              -       nice            -20" | sudo tee -a Arkbuild/etc/security/limits.conf

# Copy various other backend tools
sudo cp scripts/checkbrightonboot Arkbuild/usr/local/bin/
sudo cp scripts/current_* Arkbuild/usr/local/bin/
sudo cp scripts/spktoggle.sh Arkbuild/usr/local/bin/
sudo cp scripts/timezones Arkbuild/usr/local/bin/
sudo cp scripts/volume.sh Arkbuild/usr/local/bin/
sudo cp scripts/auto_suspend* Arkbuild/usr/local/bin/
sudo cp scripts/processcheck.sh Arkbuild/usr/local/bin/
sudo cp scripts/autosuspend.service Arkbuild/etc/systemd/system/
sudo chroot Arkbuild/ bash -c "pip install --break-system-packages --root-user-action ignore inputs"
sudo chroot Arkbuild/ bash -c "systemctl disable autosuspend"
sudo cp scripts/sleep_governors.sh Arkbuild/usr/local/bin/
sudo cp global/* Arkbuild/usr/local/bin/

# Disable e2scrub_reap if ext file system is not being used for rootfs
if [ "$ROOT_FILESYSTEM_FORMAT" == "xfs" ] || [ "$ROOT_FILESYSTEM_FORMAT" == "btrfs" ]; then
  sudo chroot Arkbuild/ bash -c "systemctl disable e2scrub_reap"
fi

# Set the default systemd target to multi-user (no desktop / ES)
sudo chroot Arkbuild/ bash -c "systemctl set-default multi-user.target"

# Device specific board scripts (LED, battery, brightness, etc.)
if [[ "$UNIT" == "rgb10" ]]; then
  sudo cp device/rgb10/* Arkbuild/usr/local/bin/
elif [[ "$UNIT" == "rg351mp" ]] || [[ "$UNIT" == "g350" ]] || [[ "$UNIT" == "a10mini" ]]; then
  sudo cp device/rg351mp/*.sh Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/*.py Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/*.green Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/*.red Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/fix_power_led Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/checkbrightonboot Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/*.service Arkbuild/etc/systemd/system/
  sudo chroot Arkbuild/ bash -c "systemctl enable 351mp batt_led"
fi
if [[ "$UNIT" == "g350" ]]; then
  sudo cp scripts/g350/*.sh Arkbuild/usr/local/bin/
  # USB ethernet gadget on every boot — the only deploy/SSH path to the device
  sudo cp scripts/g350/usbnet.service Arkbuild/etc/systemd/system/usbnet.service
  sudo chroot Arkbuild/ bash -c "systemctl enable usbnet"
fi

# Make all scripts in /usr/local/bin executable
sudo chmod 777 Arkbuild/usr/local/bin/*

# --- SOLIS music tracker (placeholder) ---
sudo cp solis/solis Arkbuild/usr/local/bin/solis
sudo chmod 755 Arkbuild/usr/local/bin/solis
sudo cp solis/solis.service Arkbuild/etc/systemd/system/solis.service
sudo chroot Arkbuild/ bash -c "systemctl enable solis"
# Boot straight into SOLIS, not a login console — disable the tty1 getty.
# (SOLIS's "Console" option starts it again on demand.)
sudo chroot Arkbuild/ bash -c "systemctl disable getty@tty1.service"

# Set distro identification and version
sudo mkdir -p Arkbuild/usr/share/plymouth/themes/
cat <<EOF | sudo tee Arkbuild/usr/share/plymouth/themes/text.plymouth
title=SOLIS (${BUILD_DATE})
EOF
echo "${BUILD_DATE}" | sudo tee Arkbuild/home/ark/.config/.VERSION

# Set boot up welcome text with distro and version
sudo cp scripts/boot_text.sh Arkbuild/usr/local/bin/
sudo chmod 777 Arkbuild/usr/local/bin/boot_text.sh
sudo cp scripts/welcome-message.service Arkbuild/etc/systemd/system/welcome-message.service
sudo chroot Arkbuild/ bash -c "systemctl enable welcome-message"

# Set the owner of the ark folder and all sub content to ark
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark"

sync
sudo umount -l ${mountpoint}
sudo losetup -d ${LOOP_BOOT}

# Format rootfs partition in final image
ROOTFS_PART_OFFSET=$((STORAGE_PART_START * 512))
LOOP_ROOTFS=$(sudo losetup --find --show --offset ${ROOTFS_PART_OFFSET} ${DISK})
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_FORMAT_PARAMETERS} ${LOOP_ROOTFS}
sudo losetup -d ${LOOP_ROOTFS}

# Format the SOLIS data partition in the final image (empty; expanded to exfat on first boot)
ROM_PART_OFFSET=$((ROM_PART_START * 512))
ROM_PART_SIZE_BYTES=$(( (ROM_PART_END - ROM_PART_START + 1) * 512 ))
LOOP_ROM=$(sudo losetup --find --show --offset ${ROM_PART_OFFSET} --sizelimit ${ROM_PART_SIZE_BYTES} ${DISK})
if [ -z "$LOOP_ROM" ]; then
  echo "❌ Failed to create loop device for the data partition!"
  exit 1
fi
sudo mkfs.vfat -F 32 -n SOLISDATA ${LOOP_ROM}
sudo losetup -d ${LOOP_ROM}
